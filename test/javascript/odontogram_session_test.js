const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../app/assets/javascripts/odontogram.js'), 'utf8');

function harness() {
  const data = new Map();
  const context = { window: { sessionStorage: {
    getItem: key => data.get(key) || null,
    setItem: (key, value) => data.set(key, value),
    removeItem: key => data.delete(key)
  } } };
  vm.runInNewContext(source.slice(source.indexOf('  function forgetEditorSession('), source.indexOf('  function start(')), context);
  const root = { dataset: { odontogramSession: '1:2:4', odontogramSessionEnabled: 'true' } };
  return { context, data, root };
}

test('history and saved charts preserve an opaque editor identity without storing markings', () => {
  const { context, data, root } = harness();
  const editor = '00000000-0000-4000-8000-000000000001';
  context.rememberEditorSession(root, editor);
  assert.equal(context.prepareEditorSession(root, 'navigate').editor, editor);
  const snapshot = { dataset: { ...root.dataset, snapshotId: '123' } };
  context.rememberEditorSession(snapshot, '00000000-0000-4000-8000-000000000002');
  assert.equal(context.editorSession(root).editor, editor);
  assert.deepEqual(Object.keys(JSON.parse([...data.values()][0])).sort(), ['context', 'editor']);
});

test('reload leaving the patient changing author and disabled access end the session', () => {
  for (const [next, navigation] of [
    [null, 'navigate'], [{ odontogramSession: '1:2:5', odontogramSessionEnabled: 'true' }, 'navigate'],
    [{ odontogramSession: '2:2:4', odontogramSessionEnabled: 'true' }, 'navigate'],
    [{ odontogramSession: '1:2:4', odontogramSessionEnabled: 'false' }, 'navigate'],
    [{ odontogramSession: '1:2:4', odontogramSessionEnabled: 'true' }, 'reload']
  ]) {
    const { context, data, root } = harness();
    context.rememberEditorSession(root, '00000000-0000-4000-8000-000000000001');
    assert.equal(context.prepareEditorSession(next && { dataset: next }, navigation), null);
    assert.equal(data.size, 0);
  }
});

test('unavailable browser storage safely leaves editing as an in-memory session', () => {
  const { context, root } = harness();
  Object.defineProperty(context.window, 'sessionStorage', { get() { throw new Error('Blocked'); } });
  assert.equal(context.editorSession(root), null);
  assert.doesNotThrow(() => context.rememberEditorSession(root, '00000000-0000-4000-8000-000000000001'));
  assert.doesNotThrow(() => context.forgetEditorSession());
});
