const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const context = { window: {} };
for (const file of ['odontogram-artwork.js', 'odontogram-markings.js']) {
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../app/assets/javascripts', file), 'utf8'), context);
}
const markings = context.window.OdontogramMarkings;
const artwork = context.window.OdontogramArtwork;

test('bridges draw one span with ticks only on supports and replacement crowns without inventing natural roots', () => {
  const bridge = { category: 'fixed_bridge', surfaces: [], member_teeth: [16,15,14], bridge_units: [
    { tooth: 16, role: 'natural_support' }, { tooth: 15, role: 'pontic' }, { tooth: 14, role: 'implant_support', implant_entry_id: 7 }
  ] };
  const first = markings.forEntries(artwork[16], [bridge], 16);
  assert.deepEqual(JSON.parse(JSON.stringify(first.bridge)), { start: true, end: false, support: true, pontic: false });
  assert.equal(first.replacement, false, 'Generic natural supports do not imply a full crown retainer');
  const middle = markings.forEntries(artwork[15], [bridge, { category: 'missing', surfaces: [] }], 15);
  assert.equal(middle.bridge.support, false);
  assert.equal(middle.bridge.pontic, true);
  assert.equal(middle.replacement, true);
  const last = markings.forEntries(artwork[14], [bridge, { id: 7, category: 'implant', surfaces: [] }], 14);
  assert.equal(last.bridge.end, true);
  assert.equal(last.bridge.support, true);
  assert.equal(last.implant, true);
  assert.equal(last.replacement, true);
  assert.equal(markings.forEntries(artwork[13], [bridge], 13).bridge, null);
  const reversedArch = { ...bridge, member_teeth: [85,84], bridge_units: [{ tooth: 85, role: 'natural_support' }, { tooth: 84, role: 'pontic' }] };
  assert.equal(markings.forEntries(artwork[84], [reversedArch], 84).bridge.pontic, true);
});

test('partial denture lines join adjacent replacements and stop at unselected gaps', () => {
  const row = [18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28];
  const denture = { category: 'partial_denture', surfaces: [], replacement_teeth: [16,15,24] };
  const expected = { 16: [true,false], 15: [false,true], 24: [true,true] };
  row.forEach(tooth => {
    const result = markings.forEntries(artwork[tooth], [denture], tooth, row);
    assert.equal(result.replacement, !!expected[tooth]);
    assert.equal(result.dentureSpan, !!expected[tooth]);
    assert.equal(result.missing, false, 'The prosthesis itself must not invent absence');
    if (expected[tooth]) assert.deepEqual([result.dentureStart,result.dentureEnd], expected[tooth]);
  });
  const lower = { ...denture, replacement_teeth: [85,84,72] };
  const lowerRow = [85,84,83,82,81,71,72,73,74,75];
  assert.equal(markings.forEntries(artwork[85], [lower], 85, lowerRow).dentureEnd, false);
  assert.equal(markings.forEntries(artwork[84], [lower], 84, lowerRow).dentureEnd, true);
  assert.equal(markings.forEntries(artwork[83], [lower], 83, lowerRow).dentureSpan, false);
});

test('complete dentures draw replacement crowns only at their recorded positions and preserve underlying status', () => {
  const absence = { category: 'edentulous_arch', surfaces: [] };
  const denture = { category: 'complete_denture', surfaces: [], replacement_teeth: [17,16,15,14,13,12,11,21,22,23,24,25,26,27] };
  [18,17,13,21,28,55,51].forEach(tooth => {
    const result = markings.forEntries(artwork[tooth], [absence, denture], tooth);
    assert.equal(result.replacement, denture.replacement_teeth.includes(tooth));
    assert.equal(result.dentureSpan, tooth < 50);
    assert.equal(result.edentulous, true);
    assert.equal(result.missing, true);
    assert.equal(result.implant, false);
    const removed = markings.forEntries(artwork[tooth], [absence], tooth);
    assert.equal(removed.replacement, false);
    assert.equal(removed.missing, true);
  });
  const implant = { id: 7, category: 'implant', surfaces: [] };
  const result = markings.forEntries(artwork[13], [absence, denture, implant], 13);
  assert.equal(result.implant, true);
  assert.equal(result.implantCrown, false);
  assert.equal(result.replacement, true);
  assert.equal(result.overlays.length, 8);
  const primary = { ...denture, replacement_teeth: [85,84,83,82,81,71,72,73,74,75] };
  assert.equal(markings.forEntries(artwork[85], [absence, primary], 85).replacement, true);
  assert.equal(markings.forEntries(artwork[48], [absence, primary], 48).dentureSpan, false);
});

test('implants replace natural anatomy and only show a crown linked to that implant', () => {
  Object.values(artwork).forEach(a => {
    const implant = { id: 10, category: 'implant', surfaces: [] };
    const missing = { id: 9, category: 'missing', surfaces: [] };
    const bare = markings.forEntries(a, [missing, implant]);
    assert.equal(bare.implant, true);
    assert.equal(bare.missing, false);
    assert.equal(bare.implantCrown, false);
    assert.equal(bare.overlays.length, 8);
    const start = a.lower ? a.crownBounds[1] + a.crownBounds[3] : a.crownBounds[1];
    assert.ok(bare.overlays[0].attributes.d.startsWith('M 32 ' + start + ' '));
    assert.ok(start + (a.lower ? 80 : -80) > 0);
    assert.ok(start + (a.lower ? 80 : -80) < 260);
    ['crown', 'temporary_crown'].forEach(category => {
      const restored = markings.forEntries(a, [missing, implant, { category, implant_entry_id: 10, surfaces: [] }]);
      assert.equal(restored.implantCrown, true);
      assert.equal(restored.missing, false);
      assert.equal(restored.temporary, category === 'temporary_crown');
      assert.equal(restored.overlays.length, bare.overlays.length);
    });
    assert.equal(markings.forEntries(a, [implant, { category: 'crown', implant_entry_id: 11, surfaces: [] }]).implantCrown, false);
    assert.equal(markings.forEntries(a, [missing]).missing, true);
    assert.equal(markings.forEntries(a, []).implant, false);
  });
});

test('temporary work remains blue, labeled, and limited to its recorded targets', () => {
  const result = markings.forEntries(artwork[16], [
    { category: 'temporary_crown', surfaces: [] },
    { category: 'temporary_filling', surfaces: ['M', 'O'] }
  ]);
  assert.equal(result.crownWork, true);
  assert.deepEqual(Array.from(result.surfaceOutlines), ['M', 'O']);
  assert.equal(result.temporary, true);
  assert.equal(result.overlays.length, 0);
  assert.equal(markings.forEntries(artwork[16], []).temporary, false);
});

test('pulpotomy stays inside the crown chamber without adding canal paths on all 52 teeth', () => {
  Object.values(artwork).forEach(a => {
    const result = markings.forEntries(a, [{ category: 'pulpotomy', surfaces: [] }]);
    assert.equal(result.temporary, false);
    assert.equal(result.overlays.length, 1);
    const shape = result.overlays[0];
    assert.equal(shape.tag, 'rect');
    const [x, y, width, height] = a.crownBounds;
    assert.ok(shape.attributes.x >= x && shape.attributes.y >= y);
    assert.ok(shape.attributes.x + shape.attributes.width <= x + width);
    assert.ok(shape.attributes.y + shape.attributes.height <= y + height);
    assert.equal(shape.attributes.fill, 'var(--od-blue)');
    assert.equal(result.crownWork, false);
    assert.equal(result.surfaceOutlines.length, 0);
  });
});

test('wear records a red line at each selected anatomical site without filling the tooth', () => {
  Object.values(artwork).forEach(a => {
    a.surfaceNames.forEach(surface => {
      const result = markings.forEntries(a, [{ category: 'wear', surfaces: [surface] }]);
      const point = markings.surfaceCenter(a, surface);
      assert.equal(result.temporary, false);
      assert.equal(result.overlays.length, 1);
      const shape = result.overlays[0];
      assert.equal(shape.tag, 'line');
      assert.equal(shape.attributes.stroke, 'var(--od-red)');
      assert.equal(shape.attributes.y1, point[1]);
      assert.equal(shape.attributes.y2, point[1]);
      assert.ok(shape.attributes.x1 < point[0] && shape.attributes.x2 > point[0]);
      assert.equal(result.crownWork, false);
    });
  });
});

test('coexisting temporary work pulpotomy and wear all retain their separate indicators', () => {
  const result = markings.forEntries(artwork[46], [
    { category: 'temporary_filling', surfaces: ['O'] },
    { category: 'pulpotomy', surfaces: [] },
    { category: 'wear', surfaces: ['O'] },
    { category: 'caries', surfaces: ['O'] }
  ]);
  assert.equal(result.temporary, true);
  assert.deepEqual(Array.from(result.surfaceOutlines), ['O']);
  assert.deepEqual(Array.from(result.overlays, shape => shape.tag), ['rect', 'line']);
});

test('unspecified core and enamel findings use notation without inventing clinical geometry', () => {
  Object.values(artwork).forEach(a => {
    const result = markings.forEntries(a, [
      { category: 'core', surfaces: [] },
      { category: 'enamel_defect', surfaces: [] },
      { category: 'deep_fissures', surfaces: [] }
    ]);
    assert.equal(result.overlays.length, 0);
    assert.equal(result.crownWork, false);
    assert.equal(result.surfaceOutlines.length, 0);
    assert.deepEqual(Array.from(result.annotations), ['core', 'enamel_defect', 'deep_fissures']);
  });
});

test('finding notation is shown once per category without painting decay or altering recorded sites', () => {
  const entries = [
    { category: 'enamel_defect', surfaces: ['M'] },
    { category: 'enamel_defect', surfaces: ['O'] },
    { category: 'deep_fissures', surfaces: ['O'] }
  ];
  const before = JSON.stringify(entries);
  const result = markings.forEntries(artwork[16], entries);
  assert.deepEqual(Array.from(result.annotations), ['enamel_defect', 'deep_fissures']);
  assert.equal(result.overlays.length, 0);
  assert.equal(result.surfaceOutlines.length, 0);
  assert.equal(JSON.stringify(entries), before);
});

test('veneers have their own crown layer without painting a surface ring', () => {
  Object.values(artwork).forEach(a => {
    const facial = a.surfaceNames[0];
    const result = markings.forEntries(a, [
      { category: 'veneer', surfaces: [facial, 'M'] },
      { category: 'filling', surfaces: ['M'] },
      { category: 'rct', surfaces: [] }
    ]);
    assert.equal(result.veneer, true);
    assert.equal(result.crownWork, false);
    assert.equal(result.surfaceOutlines.length, 0);
    assert.equal(result.overlays.length, 0);
    assert.equal(markings.forEntries(a, [{ category: 'filling', surfaces: [facial] }]).veneer, false);
  });
});

test('a tooth-level veneer draws its facial layer without fabricating recorded surface coverage', () => {
  Object.values(artwork).forEach(a => {
    const result = markings.forEntries(a, [{ category: 'veneer', surfaces: [] }]);
    assert.equal(result.veneer, true);
    assert.equal(result.surfaceOutlines.length, 0);
    assert.equal(result.crownWork, false);
    assert.equal(result.overlays.length, 0);
  });
});

test('sealants and unspecified crown fractures use notation instead of fabricated paths', () => {
  Object.values(artwork).forEach(a => {
    const result = markings.forEntries(a, [
      { category: 'sealant', surfaces: ['M'] },
      { category: 'fracture', surfaces: [] }
    ]);
    assert.deepEqual(Array.from(result.annotations), ['sealant', 'fracture']);
    assert.equal(result.overlays.length, 0);
    assert.equal(result.surfaceOutlines.length, 0);
    assert.equal(result.crownWork, false);
  });
});

test('inlays keep their own notation without implying a material or full crown', () => {
  Object.values(artwork).forEach(a => {
    const entries = [{ category: 'inlay', surfaces: ['M', 'D'] }];
    const before = JSON.stringify(entries);
    const result = markings.forEntries(a, entries);
    assert.deepEqual(Array.from(result.annotations), ['inlay']);
    assert.equal(result.crownWork, false);
    assert.equal(result.surfaceOutlines.length, 0);
    assert.equal(result.overlays.length, 0);
    assert.equal(JSON.stringify(entries), before);
  });
});

test('root canal and post records without root details produce distinct notation and no invented root geometry', () => {
  Object.values(artwork).forEach(a => {
    const result = markings.forEntries(a, [
      { category: 'rct', surfaces: [] }, { category: 'post', surfaces: [] },
      { category: 'crown', surfaces: [] }
    ]);
    assert.deepEqual(Array.from(result.annotations), ['rct', 'post']);
    assert.equal(result.overlays.length, 0);
    assert.equal(result.surfaceOutlines.length, 0);
    assert.equal(result.veneer, false);
  });
});


test('tooth size observations add compact notation without changing anatomy or hiding coexisting work', () => {
  Object.values(artwork).forEach(a => {
    ['macrodontia', 'microdontia'].forEach(category => {
      const entries = [{ category, surfaces: [] }];
      const result = markings.forEntries(a, entries);
      assert.deepEqual(Array.from(result.annotations), [category]);
      assert.equal(result.overlays.length, 0);
      assert.equal(result.missing, false);
      assert.equal(result.implant, false);
      const combined = markings.forEntries(a, [...entries, { category: 'inlay', surfaces: ['M'] }]);
      assert.ok(combined.annotations.includes(category));
      assert.ok(combined.annotations.includes('inlay'));
    });
  });
});


test('peg shape uses one blue triangle beyond the roots without changing the crown or surfaces', () => {
  Object.values(artwork).forEach(a => {
    const entry = { category: 'peg_shaped', surfaces: [] };
    const result = markings.forEntries(a, [entry]);
    assert.deepEqual(Array.from(result.annotations), []);
    assert.equal(result.overlays.length, 1);
    const triangle = result.overlays[0];
    assert.equal(triangle.tag, 'polygon');
    assert.equal(triangle.attributes.stroke, 'var(--od-blue)');
    assert.equal(triangle.attributes.fill, 'none');
    const points = triangle.attributes.points.split(' ').map(point => point.split(',').map(Number));
    assert.equal(points.length, 3);
    points.forEach(([x,y]) => { assert.ok(x > 0 && x < 80); assert.ok(y > 0 && y < 260); });
    const rootY = [...a.svg.matchAll(/<path[^>]*data-part="root[^"]*"[^>]*d="([^"]+)"/g)]
      .flatMap(match => match[1].match(/-?\d+(?:\.\d+)?/g).map(Number).filter((_, i) => i % 2 === 1));
    assert.ok(a.lower ? Math.min(...points.map(p => p[1])) > Math.max(...rootY) : Math.max(...points.map(p => p[1])) < Math.min(...rootY));
    assert.equal(result.surfaceOutlines.length, 0);
    assert.equal(result.veneer, false);
    assert.equal(result.missing, false);
    const combined = markings.forEntries(a, [entry, { category: 'microdontia', surfaces: [] }, { category: 'temporary_crown', surfaces: [] }]);
    assert.equal(combined.crownWork, true);
    assert.equal(combined.temporary, true);
    assert.ok(combined.annotations.includes('microdontia'));
    assert.ok(!combined.annotations.includes('peg_shaped'));
    assert.equal(combined.overlays.length, 1);
  });
});

test('mobility annotates its recorded target without painting sites or inventing displacement', () => {
  Object.values(artwork).forEach(a => {
    const observation = { category: 'mobility', surfaces: [] };
    const natural = markings.forEntries(a, [observation]);
    assert.deepEqual(Array.from(natural.annotations), ['mobility']);
    assert.equal(natural.overlays.length, 0);
    assert.equal(natural.surfaceOutlines.length, 0);
    const implant = markings.forEntries(a, [{ id: 1, category: 'implant', surfaces: [] }, { ...observation, implant_entry_id: 1 }]);
    assert.equal(implant.implant, true);
    assert.equal(implant.implantCrown, false);
    assert.deepEqual(Array.from(implant.annotations), ['mobility']);
  });
});


test('extrusion and intrusion use opposite arch-aware arrows outside every crown without extra labels', () => {
  Object.values(artwork).forEach(a => {
    ['extrusion', 'intrusion'].forEach(category => {
      const result = markings.forEntries(a, [{ category, surfaces: [] }]);
      assert.equal(result.overlays.length, 1);
      assert.equal(result.annotations.length, 0);
      assert.equal(result.surfaceOutlines.length, 0);
      const arrow = result.overlays[0];
      assert.equal(arrow.tag, 'path');
      assert.equal(arrow.attributes.stroke, 'var(--od-blue)');
      assert.equal(arrow.attributes.fill, 'none');
      const coords = arrow.attributes.d.match(/-?\d+(?:\.\d+)?/g).map(Number);
      const [x, startY, tipX, tipY] = coords;
      assert.equal(x, tipX);
      const pointsDown = category === 'extrusion' ? !a.lower : a.lower;
      assert.equal(tipY > startY, pointsDown);
      for (let i = 0; i < coords.length; i += 2) {
        assert.ok(coords[i] > a.crownBounds[0] + a.crownBounds[2]);
        assert.ok(coords[i] < 80);
        assert.ok(coords[i+1] > 0 && coords[i+1] < 260);
      }
      const combined = markings.forEntries(a, [{ category, surfaces: [] }, { category: 'peg_shaped', surfaces: [] }, { category: 'temporary_crown', surfaces: [] }]);
      assert.equal(combined.overlays.length, 2);
      assert.equal(combined.crownWork, true);
      assert.equal(combined.temporary, true);
    });
  });
});

test('rotation arrows keep their recorded screen direction across arches and never move recorded sites', () => {
  Object.values(artwork).forEach(a => {
    const cy = a.lower ? 37 : 223;
    for (const direction of ['clockwise', 'counterclockwise', 'unspecified']) {
      const rotation = { category: 'rotation', rotation_direction: direction, surfaces: [] };
      const result = markings.forEntries(a, [rotation]);
      assert.equal(result.surfaceOutlines.length, 0);
      assert.equal(result.veneer, false);
      if (direction === 'unspecified') {
        assert.equal(result.overlays.length, 0);
        assert.deepEqual(Array.from(result.annotations), ['rotation']);
      } else {
        assert.equal(result.overlays.length, 1);
        assert.equal(result.annotations.length, 0);
        const arrow = result.overlays[0];
        assert.equal(arrow.attributes.stroke, 'var(--od-blue)');
        assert.equal(arrow.attributes.fill, 'none');
        assert.equal(arrow.attributes.transform, undefined);
        // Both arches use the displayed surface circle as the reference frame.
        const clockwise = direction === 'clockwise', tipX = clockwise ? 10 : 70;
        assert.ok(arrow.attributes.d.startsWith(`M 40 ${cy - 30} A 30 30 0 1 ${clockwise ? 1 : 0} ${tipX} ${cy}`));
        assert.ok(cy - 30 > 0 && cy + 30 < 260);
        const combined = markings.forEntries(a, [rotation, { category: 'temporary_filling', surfaces: ['M'] }, { category: 'extrusion', surfaces: [] }]);
        assert.deepEqual(Array.from(combined.surfaceOutlines), ['M']);
        assert.equal(combined.overlays.length, 2);
      }
    }
  });
});


test('gemination marks only the existing tooth number without adding anatomy or a bottom label', () => {
  Object.values(artwork).forEach(a => {
    assert.equal(markings.forEntries(a, []).gemination, false);
    const result = markings.forEntries(a, [{ category: 'gemination', surfaces: [] }]);
    assert.equal(result.gemination, true);
    assert.equal(result.annotations.length, 0);
    assert.equal(result.overlays.length, 0);
    assert.equal(result.surfaceOutlines.length, 0);
    const combined = markings.forEntries(a, [{ category: 'gemination', surfaces: [] }, { category: 'temporary_crown', surfaces: [] }, { category: 'rotation', rotation_direction: 'clockwise', surfaces: [] }]);
    assert.equal(combined.gemination, true);
    assert.equal(combined.crownWork, true);
    assert.equal(combined.overlays.length, 1);
  });
});


test('impaction and ectopic observations annotate the tooth without inventing position or hiding anatomy', () => {
  Object.values(artwork).forEach(a => {
    for (const category of ['impaction', 'ectopic']) {
      const result = markings.forEntries(a, [{ category, surfaces: [] }]);
      assert.deepEqual(Array.from(result.annotations), [category]);
      assert.equal(result.overlays.length, 0);
      assert.equal(result.surfaceOutlines.length, 0);
      assert.equal(result.missing, false);
      assert.equal(result.implant, false);
      const combined = markings.forEntries(a, [{ category, surfaces: [] }, { category: 'filling', surfaces: ['M'] }]);
      assert.deepEqual(Array.from(combined.annotations), [category]);
      assert.equal(combined.missing, false);
    }
  });
});


test('eruption uses a blue zigzag toward the bite plane on both arches without moving anatomy', () => {
  Object.values(artwork).forEach(a => {
    const entry = { category: 'erupting', surfaces: [] };
    const result = markings.forEntries(a, [entry]);
    assert.equal(result.overlays.length, 1);
    assert.equal(result.missing, false);
    assert.equal(result.implant, false);
    assert.equal(result.surfaceOutlines.length, 0);
    const arrow = result.overlays[0];
    assert.equal(arrow.tag, 'path');
    assert.equal(arrow.attributes.stroke, 'var(--od-blue)');
    assert.equal(arrow.attributes.fill, 'none');
    const points = arrow.attributes.d.match(/-?\d+/g).map(Number);
    const startY = points[1], tipY = points[11];
    assert.ok(a.lower ? tipY < startY : tipY > startY);
    assert.ok(points.every(n => n >= 0 && n <= 260));
    assert.ok(new Set(points.filter((_, i) => i % 2 === 0)).size > 1);
    assert.deepEqual(Array.from(result.annotations), ['erupting']);
    const together = markings.forEntries(a, [entry, { category: 'temporary_filling', surfaces: ['M'] }]);
    assert.deepEqual(Array.from(together.surfaceOutlines), ['M']);
    assert.equal(together.temporary, true);
  });
});


test('abnormal position retains all recorded direction labels without displacement or surface marks', () => {
  Object.values(artwork).forEach(a => {
    for (const directions of [[], ['M', 'V'], ['D', a.lower ? 'L' : 'P']]) {
      const result = markings.forEntries(a, [{ category: 'abnormal_position', surfaces: [], position_directions: directions }]);
      assert.deepEqual(Array.from(result.positionDirections), directions);
      assert.deepEqual(Array.from(result.annotations), directions.length ? [] : ['abnormal_position']);
      assert.equal(result.overlays.length, 0);
      assert.equal(result.missing, false);
      assert.equal(result.surfaceOutlines.length, 0);
    }
  });
});


test('retained roots request root-only anatomy and RR notation while preserving independent root care', () => {
  Object.values(artwork).forEach(a => {
    assert.equal(markings.forEntries(a, []).retainedRoot, false);
    const root = { category: 'retained_root', surfaces: [] };
    const result = markings.forEntries(a, [root]);
    assert.equal(result.retainedRoot, true);
    assert.deepEqual(Array.from(result.annotations), ['retained_root']);
    assert.equal(result.overlays.length, 0);
    assert.equal(result.surfaceOutlines.length, 0);
    const missing = markings.forEntries(a, [root, { category: 'missing', surfaces: [] }]);
    assert.equal(missing.retainedRoot, true);
    assert.equal(missing.missing, false);
    assert.equal(missing.implant, false);
    const treated = markings.forEntries(a, [root, { category: 'rct', surfaces: [] }, { category: 'mobility', surfaces: [] }]);
    assert.deepEqual(Array.from(treated.annotations), ['rct', 'mobility', 'retained_root']);
    assert.equal(treated.retainedRoot, true);
  });
});


test('diastema draws one shared blue gap symbol from its first tooth without changing anatomy', () => {
  const entry = { tooth: 11, paired_tooth: 21, category: 'diastema', surfaces: [] };
  const first = markings.forEntries(artwork[11], [entry], 11);
  const second = markings.forEntries(artwork[21], [entry], 21);
  assert.equal(first.overlays.length, 0);
  assert.equal(second.gap, null);
  assert.ok(first.gap.top > 0 && first.gap.top < 100);
  assert.equal((first.gap.path.match(/Q/g) || []).length, 2);
  assert.equal(first.annotations.length, 0);
  assert.equal(first.surfaceOutlines.length, 0);
});


test('fusion links both tooth numbers while remaining distinct from gemination and a gap', () => {
  for (const pair of [[12, 11], [41, 31], [51, 61], [81, 71]]) {
    const entry = { tooth: pair[0], paired_tooth: pair[1], category: 'fusion', surfaces: [] };
    pair.forEach((tooth, index) => {
      const result = markings.forEntries(artwork[tooth], [entry], tooth);
      assert.equal(result.fusion, true);
      assert.equal(result.fusionStart, index === 0);
      assert.equal(result.gemination, false);
      assert.equal(result.gap, null);
      assert.equal(result.overlays.length, 0);
      assert.equal(result.annotations.length, 0);
      assert.equal(result.surfaceOutlines.length, 0);
    });
  }
});


test('transposition connects identities across the arch without changing tooth drawings', () => {
  for (const row of [[18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28], [85,84,83,82,81,71,72,73,74,75]]) {
    const records = [{ tooth: row[1], paired_tooth: row[4], category: 'transposition', surfaces: [] }];
    assert.deepEqual(Array.from(markings.transpositionSpans(records, row[1], row)), [3]);
    assert.deepEqual(Array.from(markings.transpositionSpans(records, row[4], row)), []);
    const result = markings.forEntries(artwork[row[1]], records, row[1]);
    assert.equal(result.fusion, false);
    assert.equal(result.gemination, false);
    assert.equal(result.overlays.length, 0);
    assert.equal(result.annotations.length, 0);
  }
});

test('an appliance marks actual attachments and joins them across unselected positions', () => {
  for (const row of [[18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28], [85,84,83,82,81,71,72,73,74,75]]) {
    const entry = { category: 'fixed_orthodontic', member_teeth: [row[1], row[3], row[4]], surfaces: [] };
    assert.deepEqual(Array.from(markings.applianceConnections([entry], row[1], row)), [2]);
    assert.deepEqual(Array.from(markings.applianceConnections([entry], row[2], row)), []);
    assert.deepEqual(Array.from(markings.applianceConnections([entry], row[3], row)), [1]);
    assert.deepEqual(Array.from(markings.applianceConnections([entry], row[4], row)), [0]);
    assert.deepEqual(Array.from(markings.applianceConnections([{ ...entry, member_teeth: [row[1]] }], row[1], row)), [0]);
  }
});


test('removable appliances mark only their recorded extent without fixed attachments', () => {
  for (const row of [[13,12,11,21,22,23], [43,42,41,31,32,33]]) {
    const entry = { category: 'removable_orthodontic', member_teeth: row.slice(1,4), surfaces: [] };
    assert.equal(markings.forEntries(artwork[row[0]], [entry], row[0]).removable, null);
    for (const [index,tooth] of entry.member_teeth.entries()) {
      const result = markings.forEntries(artwork[tooth], [entry], tooth);
      assert.equal(result.removable.start, index === 0);
      assert.equal(result.removable.end, index === 2);
      assert.equal(markings.applianceConnections([entry], tooth, row).length, 0);
      assert.equal(result.annotations.length, 0);
    }
  }
});

test('arch absence marks natural outlines without hiding implants or retained roots', () => {
  for (const tooth of [13,33,53,73]) {
    const absence = { category: 'edentulous_arch', surfaces: [] };
    const result = markings.forEntries(artwork[tooth], [absence], tooth);
    assert.equal(result.edentulous, true);
    assert.equal(result.missing, true);
    assert.equal(result.annotations.length, 0);
    assert.equal(markings.forEntries(artwork[tooth], [absence, { category: 'implant', id: 1, surfaces: [] }], tooth).missing, false);
    assert.equal(markings.forEntries(artwork[tooth], [absence, { category: 'retained_root', surfaces: [] }], tooth).missing, false);
  }
});
