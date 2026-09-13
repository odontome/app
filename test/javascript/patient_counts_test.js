const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../app/assets/javascripts/patient_counts.js'), 'utf8');

function setup(fetch, { hasNav = true, today = null } = {}) {
  const badges = ['today', 'needs_follow_up', 'birthdays'].map(name => {
    const known = name === 'today' && today !== null;
    const attributes = { 'aria-busy': known ? 'false' : 'true', 'aria-label': 'Loading count' };
    const classes = new Set();
    return { dataset: { patientCount: name }, textContent: known ? today : '…',
      getAttribute: name => attributes[name], removeAttribute: name => delete attributes[name],
      classList: { add: name => classes.add(name), contains: name => classes.has(name) } };
  });
  let ready;
  let expire;
  let cleared = false;
  const nav = { dataset: { patientCountsUrl: '/patients/segment_counts.json' }, querySelectorAll: () => badges };
  vm.runInNewContext(source, {
    document: { querySelector: () => hasNav ? nav : null, addEventListener: (_name, callback) => { ready = callback; } },
    window: { setTimeout: callback => { expire = callback; return 1; }, clearTimeout: () => { cleared = true; } },
    AbortController, fetch
  });
  return { badges, ready: () => ready(), expire: () => expire(), get cleared() { return cleared; } };
}

test('loads fresh counts after the document is ready and displays zero correctly', async () => {
  let request;
  let resolve;
  const ui = setup((url, options) => { request = { url, options }; return new Promise(done => { resolve = done; }); });
  assert.equal(request, undefined);
  const pending = ui.ready();
  assert.deepEqual(ui.badges.map(badge => badge.textContent), ['…', '…', '…']);
  assert.equal(request.url, '/patients/segment_counts.json');
  assert.equal(request.options.cache, 'no-store');
  assert.equal(request.options.credentials, 'same-origin');
  resolve({ ok: true, json: async () => ({ today: 0, needs_follow_up: 6036, birthdays: 127 }) });
  await pending;
  assert.deepEqual(ui.badges.map(badge => badge.textContent), [0, 6036, 127]);
  ui.badges.forEach(badge => {
    assert.equal(badge.getAttribute('aria-busy'), undefined);
    assert.equal(badge.getAttribute('aria-label'), undefined);
    assert.equal(badge.classList.contains('d-none'), false);
  });
  assert.equal(ui.cleared, true);
});

test('does not fetch on pages without patient tabs', async () => {
  const ui = setup(() => assert.fail('unexpected request'), { hasNav: false });
  await ui.ready();
});

for (const [name, fetch] of Object.entries({
  network: async () => { throw new Error('offline'); },
  server: async () => ({ ok: false }),
  login: async () => ({ ok: true, json: async () => { throw new Error('HTML login page'); } }),
  missing: async () => ({ ok: true, json: async () => ({ today: 0 }) }),
  negative: async () => ({ ok: true, json: async () => ({ today: 0, needs_follow_up: -1, birthdays: 2 }) }),
  markup: async () => ({ ok: true, json: async () => ({ today: '<img>', needs_follow_up: 1, birthdays: 2 }) })
})) {
  test(`${name} failure hides unknown counts and preserves the rendered Today count`, async () => {
    const ui = setup(fetch, { today: 4 });
    await ui.ready();
    assert.equal(ui.badges[0].textContent, 4);
    assert.equal(ui.badges[0].classList.contains('d-none'), false);
    ui.badges.slice(1).forEach(badge => {
      assert.equal(badge.classList.contains('d-none'), true);
      assert.equal(badge.getAttribute('aria-busy'), undefined);
      assert.equal(badge.textContent, '…');
    });
    assert.equal(ui.cleared, true);
  });
}

test('a stalled request stops loading after the timeout', async () => {
  const ui = setup((_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(new Error('aborted')));
  }));
  const pending = ui.ready();
  ui.expire();
  await pending;
  assert.equal(ui.cleared, true);
  ui.badges.forEach(badge => assert.equal(badge.classList.contains('d-none'), true));
});
