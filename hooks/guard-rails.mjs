#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_HOOKS = Object.freeze({ privacy: true, scout: true });
const SENSITIVE_PATH = /(^|[\\/\s'"`])(?:\.env(?:\.[^\\/]+)?|\.npmrc|\.netrc|\.pypirc|\.git-credentials|auth\.json|kubeconfig|id_[a-z0-9_-]*|credentials(?:\.[a-z0-9_-]+)?|secrets?(?:\.[a-z0-9_-]+)?|[^\\/]+\.(?:pem|key|p12|pfx))(?=$|[\\/\s'"`])/i;
const HEAVY_DIRECTORY = /(^|[\\/\s'"`])(?:node_modules|dist|build|\.next|\.nuxt|coverage|target|vendor|\.venv|venv|__pycache__|\.git)(?=$|[\\/\s'"`])/i;
const ROOT_GLOB = /(?:^|[\s'"`])\*\*\/(?:\*|\*\.[a-z0-9_-]+)(?=$|[\\/\s'"`])/i;
const PARENT_TRAVERSAL = /(?:^|[\\/\s'"`])\.\.(?=$|[\\/])/;
const SAFE_BASH = /^\s*(?:npm\s+(?:run\s+)?(?:build|test)|pnpm\s+(?:run\s+)?(?:build|test)|yarn\s+(?:build|test)|bun\s+(?:run\s+)?(?:build|test)|pytest\b|dotnet\s+test\b|cargo\s+test\b|go\s+test\b|make\b|docker\s+build\b)[\w\s./:=@,\-]*$/i;
// Keys that hold file bodies rather than paths — matching guard-rail patterns inside these
// produces false positives (e.g. a "../db/rooms.js" import line, or "node_modules" in a comment).
const CONTENT_KEYS = new Set([
    'content', 'old_string', 'new_string', 'new_source', 'file_text', 'body',
    'oldText', 'newText', 'old_text', 'new_text', 'text', 'contents',
]);
// Tools that never touch the filesystem — their inputs are prose (questions, previews, task
// descriptions), not paths, so scanning them for path patterns only produces false positives.
const NON_FILESYSTEM_TOOLS = new Set([
    'AskUserQuestion',
    'TodoWrite',
    'Task',
    'TaskCreate',
    'TaskUpdate',
    'TaskGet',
    'TaskList',
    'TaskOutput',
    'TaskStop',
    'EnterPlanMode',
    'ExitPlanMode',
    'ScheduleWakeup',
    'SendMessage',
    'WebFetch',
    'WebSearch',
]);
// .hs.json is what privacy/scout read their on/off state from. If an agent could write it
// unattended, it could silently disable its own guard rails — so this check is NOT configurable
// through .hs.json (unlike privacy/scout) and always applies, regardless of hookConfig.
const CONFIG_PATH = /(^|[\\/\s'"`])\.hs\.json(?=$|[\\/\s'"`])/i;
const CONFIG_WRITE_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit']);
const BASH_WRITE_INDICATOR = /(>>?|\btee\b|\bsed\s+(?:-i|--in-place)|\bSet-Content\b|\bOut-File\b|\bmv\b|\bcp\b)/i;
const CONFIG_GUARD_REASON = 'Blocked by hs-skills config guard: .hs.json controls the guard rails themselves, so an agent may not edit it unattended — even to relax an over-eager rule. Stop and use AskUserQuestion to ask the user directly: state the specific rule that is misfiring and why, then offer concrete options (e.g. "fix the pattern in guard-rails.mjs" vs "disable this hook in .hs.json" vs "leave as-is"). Only proceed once the user has picked one.';

function findProjectRoot(startDirectory) {
    let current = path.resolve(startDirectory || process.cwd());
    while (true) {
        if (fs.existsSync(path.join(current, '.hs.json'))) return current;
        const parent = path.dirname(current);
        if (parent === current) return null;
        current = parent;
    }
}

export function readHookConfig(startDirectory = process.cwd()) {
    const root = findProjectRoot(startDirectory);
    if (!root) return { ...DEFAULT_HOOKS };

    try {
        const config = JSON.parse(fs.readFileSync(path.join(root, '.hs.json'), 'utf8'));
        const configuredHooks = config?.guardrails?.hooks;
        return {
            privacy: configuredHooks?.privacy ?? DEFAULT_HOOKS.privacy,
            scout: configuredHooks?.scout ?? DEFAULT_HOOKS.scout,
        };
    } catch {
        return { ...DEFAULT_HOOKS };
    }
}

function stringifyToolInput(input, depth = 0) {
    if (depth > 8 || input == null) return '';
    if (typeof input === 'string') return input;
    if (typeof input === 'number' || typeof input === 'boolean') return String(input);
    if (Array.isArray(input)) return input.map((value) => stringifyToolInput(value, depth + 1)).join(' ');
    if (typeof input === 'object') {
        return Object.entries(input)
            .filter(([key]) => !CONTENT_KEYS.has(key))
            .map(([, value]) => stringifyToolInput(value, depth + 1))
            .join(' ');
    }
    return '';
}

function block(hook, reason) {
    return { hook, action: 'block', reason };
}

export function evaluateGuardrails(event, hookConfig = readHookConfig(event?.cwd)) {
    const toolName = event?.tool_name ?? '';
    if (NON_FILESYSTEM_TOOLS.has(toolName)) return { action: 'allow' };

    const toolInput = stringifyToolInput(event?.tool_input ?? event);
    const isSafeBash = toolName === 'Bash' && SAFE_BASH.test(toolInput);

    if (CONFIG_PATH.test(toolInput)) {
        const isDirectWrite = CONFIG_WRITE_TOOLS.has(toolName);
        const isBashWrite = toolName === 'Bash' && BASH_WRITE_INDICATOR.test(toolInput);
        if (isDirectWrite || isBashWrite) {
            return block('config', CONFIG_GUARD_REASON);
        }
    }

    if (hookConfig.privacy && SENSITIVE_PATH.test(toolInput)) {
        return block('privacy', 'Blocked by hs-skills privacy guard: do not read secret files through the agent.');
    }

    if (hookConfig.scout && !isSafeBash) {
        if (HEAVY_DIRECTORY.test(toolInput)) {
            return block('scout', 'Blocked by hs-skills scout guard: avoid generated or dependency directories.');
        }
        if (ROOT_GLOB.test(toolInput)) {
            return block('scout', 'Blocked by hs-skills scout guard: narrow the repository-wide glob before reading files.');
        }
        if (PARENT_TRAVERSAL.test(toolInput)) {
            return block('scout', 'Blocked by hs-skills scout guard: do not traverse above the project root.');
        }
    }

    return { action: 'allow' };
}

function parseArguments(argv) {
    const index = argv.indexOf('--platform');
    return index === -1 ? 'codex' : argv[index + 1];
}

async function readStdin() {
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    const raw = Buffer.concat(chunks).toString('utf8').trim();
    return raw ? JSON.parse(raw) : {};
}

export async function main(argv = process.argv.slice(2)) {
    const platform = parseArguments(argv);
    const event = await readStdin();
    const decision = evaluateGuardrails(event);
    if (decision.action !== 'block') return 0;

    process.stdout.write(`${JSON.stringify({
        hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'deny',
            permissionDecisionReason: decision.reason,
        },
    })}\n`);
    return 0;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
    main().then((exitCode) => { process.exitCode = exitCode; }).catch((error) => {
        process.stderr.write(`hs-skills guard rail failed: ${error.message}\n`);
        process.exitCode = 1;
    });
}
