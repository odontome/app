// Exercise the server-rendered calendar configuration with the installed library.
const fs = require('node:fs');
const vm = require('node:vm');

const fullCalendar = vm.createContext({ console });
vm.runInContext(fs.readFileSync(
  'node_modules/@tabler/core/dist/libs/fullcalendar/index.global.min.js', 'utf8'
), fullCalendar);

const html = fs.readFileSync(0, 'utf8');
const script = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)]
  .map(match => match[1]).find(source => source.includes('new FullCalendar.Calendar'));
let options;
let modalTitle;
const element = { addEventListener() {} };
const jquery = () => ({
  on() {}, html() {}, prop() {}, val() { return '1'; },
  text(value) { modalTitle = value; }
});
jquery.get = (...args) => args.at(-1)('');

vm.runInNewContext(script, {
  Intl, Date, console,
  document: {
    addEventListener(name, callback) { if (name === 'DOMContentLoaded') callback(); },
    getElementById() { return element; }
  },
  window: { matchMedia() { return { matches: process.argv[2] === 'compact' }; } },
  FullCalendar: { Calendar: class {
    constructor(target, config) { options = config; }
    render() {}
  } },
  tabler: { Modal: { getOrCreateInstance() { return { show() {} }; } } },
  $: jquery,
  setTimeout() {}, clearTimeout() {}
});

const results = ['00:00', '09:15', '12:00', '13:30', '23:45'].map(time => {
  const date = new Date(`2026-09-05T${time}:00Z`);
  const format = config => fullCalendar.FullCalendar.formatDate(date.toISOString(), {
    locale: options.locale, timeZone: options.timeZone,
    hour: 'numeric', minute: '2-digit', ...config
  });
  options.dateClick({ date, view: { type: 'timeGridDay' } });
  const newTitle = modalTitle;
  options.eventClick({ event: { id: 1, start: date, extendedProps: { patient_id: 1 } } });
  return {
    time, slot: format(options.slotLabelFormat), event: format(options.eventTimeFormat),
    newTitle, editTitle: modalTitle
  };
});
process.stdout.write(JSON.stringify({ locale: options.locale, view: options.initialView, results }));
