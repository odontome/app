const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../app/assets/javascripts/jquery-autosuggest.js'), 'utf8');

// A minimal jQuery stand-in: it records every markup string it is asked to
// parse, so a test can tell whether a patient name ever reached the HTML parser.
function setup() {
  const parsedMarkup = [];
  const instance = {};
  const element = markup => {
    const el = { markup, attributes: {}, text: null, children: [] };
    el.attr = (name, value) => {
      Object.assign(el.attributes, typeof name === 'object' ? name : { [name]: value });
      return el;
    };
    el.text = value => { el.text = value; return el; };
    el.append = child => { el.children.push(child); return el; };
    el.appendTo = parent => { parent.children.push(el); return el; };
    return el;
  };
  const $ = arg => {
    if (typeof arg === 'function') return arg();
    if (typeof arg === 'string' && arg.trim().startsWith('<')) {
      parsedMarkup.push(arg);
      return element(arg);
    }
    return { autocomplete: () => ({ autocomplete: () => instance }) };
  };
  vm.runInNewContext(source, { $ });
  return { renderItem: instance._renderItem, parsedMarkup, element };
}

test('renders a patient name as text, never as HTML', () => {
  const ui = setup();
  const name = '<img src=x onerror=alert(1)>';
  const ul = ui.element('<ul>');

  const li = ui.renderItem(ul, { id: 1, fullname: name });

  assert.ok(ui.parsedMarkup.every(markup => !markup.includes(name)), 'name must not be parsed as markup');
  const link = li.children[0];
  assert.equal(link.text, name);
  assert.equal(link.markup, '<a>');
  assert.deepEqual(link.attributes, { href: '', class: 'dropdown-item', 'data-theme': 'none' });
  assert.equal(li.markup, "<li data-theme='none'>");
  assert.equal(ul.children[0], li);
});
