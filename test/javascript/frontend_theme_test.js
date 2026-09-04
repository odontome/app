const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

for (const mode of ['light', 'dark']) {
  test(`official theme preserves saved ${mode} mode with the neutral palette`, () => {
    const attributes = new Map();
    const storage = new Map([['tabler-theme', mode]]);
    const context = vm.createContext({
      URLSearchParams,
      window: { location: { search: '' } },
      localStorage: {
        getItem: (key) => storage.get(key) || null,
        setItem: (key, value) => storage.set(key, value)
      },
      document: { documentElement: {
        setAttribute: (key, value) => attributes.set(key, value),
        removeAttribute: (key) => attributes.delete(key)
      } }
    });

    vm.runInContext(read('node_modules/@tabler/core/dist/js/tabler-theme.min.js'), context);
    vm.runInContext(read('app/assets/javascripts/theme.js'), context);

    assert.equal(attributes.get('data-bs-theme'), mode === 'dark' ? 'dark' : undefined);
    assert.equal(attributes.get('data-bs-theme-base'), 'neutral');
    assert.equal(storage.get('tabler-theme'), mode);
  });
}

test('help controls initialize after DOM ready using idempotent Tabler APIs', () => {
  const popover = {};
  const tooltip = {};
  const calls = [];
  let ready;
  const context = vm.createContext({
    window: {},
    setInterval() {},
    $: (argument) => {
      if (typeof argument === 'function') ready = argument;
      return { wrap() {} };
    },
    document: { querySelectorAll: (selector) => {
      if (selector === '[data-bs-toggle="popover"]') return [popover];
      if (selector === '[data-bs-toggle="tooltip"]') return [tooltip];
      return [];
    } },
    tabler: {
      Popover: { getOrCreateInstance: (element) => calls.push(element) },
      Tooltip: { getOrCreateInstance: (element) => calls.push(element) }
    }
  });

  vm.runInContext(read('app/assets/javascripts/application.js'), context);
  assert.deepEqual(calls, []);
  ready();
  assert.deepEqual(calls, [popover, tooltip]);
});
