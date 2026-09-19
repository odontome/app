const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const view = fs.readFileSync(path.join(root, 'app/views/datebooks/show.html.erb'), 'utf8');
const bundle = fs.readFileSync(path.join(root,
  'node_modules/@tabler/core/dist/libs/fullcalendar/index.global.js'), 'utf8');

// Expose the installed library's actual hit detection, without copying its math
// into this test or changing the library shipped to the browser.
const context = vm.createContext({ console, HTMLElement: class {}, window: { scrollX: 0, scrollY: 0 } });
vm.runInContext(bundle.replace('exports.Calendar = Calendar;',
  'exports.dragTest = { HitDragging, TimeCols, processSlotOptions }; exports.Calendar = Calendar;'), context);
const { HitDragging, TimeCols, processSlotOptions } = context.FullCalendar.dragTest;
const { createDuration, DateEnv, Emitter } = context.FullCalendar.Internal;
const option = name => createDuration(view.match(new RegExp(`${name}: '([^']+)'`))[1]);
const slotDuration = option('slotDuration');
const snapDuration = option('snapDuration');
const slotMinutes = slotDuration.milliseconds / 60000;
const date = new Date('2026-09-19T00:00:00Z');
const dateEnv = new DateEnv({ timeZone: 'UTC', calendarSystem: 'gregory', locale: { week: { dow: 1, doy: 4 }, options: {} } });

function dragAt(startMinute, duration, grabFraction) {
  // Same 70px/hour density as the calendar, with one column and 08:00–20:00 slots.
  const pixelsPerMinute = 70 / 60;
  const slotHeight = slotMinutes * pixelsPerMinute;
  const columns = {
    context: { dateEnv, options: { snapDuration } },
    props: { slotDuration, cells: [{ date }], dateProfile: { slotMinTime: createDuration('08:00:00') } },
    colCoords: { leftToIndex: () => 0, lefts: [0], rights: [300], els: [{}] },
    state: { slatCoords: { positions: {
      topToIndex: top => Math.floor(top / slotHeight),
      tops: Array.from({ length: 720 / slotMinutes }, (_, i) => i * slotHeight),
      getHeight: () => slotHeight
    } } },
    processSlotOptions
  };
  const hitDragging = new HitDragging({ emitter: new Emitter() }, {});
  hitDragging.useSubjectCenter = true;
  hitDragging.queryHitForOffset = (x, y) => TimeCols.prototype.queryHit.call(columns, x, y);
  const top = (startMinute - 480) * pixelsPerMinute;
  const bottom = top + duration * pixelsPerMinute - 2; // event border/inset
  const subjectEl = new context.HTMLElement();
  subjectEl.getBoundingClientRect = () => ({ left: 0, right: 300, top, bottom });
  const pointer = { subjectEl, pageX: 150, pageY: top + (bottom - top) * grabFraction };
  hitDragging.processFirstCoord(pointer);
  return movement => {
    hitDragging.handleMove({ ...pointer, pageY: pointer.pageY + movement * pixelsPerMinute }, true);
    return (hitDragging.movingHit.dateSpan.range.start - hitDragging.initialHit.dateSpan.range.start) / 60000;
  };
}

for (const startMinute of [600, 615, 630, 645]) {
  for (const duration of [15, 30, 45, 60]) {
    for (const grabFraction of [0.1, 0.4, 0.6, 0.9]) {
      test(`holding ${startMinute} for ${duration}min at ${grabFraction} does not move it`, () => {
        const move = dragAt(startMinute, duration, grabFraction);
        assert.equal(move(0), 0, 'a stationary long press must not change the time');
        assert.equal(move(15), 15, 'dragging down one increment moves exactly 15 minutes');
        assert.equal(move(-15), -15, 'dragging up one increment moves exactly 15 minutes');
        assert.equal(move(0), 0, 'returning to the grab point restores the original time');
      });
    }
  }
}
