const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../app/assets/javascripts/odontogram.js'), 'utf8');

test('uncertain saves keep retry available but allow changing the treatment and status', () => {
  const elements = new Map();
  const context = { editable: true, loading: false, busy: false, ready: true, pending: {}, undo: [], desktop: { matches: true },
    root: { setAttribute() {} }, $: selector => { if (!elements.has(selector)) elements.set(selector, {}); return elements.get(selector); } };
  vm.runInNewContext(source.slice(source.indexOf('    const canWrite ='), source.indexOf('    function adopt(')), context);
  context.controls();
  assert.equal(elements.get('[data-tool]').disabled, false);
  assert.equal(elements.get('[data-treatment-status]').disabled, false);
  assert.equal(elements.get('[data-retry]').hidden, false);
  assert.equal(elements.get('[data-undo]').disabled, true);
  assert.equal(vm.runInNewContext('canWrite()', context), false);
  context.pending = null; context.ready = false;
  assert.equal(vm.runInNewContext('canWrite()', context), false);
  context.ready = true;
  assert.equal(vm.runInNewContext('canWrite()', context), true);
  context.busy = true; context.controls();
  assert.equal(elements.get('[data-tool]').disabled, true);
});

test('choosing another treatment abandons retry and reloads authoritative state before a new save', () => {
  let loads = 0;
  const context = { pending: { body: { request_id: 'original' } }, selected: null, menuForTooth: false,
    draftSurfaces: new Set(), closeMenu() {}, closeDetails() {}, render() {}, showDetails() {},
    load: () => { loads++; }, $: () => ({ focus() {} }) };
  vm.runInNewContext(source.slice(source.indexOf('    function choose('), source.indexOf('    function add(')), context);
  context.choose('filling');
  assert.equal(context.active, 'filling');
  assert.equal(context.pending, null);
  assert.equal(loads, 1);
});

test('footer feedback restarts its fade and yellow highlight without animating loading or reduced motion', () => {
  const animations = [], cancelled = [], text = {};
  const feedback = { getAnimations: () => [{ cancel: () => cancelled.push(true) }], animate: (...args) => animations.push(args) };
  const context = { $: selector => selector === '[data-feedback]' ? feedback : text,
    matchMedia: () => ({ matches: false }) };
  vm.runInNewContext(source.slice(source.indexOf('    const status ='), source.indexOf('    function reportFormError(')), context);
  vm.runInNewContext("status('Could not save'); status('Could not save')", context);
  assert.equal(text.textContent, 'Could not save');
  assert.equal(animations.length, 2);
  assert.equal(animations[0][0][0].opacity, 0);
  assert.equal(animations[0][0][0].backgroundColor, 'var(--tblr-warning-lt)');
  assert.equal(animations[0][0].at(-1).backgroundColor, 'transparent');
  vm.runInNewContext("status('Saving', false); status('')", context);
  assert.equal(animations.length, 2);
  context.matchMedia = () => ({ matches: true });
  vm.runInNewContext("status('Saved')", context);
  assert.equal(text.textContent, 'Saved');
  assert.equal(animations.length, 2);
  assert.equal(cancelled.length, 5);
});

test('server failure releases busy state and retry uses the exact original request identity', async () => {
  const bodies = [];
  const context = { busy: false, pending: null, selected: null, canWrite: () => true,
    uuid: () => 'request-1', editor: 'editor-1', revision: 7, controls() {}, status() {},
    root: { dataset: { endpoint: '/chart' } }, document: { querySelector: () => ({ content: 'token' }) },
    copy: { saving: 'Saving', failed: 'Failed' },
    fetch: async (_url, options) => { bodies.push(options.body); return { status: 500 }; } };
  vm.runInNewContext(source.slice(source.indexOf('    async function save('), source.indexOf("    arches.addEventListener('click'")), context);
  await context.save({ operation: 'add', odontogram_entry: { category: 'crown', tooth: 16 } }, { tooth: 16 });
  assert.equal(context.busy, false);
  assert.equal(context.pending.body.request_id, 'request-1');
  await context.save(context.pending.payload, context.pending.entry, context.pending.body);
  assert.equal(context.busy, false);
  assert.equal(bodies[0], bodies[1]);
});

test('a conflicting edit blocks further writes until the chart is refreshed', async () => {
  const elements = new Map();
  const context = { busy: false, pending: null, selected: null, editable: true, loading: false, ready: true,
    desktop: { matches: true }, undo: [{ id: 1 }], uuid: () => 'new-editor', editor: 'editor', revision: 7,
    status() {}, forgetEditorSession() {}, root: { dataset: { endpoint: '/chart' }, setAttribute() {} },
    document: { querySelector: () => ({ content: 'token' }) }, copy: { saving: 'Saving' },
    $: selector => { if (!elements.has(selector)) elements.set(selector, {}); return elements.get(selector); },
    fetch: async () => ({ status: 409, ok: false, json: async () => ({ error: 'Refresh chart' }) }) };
  vm.runInNewContext(source.slice(source.indexOf('    const canWrite ='), source.indexOf('    function adopt(')), context);
  vm.runInNewContext(source.slice(source.indexOf('    async function save('), source.indexOf("    arches.addEventListener('click'")), context);
  await context.save({ operation: 'add' }, { tooth: 16 });
  assert.equal(context.ready, false);
  assert.equal(vm.runInNewContext('canWrite()', context), false);
  assert.equal(elements.get('[data-refresh]').hidden, false);
  assert.equal(elements.get('[data-tool]').disabled, false);
  assert.equal(context.undo.length, 0);
});

test('changing treatment after a conflict fetches the latest chart before entry resumes', () => {
  let loads = 0;
  const context = { ready: false, pending: null, selected: null, menuForTooth: false,
    draftSurfaces: new Set(), closeMenu() {}, closeDetails() {}, render() {}, showDetails() {},
    load: () => { loads++; }, $: () => ({ focus() {} }) };
  vm.runInNewContext(source.slice(source.indexOf('    function choose('), source.indexOf('    function add(')), context);
  context.choose('filling');
  assert.equal(context.active, 'filling');
  assert.equal(loads, 1);
});

test('cancelling removal preserves a shared marking and confirmation submits its single identity', () => {
  const buttons = [], saved = [], prompts = [];
  const element = () => ({ dataset: {}, append() {}, replaceChildren() {}, setAttribute() {}, querySelectorAll: () => [] });
  const entry = { id: 42, tooth: 16, member_teeth: [16, 15], treatment_status: 'existing' };
  const context = { desktop: { matches: true }, mode: 'inspect', selected: 15, active: '', editable: true,
    busy: false, pending: null, formError: '', editor: 'test', root: {}, details: element(), entries: [entry],
    node: element, button: (text, action) => { const item = { ...element(), text, action }; buttons.push(item); return item; },
    disposeDetailsPopover() {}, closeDetails() {}, toothLabel: n => 'Tooth ' + n,
    markingLabel: () => 'Fixed bridge', label: () => 'Fixed bridge · 16, 15', entryTeeth: e => e.member_teeth,
    toothHistoryPath: () => '/history', canWrite: () => true, save: (...args) => saved.push(args),
    window: { confirm: text => { prompts.push(text); return false; } },
    copy: { close: 'Close', remove: 'Remove', add: 'Add marking', view_history: 'History', confirm_remove: 'Remove %{marking}?' },
    arches: { querySelector: () => ({}) }, tabler: { Popover: class { show() {} } } };
  vm.runInNewContext(source.slice(source.indexOf('    function showDetails('), source.indexOf('    let menuForTooth =')), context);
  context.showDetails(false);
  const remove = buttons.find(item => item.text === 'Remove');
  remove.action();
  assert.equal(prompts[0], 'Remove Fixed bridge · 16, 15?');
  assert.equal(saved.length, 0);
  context.window.confirm = () => true;
  remove.action();
  assert.equal(saved.length, 1);
  assert.equal(saved[0][0].operation, 'remove');
  assert.equal(saved[0][0].entry_id, 42);
  assert.equal(saved[0][1], entry);
  context.canWrite = () => false;
  remove.action();
  assert.equal(saved.length, 1);
});
