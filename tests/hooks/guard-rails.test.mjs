import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { evaluateGuardrails, readHookConfig } from '../../hooks/guard-rails.mjs';

const enabled = { privacy: true, scout: true };
const testsDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testsDirectory, '..', '..');
const hooksDirectory = path.join(root, 'hooks');

function collectMarkdownFiles(directory) {
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
        const entryPath = path.join(directory, entry.name);
        if (entry.isDirectory()) return collectMarkdownFiles(entryPath);
        return entry.isFile() && entry.name.endsWith('.md') ? [entryPath] : [];
    });
}

test('privacy blocks secret paths before a tool runs', () => {
    const result = evaluateGuardrails({ tool_name: 'Read', tool_input: { path: '.env.local' } }, enabled);
    assert.equal(result.hook, 'privacy');
    assert.equal(result.action, 'block');
});

test('privacy inspects nested MCP and local-tool arguments', () => {
    const result = evaluateGuardrails({
        tool_name: 'mcp__filesystem__read_file',
        tool_input: { arguments: { request: { file_path: '.npmrc' } } },
    }, enabled);
    assert.equal(result.hook, 'privacy');
    assert.equal(result.action, 'block');
});

test('scout blocks generated paths and broad globs', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Read', tool_input: { path: 'node_modules/react/index.js' } }, enabled).hook, 'scout');
    assert.equal(evaluateGuardrails({ tool_name: 'Glob', tool_input: { pattern: '**/*.ts' } }, enabled).hook, 'scout');
});

test('scout allows recursive globs scoped to a subfolder', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Glob', tool_input: { pattern: 'src/**/*.ts' } }, enabled).action, 'allow');
    assert.equal(evaluateGuardrails({ tool_name: 'Glob', tool_input: { pattern: 'packages/foo/**/*.tsx' } }, enabled).action, 'allow');
});

test('scout blocks traversal above the project root', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Read', tool_input: { path: '../notes.md' } }, enabled).hook, 'scout');
    assert.equal(evaluateGuardrails({ tool_name: 'Glob', tool_input: { pattern: '../**/*.ts' } }, enabled).hook, 'scout');
    assert.equal(evaluateGuardrails({ tool_name: 'Read', tool_input: { path: 'src/../../outside.ts' } }, enabled).hook, 'scout');
});

test('a filename containing two dots is not mistaken for parent traversal', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Read', tool_input: { path: 'src/foo..bar.ts' } }, enabled).action, 'allow');
});

test('a relative import inside written file content is not mistaken for parent traversal', () => {
    const result = evaluateGuardrails({
        tool_name: 'Write',
        tool_input: { file_path: 'src/routes/rooms.ts', content: "import { db } from '../db/rooms.js';\n" },
    }, enabled);
    assert.equal(result.action, 'allow');
});

test('a relative import inside edited file content is not mistaken for parent traversal', () => {
    const result = evaluateGuardrails({
        tool_name: 'Edit',
        tool_input: { file_path: 'src/routes/spawn.ts', old_string: 'x', new_string: "import spawn from '../claude/spawn.js';" },
    }, enabled);
    assert.equal(result.action, 'allow');
});

test('a node_modules mention inside written prose is not mistaken for a heavy directory path', () => {
    const result = evaluateGuardrails({
        tool_name: 'Edit',
        tool_input: { file_path: 'plans/phase-02b.md', old_string: 'x', new_string: 'Remember: never commit node_modules to git.' },
    }, enabled);
    assert.equal(result.action, 'allow');
});

test('config guard blocks direct writes and edits to .hs.json', () => {
    const writeResult = evaluateGuardrails({ tool_name: 'Write', tool_input: { file_path: '.hs.json', content: '{}' } }, enabled);
    assert.equal(writeResult.hook, 'config');
    assert.equal(writeResult.action, 'block');

    const editResult = evaluateGuardrails({
        tool_name: 'Edit',
        tool_input: { file_path: '.hs.json', old_string: '"scout": true', new_string: '"scout": false' },
    }, enabled);
    assert.equal(editResult.hook, 'config');
    assert.equal(editResult.action, 'block');
});

test('config guard blocks shell writes to .hs.json but allows reading it', () => {
    const catResult = evaluateGuardrails({ tool_name: 'Bash', tool_input: { command: 'cat .hs.json' } }, enabled);
    assert.equal(catResult.action, 'allow');

    const redirectResult = evaluateGuardrails({ tool_name: 'Bash', tool_input: { command: "echo '{}' > .hs.json" } }, enabled);
    assert.equal(redirectResult.hook, 'config');
    assert.equal(redirectResult.action, 'block');

    const sedResult = evaluateGuardrails({ tool_name: 'Bash', tool_input: { command: "sed -i 's/true/false/' .hs.json" } }, enabled);
    assert.equal(sedResult.hook, 'config');
    assert.equal(sedResult.action, 'block');
});

test('the Read tool can still inspect .hs.json without triggering the config guard', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Read', tool_input: { file_path: '.hs.json' } }, enabled).action, 'allow');
});

test('config guard cannot be turned off through .hs.json itself, unlike privacy and scout', () => {
    const disabled = { privacy: false, scout: false };
    const result = evaluateGuardrails({ tool_name: 'Write', tool_input: { file_path: '.hs.json', content: '{}' } }, disabled);
    assert.equal(result.hook, 'config');
    assert.equal(result.action, 'block');
});

test('AskUserQuestion is never scanned even when option previews mention paths', () => {
    const result = evaluateGuardrails({
        tool_name: 'AskUserQuestion',
        tool_input: {
            questions: [{
                question: 'Which import style?',
                header: 'Import',
                multiSelect: false,
                options: [{ label: 'Relative', description: 'use ../db/rooms.js', preview: "import { db } from '../db/rooms.js'" }],
            }],
        },
    }, enabled);
    assert.equal(result.action, 'allow');
});

test('TodoWrite and other non-filesystem tools bypass the guard rails entirely', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'TodoWrite', tool_input: { todos: [{ content: 'clean node_modules', status: 'pending' }] } }, enabled).action, 'allow');
    assert.equal(evaluateGuardrails({ tool_name: 'Task', tool_input: { prompt: 'read ../secrets.env and summarize' } }, enabled).action, 'allow');
});

test('WebFetch and WebSearch bypass the guard rails since they never touch the filesystem', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'WebSearch', tool_input: { query: 'difference between ../a and ./a imports' } }, enabled).action, 'allow');
    assert.equal(evaluateGuardrails({ tool_name: 'WebFetch', tool_input: { url: 'https://example.com/docs/x/../y', prompt: 'summarize node_modules setup' } }, enabled).action, 'allow');
});

test('MCP edit tools using oldText/newText/text do not leak file bodies into the scan', () => {
    const result = evaluateGuardrails({
        tool_name: 'mcp__filesystem__edit_file',
        tool_input: { path: 'src/routes/rooms.ts', edits: [{ oldText: 'x', newText: "import { db } from '../db/rooms.js';" }] },
    }, enabled);
    assert.equal(result.action, 'allow');
});

test('privacy allows a secret-looking string inside written content, since only the destination path is checked', () => {
    const result = evaluateGuardrails({
        tool_name: 'Write',
        tool_input: { file_path: 'src/config.ts', content: 'const key = "AWS_SECRET id_rsa";' },
    }, enabled);
    assert.equal(result.action, 'allow');
});

test('privacy still blocks when the destination path itself is a secret file, even with benign content', () => {
    const result = evaluateGuardrails({
        tool_name: 'Write',
        tool_input: { file_path: '.env', content: 'harmless text' },
    }, enabled);
    assert.equal(result.hook, 'privacy');
    assert.equal(result.action, 'block');
});

test('scout still blocks when the actual file_path targets a heavy directory or traverses the root', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Write', tool_input: { file_path: 'node_modules/injected.js', content: 'safe text' } }, enabled).hook, 'scout');
    assert.equal(evaluateGuardrails({ tool_name: 'Write', tool_input: { file_path: '../outside.ts', content: 'safe text' } }, enabled).hook, 'scout');
});

test('build and test commands remain allowed', () => {
    assert.equal(evaluateGuardrails({ tool_name: 'Bash', tool_input: { command: 'npm test -- node_modules/example' } }, enabled).action, 'allow');
});

test('a build or test prefix cannot bypass scout checks through shell chaining', () => {
    const result = evaluateGuardrails({ tool_name: 'Bash', tool_input: { command: 'npm test && find node_modules -type f' } }, enabled);
    assert.equal(result.hook, 'scout');
    assert.equal(result.action, 'block');
});

test('individual hooks can be disabled in .hs.json', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'hs-guardrails-'));
    try {
        fs.writeFileSync(path.join(directory, '.hs.json'), JSON.stringify({ guardrails: { hooks: { privacy: false, scout: true } } }));
        const config = readHookConfig(directory);
        assert.deepEqual(config, { privacy: false, scout: true });
        assert.equal(evaluateGuardrails({ tool_name: 'Read', tool_input: { path: '.env' } }, config).action, 'allow');
    } finally {
        fs.rmSync(directory, { recursive: true, force: true });
    }
});

test('Claude and Codex receive the PreToolUse deny contract', () => {
    const input = JSON.stringify({ tool_name: 'Read', tool_input: { path: '.env' } });
    for (const platform of ['claude', 'codex']) {
        const result = spawnSync(process.execPath, ['./guard-rails.mjs', '--platform', platform], { cwd: hooksDirectory, input, encoding: 'utf8' });
        assert.equal(result.status, 0, `${platform} hook succeeds after denying the tool`);
        assert.equal(JSON.parse(result.stdout).hookSpecificOutput.permissionDecision, 'deny');
    }
});

test('target implementation skills contain one hard gate', () => {
    for (const skill of ['backend-development', 'frontend-design', 'ui-styling', 'databases']) {
        const content = fs.readFileSync(path.join(root, 'skills', skill, 'SKILL.md'), 'utf8');
        assert.equal((content.match(/<HARD-GATE>/g) ?? []).length, 1, `${skill} must contain exactly one hard gate`);
    }
});

test('skill workflows remain self-contained and runtime-neutral', () => {
    const forbidden = /\b(?:ASK_USER|SPAWN_AGENT|TRACK_TASK|TaskCreate|TaskUpdate|TaskGet|TaskList|TodoWrite|AskUserQuestion)\b|runtime-actions\.md/;
    for (const file of collectMarkdownFiles(path.join(root, 'skills'))) {
        const content = fs.readFileSync(file, 'utf8');
        assert.doesNotMatch(content, forbidden, `${path.relative(root, file)} must not use shared runtime action identifiers`);
    }
});
