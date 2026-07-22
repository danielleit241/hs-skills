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
