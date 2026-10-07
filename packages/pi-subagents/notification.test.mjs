// Exercise the installed notification callbacks without a provider or Pi session.
// The package omits Pi peer APIs; Node strips types from the actual patched source.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const root = resolve(process.env.PI_SUBAGENTS_SOURCE || '.');
const source = readFileSync(resolve(root, 'src/index.ts'), 'utf8');
const xml = readFileSync(resolve(root, 'src/xml.ts'), 'utf8');
function declaration(name, indent = '') {
  const match = source.match(new RegExp(`^${indent}function ${name}\\([^]*?^${indent}\\}`, 'm'));
  assert.ok(match, `Missing production function: ${name}`);
  return match[0];
}
const groupStart = source.indexOf('  const groupJoin = new GroupJoinManager(');
const groupEnd = source.indexOf('  /** Helper: build event data', groupStart);
assert.ok(groupStart >= 0 && groupEnd > groupStart, 'Missing production group callback');
const production = stripTypeScriptTypes([
  xml.replace('export function', 'function'),
  declaration('formatTaskNotification'),
  declaration('buildNotificationDetails'),
  declaration('scheduleNudge', '  '),
  declaration('cancelNudge', '  '),
  declaration('emitIndividualNudge', '  '),
  source.slice(groupStart, groupEnd),
  '({ scheduleNudge, emitIndividualNudge, deliverGroup: groupJoin.deliver })',
].join('\n'));

function harness() {
  const messages = [], warnings = [], timers = new Map();
  const context = {
    Error,
    showCost: false,
    agentActivity: new Map(),
    pendingNudges: new Map(),
    NUDGE_HOLD_MS: 200,
    setTimeout: fn => { const id = {}; timers.set(id, fn); return id; },
    clearTimeout: id => timers.delete(id),
    console: { warn: (...args) => warnings.push(args.join(' ')) },
    getStatusLabel: status => status === 'error' ? 'Error' : 'Done',
    getStatusNote: () => '',
    getLifetimeTotal: () => 0,
    getSessionContextPercent: () => null,
    getLifetimeCost: () => 0,
    widget: { update() {}, markFinished() {} },
    fleet: { onAgentFinished() {} },
    GroupJoinManager: class { constructor(deliver) { this.deliver = deliver; } },
    pi: { sendMessage: (message, options) => messages.push({ message, options }) },
  };
  const callbacks = runInNewContext(production, context);
  const flush = () => {
    for (const [id, fn] of [...timers]) { timers.delete(id); fn(); }
  };
  return { ...callbacks, context, messages, warnings, flush };
}
const record = overrides => ({
  id: 'unread-agent', type: 'astraeus-worker', status: 'completed',
  startedAt: 1, completedAt: 2, toolUses: 0, result: 'finished <work>',
  ...overrides,
});
function assertDelivery(delivery, id, description) {
  assert.equal(delivery.message.customType, 'subagent-notification');
  assert.equal(delivery.message.display, true);
  assert.equal(delivery.message.details.id, id);
  assert.equal(delivery.message.details.description, description);
  assert.equal(delivery.options.deliverAs, 'followUp');
  assert.equal(delivery.options.triggerTurn, true);
  assert.ok(delivery.message.content.includes('finished &lt;work&gt;'));
}

test('missing RPC description still delivers an actionable completion notification', () => {
  const h = harness(), r = record();
  h.scheduleNudge(r.id, () => h.emitIndividualNudge(r));
  h.flush();
  assert.equal(h.messages.length, 1);
  assertDelivery(h.messages[0], r.id, r.type);
  assert.ok(h.messages[0].message.content.includes('Agent "astraeus-worker" completed'));
  assert.deepEqual(h.warnings, []);
});

test('group notification tolerates absent descriptions and excludes consumed results', () => {
  const h = harness();
  const first = record(), second = record({ id: 'other', description: 'task & review' });
  h.deliverGroup([first, second, record({ id: 'consumed', resultConsumed: true })], false);
  h.flush();
  assert.equal(h.messages.length, 1);
  assertDelivery(h.messages[0], first.id, first.type);
  assert.equal(h.messages[0].message.details.others[0].description, 'task & review');
  assert.ok(h.messages[0].message.content.includes('Agent "task &amp; review" completed'));
  assert.ok(!h.messages[0].message.content.includes('<task-id>consumed</task-id>'));
});

test('a result consumed during the hold window does not trigger another turn', () => {
  const h = harness(), r = record();
  h.scheduleNudge(r.id, () => h.emitIndividualNudge(r));
  r.resultConsumed = true;
  h.flush();
  h.deliverGroup([r], false);
  h.flush();
  assert.deepEqual(h.messages, []);
});

test('failure status remains deliverable without a description', () => {
  const h = harness(), r = record({ status: 'error', error: 'child failed' });
  h.scheduleNudge(r.id, () => h.emitIndividualNudge(r));
  h.flush();
  assert.equal(h.messages.length, 1);
  assertDelivery(h.messages[0], r.id, r.type);
  assert.equal(h.messages[0].message.details.error, 'child failed');
  assert.equal(h.messages[0].message.details.status, 'error');
});

test('synchronous notification delivery errors are diagnosed, not silently swallowed', () => {
  const h = harness(), r = record({ description: 'task' });
  h.context.pi.sendMessage = () => { throw new Error('stale send'); };
  h.scheduleNudge(r.id, () => h.emitIndividualNudge(r));
  assert.doesNotThrow(h.flush);
  assert.equal(h.warnings.length, 1);
  assert.match(h.warnings[0], /unread-agent/);
  assert.match(h.warnings[0], /stale send/);
});
