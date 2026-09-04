const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../app/assets/javascripts/ai.js'), 'utf8');

function setup(clipboard) {
  const listeners = {};
  const status = { textContent: '' };
  const input = { value: 'https://example.test/api/agent/mcp', focused: false, selected: false,
    focus() { this.focused = true; }, select() { this.selected = true; } };
  const container = { querySelector: selector => selector === 'input' ? input : status };
  const button = { dataset: { copied: 'URL copied.', copyFailed: 'Copy the selected URL.' }, closest: () => container };
  vm.runInNewContext(source, {
    document: { addEventListener: (name, listener) => { listeners[name] = listener; } },
    navigator: { clipboard },
    window: { confirm: () => true }
  });
  return { click: listeners.click, input, status, event: { target: { closest: () => button } } };
}

function setupAccess({ enabled, consentChecked, confirmResult = true }) {
  const listeners = {};
  let submissions = 0;
  let consentFocused = false;
  const form = {
    requestSubmit() { submissions += 1; },
    querySelector(selector) {
      if (selector === '[data-ai-access-toggle]') return toggle;
      if (selector === '[data-ai-consent]') return consent;
      return null;
    }
  };
  const toggle = {
    checked: enabled,
    dataset: { disableConfirm: 'Disconnect everyone?' },
    closest(selector) { return selector === '[data-ai-access-control]' ? this : form; }
  };
  const consent = consentChecked === undefined ? null : {
    checked: consentChecked,
    focus() { consentFocused = true; },
    closest(selector) { return selector === '[data-ai-access-control]' ? this : form; }
  };

  vm.runInNewContext(source, {
    document: { addEventListener: (name, listener) => { listeners[name] = listener; } },
    navigator: { clipboard: undefined },
    window: { confirm: () => confirmResult }
  });

  return {
    toggle,
    consent,
    change(control) { listeners.change({ target: control }); },
    get submissions() { return submissions; },
    get consentFocused() { return consentFocused; }
  };
}

test('copies the complete connection URL and announces success', async () => {
  let copied;
  const ui = setup({ writeText: async text => { copied = text; } });
  await ui.click(ui.event);
  assert.equal(copied, ui.input.value);
  assert.equal(ui.status.textContent, 'URL copied.');
  assert.equal(ui.input.selected, false);
});

for (const clipboard of [undefined, { writeText: async () => { throw new Error('Permission denied'); } }]) {
  test(`selects the URL and explains manual copying when clipboard is ${clipboard ? 'denied' : 'unavailable'}`, async () => {
    const ui = setup(clipboard);
    await ui.click(ui.event);
    assert.equal(ui.input.focused, true);
    assert.equal(ui.input.selected, true);
    assert.equal(ui.status.textContent, 'Copy the selected URL.');
  });
}

test('ignores clicks outside the AI copy button', async () => {
  const ui = setup({ writeText: async () => assert.fail('Unexpected clipboard write') });
  await ui.click({ target: { closest: () => null } });
  assert.equal(ui.status.textContent, '');
});

test('saves immediately when practice access changes', () => {
  const ui = setupAccess({ enabled: true });
  ui.change(ui.toggle);
  assert.equal(ui.submissions, 1);
});

test('keeps practice access on when disconnect confirmation is cancelled', () => {
  const ui = setupAccess({ enabled: false, confirmResult: false });
  ui.change(ui.toggle);
  assert.equal(ui.toggle.checked, true);
  assert.equal(ui.submissions, 0);
});

test('waits for required consent before enabling practice access', () => {
  const ui = setupAccess({ enabled: true, consentChecked: false });
  ui.change(ui.toggle);
  assert.equal(ui.submissions, 0);
  assert.equal(ui.consentFocused, true);

  ui.consent.checked = true;
  ui.change(ui.consent);
  assert.equal(ui.submissions, 1);
});
