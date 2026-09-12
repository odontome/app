const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const asset = name => fs.readFileSync(path.join(__dirname, '../../app/assets/javascripts', name), 'utf8');


const treatmentCategories = ['filling','temporary_filling','sealant','inlay','veneer','crown','temporary_crown','rct','pulpotomy','post','core','implant','fixed_orthodontic','removable_orthodontic','complete_denture','partial_denture','fixed_bridge'];
function runChartCode(source, context) {
  context.treatmentCategories ??= treatmentCategories;
  context.treatmentStatus ??= 'existing';
  context.planning ??= () => context.treatmentCategories.includes(context.active) && context.treatmentStatus === 'planned';
  context.present ??= entry => entry.treatment_status !== 'planned';
  context.sameStage ??= entry => context.planning() ? !context.present(entry) : context.present(entry);
  return vm.runInNewContext(source, context);
}

test('every treatment entry sends the retained status while findings have no treatment choice', () => {
  const source = asset('odontogram.js'), saved = [];
  const context = { active: 'crown', treatmentStatus: 'planned', canWrite: () => true,
    surfaceCategories: [], optionalSurfaceCategories: [], groupCategories: [], pairedCategories: [], activePreset: null,
    copy: {}, save: payload => saved.push(payload), entries: [],
    bridgeUnits: () => [{ tooth: 16, role: 'natural_support' }, { tooth: 15, role: 'pontic' }], bridgeRoleReason: () => '',
    dentureReason: () => '', replacementReason: () => '', draftReplacement: new Set([16,15]), archForTooth: () => 'upper', toothArches: [[16,15]],
    draftMobility: { grade: '', scale: '' } };
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  for (const category of treatmentCategories) {
    context.active = category;
    for (const status of ['planned', 'existing']) {
      context.treatmentStatus = status;
      context.add(16, ['M','O']);
      assert.equal(saved.at(-1).odontogram_entry.treatment_status, status, category);
      assert.equal(saved.at(-1).odontogram_entry.category, category);
    }
  }
  context.active = 'crown'; context.treatmentStatus = 'planned';
  context.entries = [{ id: 1, tooth: 16, category: 'crown', surfaces: [], treatment_status: 'existing' }];
  const before = saved.length; context.add(16, []);
  assert.equal(saved.length, before + 1, 'a plan can coexist with the existing crown');
  context.entries = [];
  context.active = 'caries'; context.treatmentStatus = 'planned'; context.add(16, ['O']);
  assert.equal(Object.hasOwn(saved.at(-1).odontogram_entry, 'treatment_status'), false);
});

test('planned implants do not disable current attachment choices and plans can target future denture positions', () => {
  const source = asset('odontogram.js');
  const context = { active: 'fixed_orthodontic', entries: [{ tooth: 16, category: 'implant', treatment_status: 'planned' }],
    attachmentConflicts: ['missing','implant','retained_root','edentulous_arch'],
    copy: { categories: { implant: 'Implant' }, attachment_unavailable: 'Unavailable: %{reason}', partial_absence: 'Record absence first', denture_overlap: 'Occupied' } };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function extentTeeth(')), context);
  runChartCode(source.slice(source.indexOf('    function attachmentReason('), source.indexOf('    function showDetails(')), context);
  assert.equal(context.attachmentReason(16), '');
  context.entries[0].treatment_status = 'completed';
  assert.equal(context.attachmentReason(16), 'Unavailable: Implant');
  context.active = 'partial_denture'; context.entries = []; context.treatmentStatus = 'planned';
  assert.equal(context.replacementReason(16), '');
  context.treatmentStatus = 'existing';
  assert.equal(context.replacementReason(16), 'Record absence first');
});

test('every catalogue mode keeps the correct quick entry form inspect and read-only behavior', () => {
  const modes = JSON.parse(fs.readFileSync(path.join(__dirname, '../fixtures/files/odontogram_entry_modes.json'), 'utf8'));
  const callbacks = {}, calls = [], source = asset('odontogram.js');
  const context = { arches: { addEventListener: (name, callback) => { callbacks[name] = callback; } },
    suppressClick: false, busy: false, pending: null, editable: true, groupCategories: ['fixed_orthodontic','removable_orthodontic'],
    pairedCategories: ['diastema','fusion','transposition'], surfaceCategories: Object.keys(modes).filter(key => modes[key].startsWith('surface_')),
    draftSurfaces: new Set(), render: () => calls.push('render'), showDetails: () => calls.push('details'), add: () => calls.push('save') };
  runChartCode(source.slice(source.indexOf("    arches.addEventListener('click'"), source.indexOf("    arches.addEventListener('pointerdown'")), context);
  const event = number => ({ target: { closest: selector => selector === '[data-tooth]' ? { dataset: { tooth: '16' } } : selector === '.od-tooth-number' && number ? {} : null } });
  for (const [category, mode] of Object.entries(modes)) {
    context.active = category; context.editable = true; calls.length = 0;
    callbacks.click(event(false));
    assert.deepEqual(calls, mode === 'quick_tooth' ? ['save'] : ['render','details'], category);
    if (mode !== 'quick_tooth') assert.equal(context.mode, 'add', category);
    calls.length = 0; callbacks.click(event(true));
    assert.equal(context.mode, 'inspect', category);
    assert.equal(calls.includes('save'), false, category);
    calls.length = 0; context.editable = false; callbacks.click(event(false));
    assert.equal(context.mode, 'inspect', category);
    assert.equal(calls.includes('save'), false, category);
  }
});

test('all surface families preserve single and grouped drag entry without crossing teeth or saving cancelled gestures', () => {
  const modes = JSON.parse(fs.readFileSync(path.join(__dirname, '../fixtures/files/odontogram_entry_modes.json'), 'utf8'));
  const categories = Object.keys(modes).filter(key => modes[key].startsWith('surface_'));
  const source = asset('odontogram.js'), callbacks = {}, saved = [];
  let hit;
  const context = { active: '', drag: null, suppressClick: false, surfaceCategories: categories, canWrite: () => true,
    arches: { addEventListener: (name, callback) => { callbacks[name] = callback; } },
    document: { addEventListener: (name, callback) => { callbacks[name] = callback; }, elementFromPoint: () => hit },
    root: { querySelectorAll: () => [] }, setTimeout: callback => callback(),
    add: (tooth, surfaces) => saved.push({ tooth, surfaces: Array.from(surfaces) }) };
  runChartCode(source.slice(source.indexOf("    arches.addEventListener('pointerdown'"), source.indexOf("    $('[data-tool]').addEventListener")), context);
  const target = (tooth, surface) => ({ closest: selector => selector === '[data-tooth]' ? { dataset: { tooth: String(tooth) } } :
    { dataset: { part: 'surface-' + surface }, setAttribute() {} } });
  for (const category of categories) {
    context.active = category; saved.length = 0;
    const down = { target: target(16,'O'), button: 0, preventDefault() {} };
    callbacks.pointerdown(down); callbacks.pointerup();
    assert.deepEqual(saved[0], { tooth: 16, surfaces: ['O'] }, category);
    callbacks.pointerdown(down);
    hit = target(16,'M'); callbacks.pointermove({});
    hit = target(17,'D'); callbacks.pointermove({});
    hit = target(16,'O'); callbacks.pointermove({}); callbacks.pointerup();
    assert.deepEqual(saved[1], { tooth: 16, surfaces: ['O','M'] }, category);
    callbacks.pointerdown(down); callbacks.pointercancel(); callbacks.pointerup();
    assert.equal(saved.length, 2, category);
  }
  context.active = 'veneer'; saved.length = 0;
  callbacks.pointerdown({ target: target(16,'O'), button: 0 }); callbacks.pointerup();
  assert.equal(saved.length, 0);
});

test('bridge entry uses explicit roles and exact implant IDs and explains invalid support choices', () => {
  const source = asset('odontogram.js'), saved = [], errors = [];
  const context = { active: 'fixed_bridge', canWrite: () => true, surfaceCategories: [], optionalSurfaceCategories: [],
    groupCategories: [], pairedCategories: [], activePreset: null,
    entries: [{ id: 7, category: 'implant', tooth: 16, surfaces: [] }, { category: 'missing', tooth: 15, surfaces: [] }],
    toothArches: [[16,15,14,13]], draftBridgeEnd: '14', draftBridgeRoles: {},
    copy: { bridge_choose_role: 'Choose roles', bridge_choose_end: 'Choose span', bridge_support: 'Review %{tooth}', bridge_overlap: 'Occupied' },
    reportFormError: error => errors.push(error), save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function mobilityDetail(')), context);
  runChartCode(source.slice(source.indexOf('    function bridgeRoleReason('), source.indexOf('    function dentureReason(')), context);
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(16, []);
  assert.equal(errors.at(-1), 'Choose roles');
  assert.equal(context.bridgeRoleReason(16, 'natural_support'), 'Review 16');
  assert.equal(context.bridgeRoleReason(16, 'implant_support'), '');
  assert.equal(context.bridgeRoleReason(14, 'pontic'), 'Review 14');
  context.draftBridgeRoles = { 16: 'implant_support', 15: 'pontic', 14: 'natural_support' };
  context.add(16, []);
  assert.equal(saved[0].odontogram_entry.bridge_units[0].implant_entry_id, 7);
  assert.deepEqual(Array.from(saved[0].odontogram_entry.bridge_units, unit => unit.tooth), [16,15,14]);
  context.entries.push({ category: 'partial_denture', member_teeth: [15], tooth: 15, surfaces: [] });
  context.add(16, []);
  assert.equal(saved.length, 1);
  assert.equal(errors.at(-1), 'Occupied');
});

test('denture availability explains blank and occupied teeth and identifies when nothing can be selected', () => {
  const source = asset('odontogram.js');
  const context = { active: 'partial_denture', entries: [], toothArches: [[16,15,14]], archForTooth: () => 'upper',
    copy: { partial_absence: 'Record absence first', partial_picker_hint: 'Unmarked is unrecorded. Choose Missing first.',
      denture_overlap: 'Already covered', denture_absence: 'Record arch absence' } };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function extentTeeth(')), context);
  runChartCode(source.slice(source.indexOf('    function replacementReason('), source.indexOf('    function showDetails(')), context);
  let state = context.dentureAvailability(16);
  assert.equal(state.eligible.length, 0);
  assert.deepEqual(Array.from(state.hints), [context.copy.partial_picker_hint]);
  context.entries = [{ category: 'missing', tooth: 16 }];
  state = context.dentureAvailability(16);
  assert.deepEqual(Array.from(state.eligible), [16]);
  assert.deepEqual(Array.from(state.hints), [context.copy.partial_picker_hint]);
  context.entries.push({ category: 'partial_denture', arch: 'upper', member_teeth: [16] });
  state = context.dentureAvailability(16);
  assert.equal(state.eligible.length, 0);
  assert.deepEqual(Array.from(state.hints), [context.copy.denture_overlap, context.copy.partial_picker_hint]);
  context.entries = [{ category: 'complete_denture', arch: 'upper', member_teeth: [16,15,14] }];
  state = context.dentureAvailability(16);
  assert.equal(state.eligible.length, 0);
  assert.deepEqual(Array.from(state.hints), [context.copy.denture_overlap]);
  context.active = 'complete_denture'; context.entries = [];
  state = context.dentureAvailability(16);
  assert.equal(state.eligible.length, 0);
  assert.deepEqual(Array.from(state.hints), [context.copy.denture_absence]);
  context.entries.push({ category: 'edentulous_arch', arch: 'upper', member_teeth: [16,15,14] });
  state = context.dentureAvailability(16);
  assert.deepEqual(Array.from(state.eligible), [16,15,14]);
  assert.equal(state.hints.length, 0);
});

test('opening on a phone makes no chart or artwork requests and constructs no drawing', () => {
  const listeners = {};
  const element = { addEventListener() {}, cloneNode() { return {}; } };
  const root = { dataset: { treatmentCategories: JSON.stringify(treatmentCategories), archTeeth: '{}', attachmentConflicts: '["missing","implant","retained_root"]', groupCategories: '["fixed_orthodontic","removable_orthodontic"]', toothArches: '[]', pairedCategories: '["diastema","fusion","transposition"]', pairedNeighbors: '{}', transpositionPartners: '{}', surfaceCategories: '[]', optionalSurfaceCategories: '[]', copy: JSON.stringify({ categories: {} }) },
    querySelector() { return element; }, addEventListener() {} };
  let requests = 0, createdElements = 0;
  runChartCode(asset('odontogram.js'), {
    crypto: { randomUUID: () => 'editor-id' },
    matchMedia: () => ({ matches: false, addEventListener() {} }),
    window: { addEventListener() {} },
    document: {
      addEventListener: (name, callback) => { listeners[name] = callback; },
      querySelectorAll: () => [root],
      querySelector: () => root,
      createElement: () => { createdElements++; return element; }
    },
    fetch: () => { requests++; }
  });
  listeners.DOMContentLoaded();
  assert.equal(requests, 0);
  assert.equal(createdElements, 0);
});

test('bundled artwork covers every standard tooth and its anatomical surface identities', () => {
  const context = { window: {} };
  runChartCode(asset('odontogram-artwork.js'), context);
  const artwork = context.window.OdontogramArtwork;
  assert.equal(Object.keys(artwork).length, 52);
  for (let quadrant = 1; quadrant <= 8; quadrant++) {
    for (let position = 1; position <= (quadrant <= 4 ? 8 : 5); position++) {
      const tooth = quadrant * 10 + position, a = artwork[tooth];
      assert.ok(a, String(tooth));
      const expected = [position <= 3 ? 'F' : 'B', 'M', [1,2,5,6].includes(quadrant) ? 'P' : 'L', 'D', position <= 3 ? 'I' : 'O'];
      assert.deepEqual(Array.from(a.surfaceNames), expected);
      expected.forEach(surface => assert.ok(a.svg.includes('data-part="surface-' + surface + '"'), tooth + ' ' + surface));
      assert.equal(a.lower, [3,4,7,8].includes(quadrant));
      assert.ok(a.canalGuides.length > 0);
      assert.doesNotMatch(a.svg, /<script|\bon\w+=|<foreignObject|<image|href=/i);
    }
  }
});

test('saved charts load their exact moment and cannot adopt editable controls', async () => {
  const requests = [], messages = [];
  const element = {};
  const saved = { id: 1, tooth: 16, category: 'crown', surfaces: [] };
  const context = {
    root: { dataset: { endpoint: '/patients/4/odontogram', snapshotId: '12', changedTeeth: '[11]' }, classList: { add() {} } },
    entries: [], presets: [], revision: 0, editable: false, changedTeeth: [], active: 'crown', activePreset: null,
    undo: ['previous edit'], editor: 'old', uuid: () => 'new', ready: false, loading: false,
    desktop: { matches: true }, window: { OdontogramArtwork: {} },
    $: () => element, controls() {}, render() {}, updateSummary() {},
    copy: { unrecorded: 'Unrecorded', read_only: 'Saved chart', load_failed: 'Failed' },
    status: message => messages.push(message),
    fetch: async url => {
      requests.push(url);
      return { ok: true, json: async () => ({ revision: 5, editable: true, entries: [saved], presets: [], comparison: { teeth: [99] } }) };
    }
  };
  const source = asset('odontogram.js');
  runChartCode(source.slice(source.indexOf('    function adopt('), source.indexOf('    function updateSummary(')), context);
  await context.load();
  assert.deepEqual(requests, ['/patients/4/odontogram.json?at=12']);
  assert.equal(context.editable, false);
  assert.equal(context.active, '');
  assert.equal(context.undo.length, 0);
  assert.equal(context.entries[0], saved);
  assert.deepEqual(Array.from(context.changedTeeth), [11]);
  assert.deepEqual(messages, ['Saved chart']);
});

test('returning to the current chart loads server-confirmed undo for the retained editor', async () => {
  const requests = [], remembered = [];
  const editor = '00000000-0000-4000-8000-000000000001';
  const actions = [{ id: 10, operation: 'add', entry: { tooth: 16, category: 'crown', surfaces: [] } }];
  const context = {
    root: { dataset: { endpoint: '/patients/4/odontogram' }, classList: { add() {} } },
    entries: [], presets: [], revision: 0, editable: false, changedTeeth: [], active: '', activePreset: null,
    undo: ['stale'], editor, uuid: () => 'new', ready: false, loading: false,
    desktop: { matches: true }, window: { OdontogramArtwork: {} },
    $: () => ({}), controls() {}, render() {}, updateSummary() {}, status() {},
    rememberEditorSession: (_root, id) => remembered.push(id), forgetEditorSession() {},
    copy: { unrecorded: 'Unrecorded' },
    fetch: async url => { requests.push(url); return { ok: true, json: async () => ({ revision: 4, editable: true, entries: [], undo: actions, arch_conflicts: { upper: [42], lower: [] } }) }; }
  };
  const source = asset('odontogram.js');
  runChartCode(source.slice(source.indexOf('    function adopt('), source.indexOf('    function updateSummary(')), context);
  await context.load();
  assert.deepEqual(requests, ['/patients/4/odontogram.json?editor_id=' + editor]);
  assert.equal(context.undo, actions);
  assert.deepEqual(context.archConflicts, { upper: [42], lower: [] });
  assert.equal(context.editable, true);
  assert.equal(context.revision, 4);
  assert.deepEqual(remembered, [editor]);
});

function errorHarness(overrides = {}) {
  const calls = [], error = { hidden: true, textContent: '', focus: () => calls.push('focus'), scrollIntoView: () => calls.push('scroll') };
  const context = {
    selected: 15, mode: 'add', active: 'wear', editable: true, formError: '',
    status: message => calls.push(['status', message]),
    showDetails: () => calls.push('render'),
    details: { querySelector: () => error }, ...overrides
  };
  const source = asset('odontogram.js');
  // Exercise the actual error handlers independently of Popper positioning.
  runChartCode(source.slice(source.indexOf('    function reportFormError('), source.indexOf('    const button =')), context);
  return { context, calls, error };
}

test('validation errors on the open tooth form clear the footer and focus the popover message', () => {
  const { context, calls } = errorHarness();
  context.reportFormError('Choose today or an earlier date.', 15);
  assert.equal(context.formError, 'Choose today or an earlier date.');
  assert.deepEqual(calls, [['status', ''], 'render', 'focus', 'scroll']);
});

test('errors without a matching editable form remain available in the chart status', () => {
  for (const state of [{ selected: null }, { selected: 16 }, { editable: false }]) {
    const { context, calls } = errorHarness(state);
    context.reportFormError('Could not add marking.', 15);
    assert.equal(context.formError, '');
    assert.deepEqual(calls.at(-1), ['status', 'Could not add marking.']);
    assert.equal(calls.includes('focus'), false);
  }
});

test('completion errors stay inside the inspect popover', () => {
  const { context, calls } = errorHarness({ mode: 'inspect' });
  context.reportFormError('Review the existing crown first.', 15);
  assert.equal(context.formError, 'Review the existing crown first.');
  assert.deepEqual(calls, [['status', ''], 'render', 'focus', 'scroll']);
});

test('editing a form clears its previous error without rebuilding the inputs', () => {
  const { context, calls, error } = errorHarness({ formError: 'Invalid date' });
  error.hidden = false; error.textContent = 'Invalid date';
  context.clearFormError();
  assert.equal(context.formError, '');
  assert.equal(error.hidden, true);
  assert.equal(error.textContent, '');
  assert.deepEqual(calls, []);
});


test('tooth history links retain the saved moment only for historical charts', () => {
  const source = asset('odontogram.js');
  const context = {};
  runChartCode(source.slice(source.indexOf('  function toothHistoryPath('), source.indexOf('  function forgetEditorSession(')), context);
  const root = { dataset: { endpoint: '/patients/4/odontogram' } };
  assert.equal(context.toothHistoryPath(root, 13), '/patients/4/odontogram?tooth=13');
  root.dataset.snapshotId = '42';
  assert.equal(context.toothHistoryPath(root, 13), '/patients/4/odontogram?tooth=13&through=42');
});

test('mobility labels never display a grade without its recorded scale', () => {
  const source = asset('odontogram.js'), context = {};
  runChartCode(source.slice(source.indexOf('  function mobilityDetail('), source.indexOf('  function toothHistoryPath(')), context);
  assert.equal(context.mobilityDetail({}), '');
  assert.equal(context.mobilityDetail({ mobility_grade: 'II' }), '');
  assert.equal(context.mobilityDetail({ mobility_grade: 'II', mobility_scale: 'Miller' }), 'II (Miller)');
});

test('mobility and rotation open their detail forms instead of saving immediately', () => {
  const source = asset('odontogram.js'), callbacks = {}, calls = [];
  const context = { arches: { addEventListener: (name, callback) => { callbacks[name] = callback; } },
    suppressClick: false, busy: false, pending: null, active: 'mobility', editable: true,
    groupCategories: ["fixed_orthodontic","removable_orthodontic"], pairedCategories: ['diastema', 'fusion', 'transposition'], surfaceCategories: [], draftSurfaces: new Set(), render: () => calls.push('render'),
    showDetails: () => calls.push('details'), add: () => calls.push('save') };
  runChartCode(source.slice(source.indexOf("    arches.addEventListener('click'"), source.indexOf("    arches.addEventListener('pointerdown'")), context);
  const event = { target: { closest: selector => selector === '[data-tooth]' ? { dataset: { tooth: '16' } } : null } };
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.selected, 16);
  assert.equal(context.mode, 'add');
  calls.length = 0;
  context.active = 'removable_orthodontic';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.draftExtent, 'arch');
  calls.length = 0;
  context.active = 'fixed_orthodontic';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.deepEqual(Array.from(context.draftMembers), [16]);
  calls.length = 0;
  context.active = 'transposition';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.draftPair, '');
  calls.length = 0;
  context.active = 'fusion';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.draftPair, '');
  calls.length = 0;
  context.active = 'diastema';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.draftPair, '');
  calls.length = 0;
  context.active = 'abnormal_position';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.draftPosition.size, 0);
  calls.length = 0;
  context.active = 'rotation';
  callbacks.click(event);
  assert.deepEqual(calls, ['render', 'details']);
  assert.equal(context.draftRotation, 'unspecified');
  calls.length = 0;
  context.active = 'crown';
  callbacks.click(event);
  assert.deepEqual(calls, ['save']);
});

test('mobility saves only its supplied grade and scale and leaves other categories unchanged', () => {
  const source = asset('odontogram.js'), saved = [];
  const context = { canWrite: () => true, active: 'mobility', groupCategories: ["fixed_orthodontic","removable_orthodontic"], pairedCategories: ['diastema', 'fusion', 'transposition'], surfaceCategories: [], optionalSurfaceCategories: [],
    draftMobility: { grade: ' II ', scale: ' Miller ' }, activePreset: null, entries: [],
    save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(16, []);
  assert.equal(saved[0].odontogram_entry.mobility_grade, 'II');
  assert.equal(saved[0].odontogram_entry.mobility_scale, 'Miller');
  context.active = 'crown';
  context.add(16, []);
  assert.equal(saved[1].odontogram_entry.mobility_grade, undefined);
});


test('rotation saves the selected direction and does not add it to other categories', () => {
  const source = asset('odontogram.js'), saved = [];
  const context = { canWrite: () => true, active: 'rotation', groupCategories: ["fixed_orthodontic","removable_orthodontic"], pairedCategories: ['diastema', 'fusion', 'transposition'], surfaceCategories: [], optionalSurfaceCategories: [],
    draftRotation: 'counterclockwise', activePreset: null, entries: [], save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(16, []);
  assert.equal(saved[0].odontogram_entry.rotation_direction, 'counterclockwise');
  context.active = 'crown';
  context.add(16, []);
  assert.equal(saved[1].odontogram_entry.rotation_direction, undefined);
});


test('position saves all selected directions only for its own category', () => {
  const source = asset('odontogram.js'), saved = [];
  const context = { canWrite: () => true, active: 'abnormal_position', groupCategories: ["fixed_orthodontic","removable_orthodontic"], pairedCategories: ['diastema', 'fusion', 'transposition'], surfaceCategories: [], optionalSurfaceCategories: [],
    draftPosition: new Set(['M', 'V']), activePreset: null, entries: [], save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(16, []);
  assert.deepEqual(Array.from(saved[0].odontogram_entry.position_directions), ['M', 'V']);
  context.active = 'crown';
  context.add(16, []);
  assert.equal(saved[1].odontogram_entry.position_directions, undefined);
});


for (const category of ['diastema', 'fusion', 'transposition']) test(category + ' submits both teeth and rejects the reversed pair locally', () => {
  const source = asset('odontogram.js'), saved = [], errors = [];
  const context = { canWrite: () => true, active: category, draftPair: '21', groupCategories: ["fixed_orthodontic","removable_orthodontic"], pairedCategories: ['diastema', 'fusion', 'transposition'], surfaceCategories: [], optionalSurfaceCategories: [],
    activePreset: null, entries: [], save: payload => saved.push(payload), reportFormError: message => errors.push(message),
    label: () => '11–21', copy: { already_recorded: '%{marking}', appliance_overlap: 'Overlapping appliance' } };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function mobilityDetail(')), context);
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(11, []);
  assert.equal(saved[0].odontogram_entry.paired_tooth, 21);
  context.entries = [{ tooth: 11, paired_tooth: 21, category, surfaces: [] }];
  context.draftPair = '11'; context.add(21, []);
  assert.equal(saved.length, 1);
  assert.equal(errors.length, 1);
  context.active = 'crown'; context.add(11, []);
  assert.equal(saved[1].odontogram_entry.paired_tooth, undefined);
});

test('appliances submit only selected attachments and deduplicate reordered membership', () => {
  const source = asset('odontogram.js'), saved = [], errors = [];
  const context = { canWrite: () => true, active: 'fixed_orthodontic', groupCategories: ['fixed_orthodontic','removable_orthodontic'],
    toothArches: [[13,12,11,21,22,23]], draftMembers: new Set([23,13,21]), pairedCategories: [],
    surfaceCategories: [], optionalSurfaceCategories: [], activePreset: null, entries: [],
    save: payload => saved.push(payload), reportFormError: message => errors.push(message),
    label: () => '13, 21, 23', copy: { already_recorded: '%{marking}', appliance_overlap: 'Overlapping appliance' } };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function mobilityDetail(')), context);
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(23, []);
  assert.deepEqual(Array.from(saved[0].odontogram_entry.member_teeth), [13,21,23]);
  context.entries = [{ tooth: 13, member_teeth: [13,21,23], category: 'fixed_orthodontic', surfaces: [] }];
  context.add(13, []);
  assert.equal(saved.length, 1);
  assert.equal(errors.length, 1);
  context.draftMembers.add(12); context.add(13, []);
  assert.equal(saved.length, 1);
  assert.equal(errors.at(-1), 'Overlapping appliance');
  context.draftMembers = new Set([12,22]); context.add(12, []);
  assert.equal(saved.length, 2);
  context.active = 'crown'; context.add(13, []);
  assert.equal(saved[2].odontogram_entry.member_teeth, undefined);
  assert.deepEqual(Array.from(context.entryTeeth(context.entries[0])), [13,21,23]);
});

test('attachment choices disable unavailable teeth but preserve valid work and the selected anchor', () => {
  function element(tag, className, text) {
    return { tag, className, textContent: text, dataset: {}, children: [], attributes: {},
      append(...children) { this.children.push(...children); },
      setAttribute(key, value) { this.attributes[key] = value; }, addEventListener() {} };
  }
  const context = { node: element, active: 'fixed_orthodontic', selected: 35, draftMembers: new Set([35,36]),
    attachmentConflicts: ['missing','implant','retained_root'],
    entries: [{ tooth: 36, category: 'missing' }, { tooth: 37, category: 'implant' },
      { tooth: 38, category: 'retained_root' }, { tooth: 34, category: 'crown' }, { tooth: 32, member_teeth: [32,33], category: 'fixed_orthodontic' }],
    copy: { categories: { missing: 'Absent', implant: 'Implant', retained_root: 'Root' }, attachment_unavailable: 'Unavailable: %{reason}', attachment_in_use: 'Unavailable: appliance %{teeth}' },
    toothLabel: n => 'Tooth ' + n, clearFormError() {} };
  const source = asset('odontogram.js');
  runChartCode(source.slice(source.indexOf('    function attachmentReason('), source.indexOf('    function showDetails(')), context);
  for (const tooth of [33,36,37,38]) {
    const choice = context.attachmentChoice(tooth), check = choice.children[0], label = choice.children[1];
    assert.equal(check.disabled, true);
    assert.equal(check.checked, false);
    assert.equal(context.draftMembers.has(tooth), false);
    assert.equal(check.dataset.selectionUnavailable, '');
    assert.match(label.className, /text-muted/);
    assert.match(choice.title, /Unavailable:/);
    assert.match(check.attributes['aria-label'], /Tooth/);
  }
  const valid = context.attachmentChoice(34).children[0];
  assert.equal(valid.disabled, false);
  const anchor = context.attachmentChoice(35).children[0];
  assert.equal(anchor.checked, true);
  assert.equal(anchor.disabled, true);
  assert.equal(anchor.dataset.attachmentAnchor, '');
  context.entries = [];
  assert.equal(context.attachmentChoice(36).children[0].disabled, false);
});


test('removable extent covers the whole arch or a continuous span in either direction', () => {
  const source = asset('odontogram.js'), saved = [], row = [13,12,11,21,22,23];
  const context = { canWrite: () => true, active: 'removable_orthodontic', groupCategories: ['removable_orthodontic'],
    toothArches: [row], draftExtent: 'arch', pairedCategories: [], surfaceCategories: [], optionalSurfaceCategories: [],
    activePreset: null, entries: [], save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function mobilityDetail(')), context);
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(11, []);
  assert.deepEqual(Array.from(saved[0].odontogram_entry.member_teeth), row);
  context.draftExtent = '13'; context.add(11, []);
  assert.deepEqual(Array.from(saved[1].odontogram_entry.member_teeth), [13,12,11]);
  context.draftExtent = '23'; context.add(11, []);
  assert.deepEqual(Array.from(saved[2].odontogram_entry.member_teeth), [11,21,22,23]);
  assert.deepEqual(Array.from(context.extentTeeth(row, 11, '99')), []);
});

test('removable extent availability blocks its own overlap without treating absence as an attachment conflict', () => {
  const source = asset('odontogram.js');
  const context = { toothArches: [[16,15,14,13,12,11]], copy: { attachment_in_use: 'Occupied: %{teeth}' },
    entries: [{ tooth: 14, category: 'missing' }, { category: 'removable_orthodontic', member_teeth: [13,12] }] };
  runChartCode(source.slice(source.indexOf('  function extentTeeth('), source.indexOf('  function mobilityDetail(')), context);
  runChartCode(source.slice(source.indexOf('    function removableReason('), source.indexOf('    function attachmentReason(')), context);
  assert.equal(context.removableReason(15, 'arch'), 'Occupied: 13, 12');
  assert.equal(context.removableReason(15, '14'), '');
  assert.equal(context.removableReason(13, '16'), 'Occupied: 13, 12');
  context.entries.pop();
  assert.equal(context.removableReason(15, 'arch'), '');
});

test('recording an edentulous arch requires confirmation and stops when the server reports conflicts', () => {
  const source = asset('odontogram.js'), saved = [], prompts = [], errors = [];
  const context = { canWrite: () => true, active: 'edentulous_arch', groupCategories: [], pairedCategories: [],
    surfaceCategories: [], optionalSurfaceCategories: [], activePreset: null, entries: [],
    archForTooth: () => 'upper', archConflicts: { upper: [] },
    copy: { arches: { upper: 'Upper arch' }, confirm_arch: 'Record %{arch}?', arch_conflict: 'Correct markings first' },
    window: { confirm: text => { prompts.push(text); return false; } },
    reportFormError: error => errors.push(error), save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(13, []);
  assert.deepEqual(prompts, ['Record Upper arch?']);
  assert.equal(saved.length, 0);
  context.window.confirm = () => true;
  context.add(13, []);
  assert.equal(saved[0].odontogram_entry.arch, 'upper');
  assert.equal(saved[0].odontogram_entry.member_teeth, undefined);
  context.archConflicts.upper = [99];
  context.add(13, []);
  assert.equal(saved.length, 1);
  assert.deepEqual(errors, ['Correct markings first']);
});

test('complete denture entry requires separate absence and explicit replacement positions', () => {
  const source = asset('odontogram.js'), saved = [], errors = [];
  const context = { canWrite: () => true, active: 'complete_denture', groupCategories: [], pairedCategories: [],
    surfaceCategories: [], optionalSurfaceCategories: [], activePreset: null, entries: [],
    archForTooth: () => 'upper', toothArches: [[18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28]],
    draftReplacement: new Set([21,13]), copy: { denture_absence: 'Record absence first', denture_overlap: 'Already recorded', choose_replacement: 'Choose teeth' },
    reportFormError: error => errors.push(error), save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('    function replacementReason('), source.indexOf('    function showDetails(')), context);
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  context.add(13, []);
  assert.deepEqual(errors, ['Record absence first']);
  assert.equal(saved.length, 0);
  context.entries.push({ category: 'edentulous_arch', arch: 'upper', tooth: 18, surfaces: [] });
  context.draftReplacement.clear(); context.add(13, []);
  assert.equal(errors.at(-1), 'Choose teeth');
  context.draftReplacement = new Set([21,13]); context.add(13, []);
  assert.deepEqual(Array.from(saved[0].odontogram_entry.replacement_teeth), [13,21]);
  assert.equal(saved[0].odontogram_entry.arch, 'upper');
  assert.equal(saved[0].odontogram_entry.member_teeth, undefined);
  context.entries.push({ category: 'complete_denture', arch: 'upper', tooth: 18, surfaces: [] });
  context.add(13, []);
  assert.equal(saved.length, 1);
  assert.equal(errors.at(-1), 'Already recorded');
});

test('partial denture picker and submission reject unavailable or occupied replacement positions', () => {
  const source = asset('odontogram.js'), saved = [], errors = [];
  const context = { canWrite: () => true, active: 'partial_denture', groupCategories: [], pairedCategories: [],
    surfaceCategories: [], optionalSurfaceCategories: [], activePreset: null,
    entries: [{ category: 'missing', tooth: 16 }, { category: 'missing', tooth: 15 }, { category: 'missing', tooth: 24 }],
    archForTooth: () => 'upper', toothArches: [[18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28]],
    draftReplacement: new Set([16,13]), copy: { partial_absence: 'Record absence first', denture_overlap: 'Occupied', choose_replacement: 'Choose teeth' },
    reportFormError: error => errors.push(error), save: payload => saved.push(payload) };
  runChartCode(source.slice(source.indexOf('  function entryTeeth('), source.indexOf('  function extentTeeth(')), context);
  runChartCode(source.slice(source.indexOf('    function replacementReason('), source.indexOf('    function showDetails(')), context);
  runChartCode(source.slice(source.indexOf('    function add('), source.indexOf('    async function save(')), context);
  assert.equal(context.replacementReason(16), '');
  assert.equal(context.replacementReason(13), 'Record absence first');
  context.add(13, []);
  assert.equal(saved.length, 0);
  context.draftReplacement = new Set([24,15,16]); context.add(13, []);
  assert.deepEqual(Array.from(saved[0].odontogram_entry.replacement_teeth), [16,15,24]);
  context.entries.push({ category: 'partial_denture', arch: 'upper', tooth: 16, member_teeth: [16,15,24], surfaces: [] });
  assert.equal(context.replacementReason(15), 'Occupied');
  context.add(13, []);
  assert.equal(saved.length, 1);
  assert.equal(errors.at(-1), 'Occupied');
  context.active = 'complete_denture';
  assert.equal(context.dentureReason(13), 'Occupied');
});

test('custom marking names avoid repeating the category while preserving distinct custom names', () => {
  const source = asset('odontogram.js');
  const context = { copy: { categories: { crown: 'Corona' } } };
  runChartCode(source.slice(source.indexOf('    const markingName ='), source.indexOf('    const activeName =')) + '\nthis.nameFor = markingName;', context);
  assert.equal(context.nameFor({ category: 'crown' }), 'Corona');
  assert.equal(context.nameFor({ category: 'crown', treatment_snapshot: { name: 'Corona' } }), 'Corona');
  assert.equal(context.nameFor({ category: 'crown', treatment_snapshot: { name: ' corona ' } }), 'corona');
  assert.equal(context.nameFor({ category: 'crown', treatment_snapshot: { name: 'Zirconia' } }), 'Zirconia (Corona)');
});
