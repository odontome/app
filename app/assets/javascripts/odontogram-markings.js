(function () {
  'use strict';
  function surfaceCenter(artwork, surface) {
    const cy = artwork.lower ? 37 : 223;
    const points = [[40, cy - 17], [artwork.mirror ? 23 : 57, cy], [40, cy + 17], [artwork.mirror ? 57 : 23, cy], [40, cy]];
    if (artwork.lower) { points[0][1] = cy + 17; points[2][1] = cy - 17; }
    return points[artwork.surfaceNames.indexOf(surface)];
  }

  function transpositionSpans(entries, tooth, row) {
    return entries.filter(entry => entry.category === 'transposition' && entry.tooth === tooth)
      .map(entry => row.indexOf(entry.paired_tooth) - row.indexOf(tooth)).filter(span => span > 0);
  }

  function applianceConnections(entries, tooth, row) {
    return entries.filter(entry => entry.category === 'fixed_orthodontic' && entry.member_teeth.includes(tooth)).map(entry => {
      const index = entry.member_teeth.indexOf(tooth), next = entry.member_teeth[index + 1];
      return next ? row.indexOf(next) - row.indexOf(tooth) : 0;
    });
  }

  function forEntries(artwork, entries, tooth, row = []) {
    const has = category => entries.some(entry => entry.category === category);
    const retainedRoot = has('retained_root'), edentulous = has('edentulous_arch');
    const denture = entries.find(entry => ['complete_denture', 'partial_denture'].includes(entry.category));
    const bridgeEntry = entries.find(entry => entry.category === 'fixed_bridge' && entry.member_teeth.includes(tooth));
    const bridgeUnit = bridgeEntry?.bridge_units.find(unit => unit.tooth === tooth);
    const bridge = bridgeUnit ? { start: bridgeEntry.member_teeth[0] === tooth, end: bridgeEntry.member_teeth.at(-1) === tooth,
      support: bridgeUnit.role !== 'pontic', pontic: bridgeUnit.role === 'pontic' } : null;
    const replacement = (!!denture && denture.replacement_teeth.includes(tooth)) || (!!bridgeUnit && bridgeUnit.role !== 'natural_support');
    const dentureSpan = !!denture && (denture.category === 'partial_denture' ? replacement : (tooth > 50) === (denture.replacement_teeth[0] > 50));
    const dentureStart = !!denture && replacement && denture.category === 'partial_denture' && !denture.replacement_teeth.includes(row[row.indexOf(tooth) - 1]);
    const dentureEnd = !!denture && replacement && denture.category === 'partial_denture' && !denture.replacement_teeth.includes(row[row.indexOf(tooth) + 1]);
    const removableEntry = entries.find(entry => entry.category === 'removable_orthodontic' && entry.member_teeth.includes(tooth));
    const removable = removableEntry ? { start: removableEntry.member_teeth[0] === tooth, end: removableEntry.member_teeth.at(-1) === tooth } : null;
    const temporary = has('temporary_crown') || has('temporary_filling');
    const overlays = [];
    const fusion = entries.some(entry => entry.category === 'fusion' && [entry.tooth, entry.paired_tooth].includes(tooth));
    const fusionStart = entries.some(entry => entry.category === 'fusion' && entry.tooth === tooth);
    const gap = entries.some(entry => entry.category === 'diastema' && entry.tooth === tooth) ? {
      top: (artwork.crownBounds[1] + artwork.crownBounds[3] / 2) / 260 * 100,
      path: 'M 4 3 Q 12 15 4 27 M 16 3 Q 8 15 16 27'
    } : null;
    const implantEntry = entries.find(entry => entry.category === 'implant');
    const implant = !!implantEntry;
    const implantCrown = implant && entries.some(entry => ['crown', 'temporary_crown'].includes(entry.category) && entry.implant_entry_id === implantEntry.id);
    if (implant) {
      const y = artwork.lower ? artwork.crownBounds[1] + artwork.crownBounds[3] : artwork.crownBounds[1];
      const sign = artwork.lower ? 1 : -1;
      const path = d => overlays.push({ tag: 'path', attributes: { d, fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 2 } });
      path('M 32 ' + y + ' L 35 ' + (y + sign * 70) + ' Q 40 ' + (y + sign * 80) + ' 45 ' + (y + sign * 70) + ' L 48 ' + y + ' Z');
      for (let i = 7; i < 69; i += 9) path('M 32 ' + (y + sign * i) + ' L 48 ' + (y + sign * (i + 4)));
    }
    const surfaceOutlines = Array.from(new Set(entries.filter(entry => entry.category === 'temporary_filling').flatMap(entry => entry.surfaces)));
    if (has('pulpotomy')) {
      const [x, y, width, height] = artwork.crownBounds;
      overlays.push({ tag: 'rect', attributes: { x: x + width * .32, y: y + height * .25,
        width: width * .36, height: height * .3, rx: 2, fill: 'var(--od-blue)' } });
    }
    if (has('peg_shaped')) {
      overlays.push({ tag: 'polygon', attributes: { points: artwork.lower ? '33,248 47,248 40,258' : '33,12 47,12 40,2',
        fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 2 } });
    }
    if (has('erupting')) {
      const y = value => artwork.lower ? 260 - value : value;
      overlays.push({ tag: 'path', attributes: {
        d: 'M 40 ' + y(90) + ' L 34 ' + y(110) + ' L 46 ' + y(130) + ' L 34 ' + y(150) + ' L 40 ' + y(170) + ' L 40 ' + y(190) +
          ' M 34 ' + y(182) + ' L 40 ' + y(190) + ' L 46 ' + y(182),
        fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 2, 'stroke-linejoin': 'round' } });
    }
    if (has('extrusion') || has('intrusion')) {
      const crownSide = artwork.lower ? 94 : 166;
      const biteSide = artwork.lower ? 68 : 192;
      const start = has('extrusion') ? crownSide : biteSide;
      const end = has('extrusion') ? biteSide : crownSide;
      const head = end + (end > start ? -6 : 6);
      overlays.push({ tag: 'path', attributes: {
        d: 'M 75 ' + start + ' L 75 ' + end + ' M 72 ' + head + ' L 75 ' + end + ' L 78 ' + head,
        fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 2 } });
    }
    const position = entries.find(entry => entry.category === 'abnormal_position');
    const positionDirections = position ? position.position_directions : [];
    const rotation = entries.find(entry => entry.category === 'rotation');
    if (rotation && ['clockwise', 'counterclockwise'].includes(rotation.rotation_direction)) {
      const cy = artwork.lower ? 37 : 223;
      const clockwise = rotation.rotation_direction === 'clockwise';
      const tipX = clockwise ? 10 : 70;
      overlays.push({ tag: 'path', attributes: {
        d: 'M 40 ' + (cy - 30) + ' A 30 30 0 1 ' + (clockwise ? 1 : 0) + ' ' + tipX + ' ' + cy +
          ' M ' + (tipX - 5) + ' ' + (cy + 6) + ' L ' + tipX + ' ' + cy + ' L ' + (tipX + 5) + ' ' + (cy + 6),
        fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 2 } });
    }
    // These categories use notation rather than an invented defect or chamber shape.
    const annotations = ['core', 'enamel_defect', 'deep_fissures', 'sealant', 'fracture', 'inlay', 'rct', 'post', 'macrodontia', 'microdontia', 'mobility', 'impaction', 'ectopic', 'erupting', 'retained_root'].filter(has);
    if (position && !positionDirections.length) annotations.push('abnormal_position');
    if (rotation && rotation.rotation_direction === 'unspecified') annotations.push('rotation');
    const wornSurfaces = new Set(entries.filter(entry => entry.category === 'wear').flatMap(entry => entry.surfaces));
    wornSurfaces.forEach(surface => {
      const [x, y] = surfaceCenter(artwork, surface);
      overlays.push({ tag: 'line', attributes: { x1: x - 6, y1: y, x2: x + 6, y2: y,
        stroke: 'var(--od-red)', 'stroke-width': 3 } });
    });
    return { bridge, replacement, dentureSpan, dentureStart, dentureEnd, edentulous, removable, fusion, fusionStart, gap, retainedRoot, positionDirections, gemination: has('gemination'), crownWork: has('temporary_crown'), surfaceOutlines, overlays, temporary, annotations, veneer: has('veneer'), implant, implantCrown, missing: (has('missing') || edentulous) && !implant && !retainedRoot };
  }

  window.OdontogramMarkings = { surfaceCenter, forEntries, transpositionSpans, applianceConnections };
})();
