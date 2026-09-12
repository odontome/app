(function () {
  'use strict';
  const findings = ['caries', 'fracture', 'wear', 'enamel_defect', 'mobility', 'retained_root'];
  const uuid = () => crypto.randomUUID();
  const node = (tag, className, text) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  };
  function entryTeeth(entry) { return entry.member_teeth?.length ? entry.member_teeth : [entry.tooth, entry.paired_tooth].filter(Boolean); }

  function extentTeeth(row, tooth, extent) {
    if (extent === 'arch') return row.slice();
    const start = row.indexOf(tooth), end = row.indexOf(Number(extent));
    return start < 0 || end < 0 ? [] : row.slice(Math.min(start, end), Math.max(start, end) + 1);
  }

  function mobilityDetail(entry) {
    return entry.mobility_grade && entry.mobility_scale ? entry.mobility_grade + ' (' + entry.mobility_scale + ')' : '';
  }

  function toothHistoryPath(root, tooth) {
    return root.dataset.endpoint + '?tooth=' + encodeURIComponent(tooth) +
      (root.dataset.snapshotId ? '&through=' + encodeURIComponent(root.dataset.snapshotId) : '');
  }

  function forgetEditorSession() {
    try { window.sessionStorage.removeItem('odontogram-editor'); } catch (_) { /* Storage may be unavailable. */ }
  }
  function editorSession(root) {
    try {
      const saved = JSON.parse(window.sessionStorage.getItem('odontogram-editor'));
      if (root && root.dataset.odontogramSessionEnabled === 'true' && saved && saved.context === root.dataset.odontogramSession &&
          typeof saved.editor === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(saved.editor)) return saved;
    } catch (_) { /* Continue with an in-memory session. */ }
    forgetEditorSession(); return null;
  }
  function rememberEditorSession(root, editor) {
    if (root.dataset.snapshotId || root.dataset.odontogramSessionEnabled !== 'true') return;
    try { window.sessionStorage.setItem('odontogram-editor', JSON.stringify({ context: root.dataset.odontogramSession, editor })); } catch (_) { /* Continue with an in-memory session. */ }
  }
  function prepareEditorSession(root, navigationType) {
    if (navigationType === 'reload') forgetEditorSession();
    return editorSession(root);
  }
  function start(root) {
    const copy = JSON.parse(root.dataset.copy), $ = selector => root.querySelector(selector);
    const archTeeth = JSON.parse(root.dataset.archTeeth);
    const archForTooth = tooth => Object.keys(archTeeth).find(arch => archTeeth[arch].includes(tooth));
    let archConflicts = {};
    const attachmentConflicts = JSON.parse(root.dataset.attachmentConflicts);
    const treatmentCategories = JSON.parse(root.dataset.treatmentCategories);
    let treatmentStatus = 'existing';
    const planning = () => treatmentCategories.includes(active) && treatmentStatus === 'planned';
    const present = entry => entry.treatment_status !== 'planned';
    const sameStage = entry => planning() ? !present(entry) : present(entry);
    const groupCategories = JSON.parse(root.dataset.groupCategories);
    const toothArches = JSON.parse(root.dataset.toothArches);
    const pairedCategories = JSON.parse(root.dataset.pairedCategories);
    const pairedNeighbors = JSON.parse(root.dataset.pairedNeighbors);
    const transpositionPartners = JSON.parse(root.dataset.transpositionPartners);
    const surfaceCategories = JSON.parse(root.dataset.surfaceCategories);
    const optionalSurfaceCategories = JSON.parse(root.dataset.optionalSurfaceCategories);
    const desktop = matchMedia('(min-width: 736px)');
    let entries = [], presets = [], activePreset = null, revision = 0, editable = false, ready = false, loading = false;
    let changedTeeth = [];
    let active = '', selected = null, mode = 'inspect', busy = false, pending = null, drag = null, suppressClick = false;
    let editor = editorSession(root)?.editor || uuid(), undo = [], draftSurfaces = new Set(), draftDate = '', draftRotation = 'unspecified', draftPosition = new Set(), draftPair = '', draftExtent = 'arch', draftMembers = new Set(), draftReplacement = new Set(), draftBridgeEnd = '', draftBridgeRoles = {}, draftMobility = { grade: '', scale: '' }, formError = '';
    const arches = $('[data-arches]'), details = $('[data-details]');
    const detailsHome = details.parentElement;
    let detailsPopover = null;
    const inspectIcon = $('[data-tool] svg').cloneNode(true);
    const toothLabel = tooth => copy.tooth.replace('%{number}', tooth);
    const markingName = entry => {
      const category = copy.categories[entry.category], name = entry.treatment_snapshot?.name.trim();
      return name && name.toLocaleLowerCase() !== category.toLocaleLowerCase() ? name + ' (' + category + ')' : name || category;
    };
    const activeName = () => activePreset ? activePreset.name : copy.categories[active];
    const markingLabel = entry => markingName(entry) + (entry.bridge_units?.length ? ' · ' + entry.bridge_units.map(unit => unit.tooth + ': ' + copy.bridge_roles[unit.role]).join(', ') : '') + (entry.replacement_teeth?.length ? ' · ' + copy.replacement_positions.replace('%{teeth}', entry.replacement_teeth.join(', ')) : '') + (entry.arch ? ' · ' + copy.arches[entry.arch] : entry.member_teeth?.length ? ' · ' + entry.member_teeth.join(', ') : entry.paired_tooth ? ' · ' + entry.tooth + '–' + entry.paired_tooth : '') + (entry.position_directions?.length ? ' · ' + entry.position_directions.map(direction => copy.position_directions[direction]).join(' · ') : '') + (entry.rotation_direction ? ' · ' + copy.rotation_directions[entry.rotation_direction] : '') + (mobilityDetail(entry) ? ' · ' + mobilityDetail(entry) : '') + (entry.implant_entry_id ? ' · ' + copy.on_implant : '') + (treatmentCategories.includes(entry.category) ? ' · ' + copy.treatment_statuses[entry.treatment_status] : '') + (entry.surfaces.length ? ' · ' + entry.surfaces.join('') : '');
    const label = entry => (entry.arch || entry.paired_tooth || entry.member_teeth?.length ? '' : toothLabel(entry.tooth) + ' · ') + markingLabel(entry);
    const status = (message, highlight = true) => {
      const feedback = $('[data-feedback]');
      feedback.getAnimations().forEach(animation => animation.cancel());
      $('[data-status]').textContent = message;
      if (message && highlight && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
        feedback.animate([
          { opacity: 0, backgroundColor: 'var(--tblr-warning-lt)' },
          { opacity: 1, backgroundColor: 'var(--tblr-warning-lt)', offset: .25 },
          { opacity: 1, backgroundColor: 'transparent' }
        ], { duration: 950, easing: 'ease-out' });
      }
    };
    function reportFormError(message, tooth) {
      if (selected === tooth && editable) {
        formError = message;
        status('');
        showDetails(false);
        const error = details.querySelector('[data-form-error]');
        error.focus({ preventScroll: true });
        error.scrollIntoView({ block: 'nearest' });
      } else {
        if (selected) showDetails(false);
        status(message);
      }
    }
    function clearFormError() {
      formError = '';
      const error = details.querySelector('[data-form-error]');
      if (error) { error.hidden = true; error.textContent = ''; }
    }
    const button = (text, action, className = 'btn btn-sm') => { const b = node('button', className, text); b.type = 'button'; b.addEventListener('click', action); return b; };
    const canWrite = () => canChoose() && ready && !pending;
    const canChoose = () => editable && !loading && !busy && desktop.matches;
    function controls() {
      $('.od-tools').hidden = !editable;
      $('[data-undo]').hidden = !editable || !undo.length;
      $('[data-undo]').disabled = loading || busy || !!pending;
      $('[data-tool]').disabled = loading || busy;
      $('[data-treatment-status]').disabled = loading || busy;
      $('[data-dentition]').disabled = loading || busy;
      $('[data-retry]').hidden = !pending || busy;
      root.setAttribute('aria-busy', String(busy));
    }
    function adopt(state) {
      archConflicts = state.arch_conflicts;
      entries = state.entries; presets = state.presets || []; revision = state.revision; editable = state.editable && !root.dataset.snapshotId;
      changedTeeth = root.dataset.snapshotId ? JSON.parse(root.dataset.changedTeeth) : [];
      if (activePreset && !presets.some(p => p.id === activePreset.id && p.version === activePreset.version)) { active = ''; activePreset = null; }
      if (!editable) {
        active = ''; activePreset = null; undo = []; editor = uuid();
        if (!root.dataset.snapshotId) forgetEditorSession();
      } else {
        undo = state.undo || [];
        rememberEditorSession(root, editor);
      }
      controls(); render(); updateSummary();
    }
    async function load() {
      if (loading || !desktop.matches) return;
      loading = true; ready = false; controls(); $('.od-desktop').hidden = false;
      try {
        if (!window.OdontogramArtwork) {
          await new Promise((resolve, reject) => {
            const script = document.createElement('script'); script.src = root.dataset.artwork;
            script.onload = resolve; script.onerror = () => { script.remove(); reject(new Error('artwork')); };
            document.head.appendChild(script);
          });
        }
        const url = root.dataset.endpoint + '.json' + (root.dataset.snapshotId ? '?at=' + encodeURIComponent(root.dataset.snapshotId) : '?editor_id=' + encodeURIComponent(editor));
        const response = await fetch(url, { headers: { Accept: 'application/json' }, cache: 'no-store' });
        if (!response.ok) throw new Error('chart');
        ready = true; root.classList.add('od-loaded'); adopt(await response.json());
        status(editable ? copy.unrecorded : copy.read_only, false);
        $('[data-refresh]').hidden = true;
      } catch (_) { ready = false; status(copy.load_failed); $('[data-refresh]').hidden = false; }
      finally { loading = false; controls(); }
    }
    function updateSummary() {
      const summary = $('.od-summary'); summary.replaceChildren();
      if (!entries.length) summary.append(node('p', 'text-muted mb-0', copy.empty));
      entries.slice(-3).reverse().forEach(entry => summary.append(node('div', '', label(entry))));
      summary.append(node('p', 'text-muted mt-2 mb-0 od-phone-note', copy.phone));
    }
    function svgNode(tag, attrs) {
      const element = document.createElementNS('http://www.w3.org/2000/svg', tag);
      Object.entries(attrs).forEach(([key, value]) => element.setAttribute(key, value)); return element;
    }
    function drawTooth(tooth, row, plannedLayer = false) {
      const a = window.OdontogramArtwork[tooth], allRecords = entries.filter(e => entryTeeth(e).includes(tooth));
      const records = allRecords.filter(entry => plannedLayer ? !present(entry) : present(entry));
      const b = node('button', 'od-tooth'); b.type = 'button'; b.dataset.tooth = tooth;
      if (records.some(entry => entry.category === 'diastema' && entry.tooth === tooth)) b.classList.add('od-pair-start');
      if (changedTeeth.includes(tooth)) b.classList.add('od-changed');
      b.setAttribute('aria-label', toothLabel(tooth) + ': ' + (allRecords.length ? allRecords.map(label).join('; ') : copy.unrecorded));
      b.setAttribute('aria-expanded', String(selected === tooth));
      // SVG is bundled original artwork, never patient-supplied markup.
      b.innerHTML = a.svg;
      const svg = b.querySelector('svg'); svg.removeAttribute('aria-labelledby'); svg.setAttribute('aria-hidden', 'true');
      svg.querySelectorAll('[id]').forEach(e => e.removeAttribute('id'));
      const artworkWrap = node('span', 'od-tooth-artwork'); svg.replaceWith(artworkWrap); artworkWrap.append(svg);
      const number = node('span', 'od-tooth-number');
      number.append(node('span', 'od-tooth-number-text', tooth));
      a.lower ? b.append(number) : b.prepend(number);
      window.OdontogramMarkings.transpositionSpans(records, tooth, row).forEach(span => {
        b.classList.add('od-transposition-start', 'od-pair-start');
        const link = node('span', 'od-transposition'); link.setAttribute('aria-hidden', 'true');
        link.style.width = (span * 100) + '%';
        const curves = svgNode('svg', { viewBox: '0 0 100 12', preserveAspectRatio: 'none' });
        curves.append(svgNode('path', { d: 'M 0 2 C 35 2 65 10 100 10 M 100 2 C 65 2 35 10 0 10',
          fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 1.5, 'vector-effect': 'non-scaling-stroke' }));
        link.append(curves);
        ['left', 'right'].forEach(side => {
          const tip = svgNode('svg', { class: 'od-transposition-tip od-tip-' + side, viewBox: '0 0 8 8' });
          tip.append(svgNode('path', { d: side === 'left' ? 'M 6 1 L 1 4 L 6 7' : 'M 2 1 L 7 4 L 2 7',
            fill: 'none', stroke: 'var(--od-blue)', 'stroke-width': 1.5, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }));
          link.append(tip);
        });
        number.append(link);
      });
      if (!plannedLayer && allRecords.length > 1) {
        const count = node('span', 'badge bg-primary text-primary-fg od-count', allRecords.length);
        count.setAttribute('aria-hidden', 'true');
        b.append(count);
      }
      const part = name => svg.querySelector('[data-part="' + name + '"]');
      const overlays = svgNode('g', { class: 'od-overlay', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }); svg.append(overlays);
      const blue = 'var(--od-blue)', red = 'var(--od-red)';
      const has = category => records.some(e => e.category === category);
      a.surfaceNames.forEach(surface => {
        const items = records.filter(e => e.surfaces.includes(surface)); if (!items.length) return;
        const work = items.some(e => ['filling', 'inlay'].includes(e.category)), finding = items.some(e => e.category === 'caries');
        const target = part('surface-' + surface);
        if (work || finding) target.setAttribute(work ? 'data-work' : 'data-finding', '');
        const [x, y] = window.OdontogramMarkings.surfaceCenter(a, surface);
        if (work && finding) overlays.append(svgNode('circle', { cx: x, cy: y, r: 4, fill: red, stroke: 'var(--od-panel)', 'stroke-width': 1 }));
      });
      const additional = window.OdontogramMarkings.forEntries(a, records, tooth, row);
      if (additional.replacement) {
        const crown = part('crown').cloneNode(true);
        crown.removeAttribute('data-part'); crown.setAttribute('class', 'od-denture-crown');
        crown.setAttribute('fill', plannedLayer ? 'none' : blue); crown.setAttribute('fill-opacity', '.6');
        crown.setAttribute('stroke', blue); crown.setAttribute('stroke-width', '2');
        overlays.append(crown);
      }
      if (additional.dentureSpan) {
        const lines = node('span', 'od-denture-span'); lines.setAttribute('aria-hidden', 'true');
        lines.style.top = (a.lower ? 96 : 4) + '%';
        lines.style.left = additional.dentureStart ? '6px' : '0';
        lines.style.width = 'calc(100% - ' + ((additional.dentureStart ? 6 : 0) + (additional.dentureEnd ? 6 : 0)) + 'px)'; artworkWrap.append(lines);
      }
      if (additional.bridge) {
        const link = node('span', 'od-bridge'); link.setAttribute('aria-hidden', 'true');
        link.style.top = (a.lower ? 96 : 4) + '%';
        const wire = node('span', 'od-bridge-wire');
        wire.style.left = additional.bridge.start ? '50%' : '0';
        wire.style.width = additional.bridge.start || additional.bridge.end ? '50%' : '100%';
        link.append(wire);
        if (additional.bridge.support) link.append(node('span', 'od-bridge-support'));
        artworkWrap.append(link);
        if (additional.bridge.pontic) b.classList.add('od-bridge-pontic');
      }
      if (has('crown') || additional.crownWork) part('crown').setAttribute('data-work', '');
      if (additional.veneer) {
        const layer = part('crown').cloneNode(true), [cx, cy, cw, ch] = a.crownBounds;
        layer.removeAttribute('data-part'); layer.removeAttribute('data-work');
        layer.setAttribute('class', 'od-veneer');
        layer.setAttribute('transform', 'translate(' + (cx + cw / 2) + ' ' + (cy + ch / 2) + ') scale(.8 .8) translate(' + -(cx + cw / 2) + ' ' + -(cy + ch / 2) + ')');
        layer.setAttribute('fill', plannedLayer ? 'none' : blue); layer.setAttribute('fill-opacity', '.6');
        layer.setAttribute('stroke', blue); layer.setAttribute('stroke-width', '2');
        overlays.append(layer);
      }
      additional.surfaceOutlines.forEach(surface => {
        const outline = part('surface-' + surface).cloneNode(true);
        outline.removeAttribute('data-part'); outline.removeAttribute('data-work'); outline.removeAttribute('data-finding');
        outline.setAttribute('fill', 'none'); outline.setAttribute('stroke', blue); outline.setAttribute('stroke-width', 2.5);
        overlays.append(outline);
      });
      additional.overlays.forEach(shape => overlays.append(svgNode(shape.tag, shape.attributes)));
      if (additional.gap) {
        const gap = svgNode('svg', { class: 'od-gap', viewBox: '0 0 20 30', 'aria-hidden': 'true' });
        gap.style.top = additional.gap.top + '%';
        gap.append(svgNode('path', { d: additional.gap.path, fill: 'none', stroke: blue, 'stroke-width': 2, 'stroke-linecap': 'round' }));
        artworkWrap.append(gap);
      }
      window.OdontogramMarkings.applianceConnections(records, tooth, row).forEach(span => {
        b.classList.add('od-pair-start');
        const attachment = node('span', 'od-appliance'); attachment.setAttribute('aria-hidden', 'true');
        attachment.style.top = (a.lower ? 96 : 4) + '%'; attachment.style.width = (span * 100) + '%';
        if (span) attachment.append(node('span', 'od-appliance-wire'));
        const square = svgNode('svg', { class: 'od-appliance-attachment', viewBox: '0 0 12 12' });
        square.append(svgNode('path', { d: 'M 1 1 H 11 V 11 H 1 Z M 1 1 L 11 11 M 11 1 L 1 11',
          fill: 'var(--od-panel)', stroke: blue, 'stroke-width': 1.5 }));
        attachment.append(square); artworkWrap.append(attachment);
      });
      if (additional.removable) {
        const wave = svgNode('svg', { class: 'od-removable', viewBox: '0 0 40 12', preserveAspectRatio: 'none', 'aria-hidden': 'true' });
        wave.style.top = (a.lower ? 100 : 0) + '%';
        wave.style.left = additional.removable.start ? '6px' : '0';
        wave.style.width = 'calc(100% - ' + ((additional.removable.start ? 6 : 0) + (additional.removable.end ? 6 : 0)) + 'px)';
        wave.append(svgNode('path', { d: 'M 0 6 L 5 2 L 15 10 L 25 2 L 35 10 L 40 6',
          fill: 'none', stroke: blue, 'stroke-width': 1.5, 'vector-effect': 'non-scaling-stroke' }));
        artworkWrap.append(wave);
      }
      if (additional.edentulous) {
        const line = node('span', 'od-arch-absence'); line.setAttribute('aria-hidden', 'true');
        line.style.top = (a.lower ? 100 / 260 : 160 / 260) * 100 + '%'; artworkWrap.append(line);
      }
      const notation = node('span', 'od-notations');
      notation.setAttribute('aria-hidden', 'true');
      const appendNotation = indicator => {
        if (notation.childNodes.length) notation.append(document.createTextNode(' · '));
        notation.append(indicator);
      };
      additional.annotations.forEach(category => {
        const indicator = node('span', 'od-notation ' + (findings.includes(category) ? 'od-finding' : 'od-work'), copy.notation[category]);
        if (category === 'impaction') indicator.classList.add('od-impaction');
        indicator.title = copy.categories[category];
        indicator.setAttribute('aria-hidden', 'true');
        appendNotation(indicator);
      });
      additional.positionDirections.forEach(direction => {
        const indicator = node('span', 'od-notation od-work', direction);
        indicator.title = copy.position_directions[direction];
        appendNotation(indicator);
      });
      if (additional.temporary) {
        const indicator = node('span', 'od-temporary od-work', copy.temporary_indicator);
        indicator.setAttribute('aria-hidden', 'true');
        appendNotation(indicator);
      }
      notation.title = notation.textContent;
      b.append(notation);
      if (additional.fusion) b.classList.add('od-fusion');
      if (additional.fusionStart) b.classList.add('od-fusion-start');
      if (additional.gemination) b.classList.add('od-gemination');
      if (additional.retainedRoot) b.classList.add('od-retained-root');
      if (additional.missing) b.classList.add('od-missing');
      if (additional.implant) {
        b.classList.add('od-implant');
        if (!additional.implantCrown) b.classList.add('od-implant-bare');
      }
      if (plannedLayer) {
        // Keep the current anatomy untouched; planned work is a separate red overlay.
        artworkWrap.classList.add('od-planned-layer');
        artworkWrap.setAttribute('aria-hidden', 'true');
        svg.querySelectorAll('[data-part]').forEach(part => {
          if (part.hasAttribute('data-work')) {
            const shape = part.cloneNode(true);
            shape.removeAttribute('data-part'); shape.removeAttribute('data-work');
            shape.setAttribute('fill', 'none'); shape.setAttribute('stroke', red); shape.setAttribute('stroke-width', '2.5');
            overlays.append(shape);
          }
          part.remove();
        });
        svg.querySelectorAll('text, title, desc').forEach(element => element.remove());
      } else if (allRecords.some(entry => !present(entry))) {
        const plan = drawTooth(tooth, row, true);
        artworkWrap.append(plan.querySelector('.od-tooth-artwork'));
        const plannedNotation = plan.querySelector('.od-notations');
        if (plannedNotation.textContent) {
          if (notation.textContent) notation.append(document.createTextNode(' · '));
          const text = node('span', 'od-finding', plannedNotation.textContent);
          notation.append(text); notation.title = notation.textContent;
        }
      }
      return b;
    }
    function render() {
      if (!ready || !desktop.matches) return;
      disposeDetailsPopover();
      arches.replaceChildren();
      const dentition = $('[data-dentition]').value;
      const rows = [];
      const upper = [18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28], lower = [48,47,46,45,44,43,42,41,31,32,33,34,35,36,37,38];
      if (dentition !== 'primary') rows.push(upper);
      if (dentition !== 'permanent') rows.push([55,54,53,52,51,61,62,63,64,65], [85,84,83,82,81,71,72,73,74,75]);
      if (dentition !== 'primary') rows.push(lower);
      rows.forEach(teeth => { const row = node('div', 'od-arch' + (teeth.length === 10 ? ' od-arch-primary' : '')); teeth.forEach(t => row.append(drawTooth(t, teeth))); arches.append(row); });
      const shown = rows.flat(); $('[data-hidden-teeth]').hidden = !entries.some(e => (e.replacement_teeth?.length ? e.replacement_teeth : e.arch ? [] : entryTeeth(e)).some(tooth => !shown.includes(tooth))); $('[data-hidden-teeth]').textContent = copy.hidden_teeth;
      if (selected && !shown.includes(selected)) closeDetails();
      if (selected) showDetails(false);
      $('[data-tool-label]').textContent = active ? activeName() : copy.inspect;
      $('[data-tool-icon]').replaceChildren(active ? node('span', 'od-swatch' + (findings.includes(active) || planning() ? ' od-swatch-finding' : '')) : inspectIcon.cloneNode(true));
      $('[data-treatment-status]').hidden = !editable || !treatmentCategories.includes(active);
      $('[data-treatment-status]').value = treatmentStatus;
      $('[data-hint]').textContent = !editable ? copy.read_only : active ? (surfaceCategories.includes(active) ? copy.surface_hint : copy.tooth_hint) : copy.inspect_hint;
    }
    function disposeDetailsPopover() {
      if (detailsPopover) { detailsPopover.dispose(); detailsPopover = null; }
      details.hidden = true;
      detailsHome.append(details);
    }
    function closeDetails(restoreFocus = true) {
      const old = selected; selected = null; formError = ''; disposeDetailsPopover(); details.replaceChildren();
      const target = arches.querySelector('[data-tooth="' + old + '"]');
      if (target) {
        target.setAttribute('aria-expanded', 'false'); target.removeAttribute('aria-describedby');
        if (restoreFocus) target.focus({ preventScroll: true });
      }
    }
    function removableReason(tooth, extent) {
      const members = extentTeeth(toothArches.find(row => row.includes(tooth)), tooth, extent);
      const appliance = entries.find(entry => sameStage(entry) && entry.category === 'removable_orthodontic' && entry.member_teeth.some(number => members.includes(number)));
      return appliance ? copy.attachment_in_use.replace('%{teeth}', appliance.member_teeth.join(', ')) : '';
    }
    function attachmentReason(tooth) {
      const conflicts = entries.filter(entry => !planning() && present(entry) && (entry.tooth === tooth || entry.member_teeth?.includes(tooth)) && attachmentConflicts.includes(entry.category));
      if (conflicts.length) return copy.attachment_unavailable.replace('%{reason}', conflicts.map(entry => copy.categories[entry.category]).join(', '));
      const appliance = entries.find(entry => sameStage(entry) && entry.category === active && entry.member_teeth?.includes(tooth));
      return appliance ? copy.attachment_in_use.replace('%{teeth}', appliance.member_teeth.join(', ')) : '';
    }
    function attachmentChoice(tooth) {
      const reason = attachmentReason(tooth), label = node('label', 'form-selectgroup-item');
      const check = node('input', 'form-selectgroup-input'); check.type = 'checkbox'; check.value = tooth;
      check.checked = draftMembers.has(tooth) && !reason; check.disabled = !!reason || tooth === selected;
      if (tooth === selected) check.dataset.attachmentAnchor = '';
      if (reason) {
        draftMembers.delete(tooth);
        check.dataset.selectionUnavailable = ''; label.title = reason;
        check.setAttribute('aria-label', toothLabel(tooth) + ': ' + reason);
      }
      check.addEventListener('change', () => { check.checked ? draftMembers.add(tooth) : draftMembers.delete(tooth); clearFormError(); });
      label.append(check, node('span', 'form-selectgroup-label px-2' + (reason ? ' bg-secondary-lt text-muted' : ''), tooth));
      return label;
    }
    function replacementReason(tooth) {
      if (active !== 'partial_denture') return '';
      const records = entries.filter(entry => entryTeeth(entry).includes(tooth));
      if (records.some(entry => sameStage(entry) && ['complete_denture', 'partial_denture', 'fixed_bridge'].includes(entry.category))) return copy.denture_overlap;
      if (!planning() && !records.some(entry => present(entry) && ['missing', 'edentulous_arch'].includes(entry.category))) return copy.partial_absence;
      return '';
    }
    function bridgeRoleReason(tooth, role) {
      const records = entries.filter(entry => entryTeeth(entry).includes(tooth));
      if (records.some(entry => sameStage(entry) && ['fixed_bridge', 'complete_denture', 'partial_denture'].includes(entry.category))) return copy.bridge_overlap;
      if (planning() && role !== 'implant_support') return '';
      const absent = records.filter(present).some(entry => ['missing', 'edentulous_arch'].includes(entry.category));
      const implant = records.some(entry => (planning() || present(entry)) && entry.category === 'implant');
      const root = records.filter(present).some(entry => entry.category === 'retained_root');
      const valid = role === 'natural_support' ? !absent && !implant && !root : role === 'implant_support' ? implant : role === 'pontic' && absent && !implant && !root;
      return valid ? '' : copy.bridge_support.replace('%{tooth}', tooth);
    }
    function bridgeUnits(tooth) {
      const row = toothArches.find(row => row.includes(tooth));
      return extentTeeth(row, tooth, draftBridgeEnd).map(number => {
        const role = draftBridgeRoles[number] || '';
        const unit = { tooth: number, role };
        if (role === 'implant_support') unit.implant_entry_id = entries.find(entry => (planning() || present(entry)) && entry.category === 'implant' && entry.tooth === number)?.id;
        return unit;
      });
    }
    function dentureReason(tooth) {
      const arch = archForTooth(tooth), records = entries.filter(entry => entry.arch === arch || (entry.category === 'fixed_bridge' && archForTooth(entry.tooth) === arch));
      if (records.some(entry => sameStage(entry) && (entry.category === 'complete_denture' || (active === 'complete_denture' && ['partial_denture', 'fixed_bridge'].includes(entry.category))))) return copy.denture_overlap;
      if (!planning() && active === 'complete_denture' && !records.some(entry => entry.category === 'edentulous_arch')) return copy.denture_absence;
      return '';
    }
    function dentureAvailability(tooth) {
      const row = toothArches.find(row => row.includes(tooth)), reason = dentureReason(tooth);
      const reasons = reason ? [reason] : [...new Set(row.map(replacementReason).filter(Boolean))];
      return {
        eligible: reason ? [] : row.filter(tooth => !replacementReason(tooth)),
        hints: reasons.map(reason => reason === copy.partial_absence ? copy.partial_picker_hint : reason)
      };
    }
    function showDetails(focus = true) {
      if (!desktop.matches) return;
      disposeDetailsPopover();
      details.replaceChildren(); details.hidden = false;
      const header = node('div', 'd-flex align-items-center justify-content-between');
      const heading = node('h3', 'mb-0', mode === 'add' && ['edentulous_arch', 'complete_denture', 'partial_denture'].includes(active) ? copy.arches[archForTooth(selected)] : toothLabel(selected)); heading.id = 'od-tooth-title-' + editor;
      const close = button('', () => closeDetails(), 'btn-close');
      close.setAttribute('aria-label', copy.close);
      header.append(heading, close); details.append(header);
      if (mode === 'add' && active && editable) {
        details.append(node('p', 'mt-2 mb-2', markingName({ category: active, treatment_snapshot: activePreset })));
        if (treatmentCategories.includes(active)) details.append(node('p', planning() ? 'text-danger small mb-2' : 'text-primary small mb-2', copy.treatment_statuses[treatmentStatus]));
        if (surfaceCategories.includes(active)) {
          details.append(node('p', 'text-muted small', optionalSurfaceCategories.includes(active) ? copy.optional_surfaces : copy.surfaces));
          const surfaces = node('div');
          window.OdontogramArtwork[selected].surfaceNames.forEach(surface => {
            const check = node('input', 'form-check-input'); check.type = 'checkbox'; check.value = surface; check.checked = draftSurfaces.has(surface);
            check.addEventListener('change', () => { check.checked ? draftSurfaces.add(surface) : draftSurfaces.delete(surface); clearFormError(); });
            const l = node('label', 'od-surface'); l.append(check, document.createTextNode(surface)); surfaces.append(l);
          }); details.append(surfaces, node('p', 'text-muted small mt-2', copy.surface_names));
        }
        if (active === 'edentulous_arch') {
          const arch = archForTooth(selected), conflicts = entries.filter(entry => archConflicts[arch].includes(entry.id));
          details.append(node('p', 'text-muted small', copy.arch_review));
          if (conflicts.length) {
            details.append(node('p', 'text-danger small', copy.arch_conflict));
            const list = node('ul', 'small ps-3');
            conflicts.forEach(entry => list.append(node('li', '', label(entry)))); details.append(list);
          }
        }
        if (active === 'fixed_bridge') {
          const hint = node('p', 'text-muted small', copy.bridge_hint); hint.id = 'od-bridge-hint-' + editor; details.append(hint);
          const field = node('label', 'form-label w-100', copy.bridge_end);
          const select = node('select', 'form-select'); select.setAttribute('aria-describedby', hint.id); select.dataset.bridgeEnd = '';
          const placeholder = node('option', '', copy.bridge_choose_end); placeholder.value = ''; select.append(placeholder);
          toothArches.find(row => row.includes(selected)).filter(tooth => tooth !== selected).forEach(tooth => {
            const option = node('option', '', tooth); option.value = tooth; select.append(option);
          });
          select.value = draftBridgeEnd;
          select.addEventListener('change', () => { draftBridgeEnd = select.value; draftBridgeRoles = {}; clearFormError(); showDetails(false); details.querySelector('[data-bridge-end]').focus({ preventScroll: true }); });
          field.append(select); details.append(field);
          bridgeUnits(selected).forEach(unit => {
            const label = node('label', 'form-label w-100', toothLabel(unit.tooth));
            const roles = node('select', 'form-select');
            const blank = node('option', '', copy.bridge_choose_role); blank.value = ''; roles.append(blank);
            Object.entries(copy.bridge_roles).forEach(([role, text]) => {
              const option = node('option', '', text); option.value = role;
              const reason = bridgeRoleReason(unit.tooth, role); option.disabled = !!reason; option.title = reason; roles.append(option);
            });
            roles.value = unit.role;
            roles.addEventListener('change', () => { draftBridgeRoles[unit.tooth] = roles.value; clearFormError(); });
            label.append(roles); details.append(label);
            if (Object.keys(copy.bridge_roles).every(role => bridgeRoleReason(unit.tooth, role))) {
              details.append(node('p', 'text-muted small', bridgeRoleReason(unit.tooth, 'natural_support')));
            }
          });
        }
        if (['complete_denture', 'partial_denture'].includes(active)) {
          const availability = dentureAvailability(selected);
          const hint = node('p', 'text-muted small', availability.hints.length ? availability.hints.join(' ') : copy.denture_review);
          hint.id = 'od-replacement-hint-' + editor;
          details.append(hint);
          const fields = node('fieldset', 'mt-2');
          fields.setAttribute('aria-describedby', hint.id);
          fields.append(node('legend', 'form-label', copy.replacement_teeth));
          const choices = node('div', 'form-selectgroup');
          const row = toothArches.find(row => row.includes(selected));
          const eligible = availability.eligible;
          draftReplacement = new Set([...draftReplacement].filter(tooth => eligible.includes(tooth)));
          const allLabel = node('label', 'form-check mb-2');
          const all = node('input', 'form-check-input'); all.type = 'checkbox';
          if (!eligible.length) { all.disabled = true; all.dataset.selectionUnavailable = ''; }
          const syncAll = () => { all.checked = eligible.length > 0 && eligible.every(tooth => draftReplacement.has(tooth)); all.indeterminate = draftReplacement.size > 0 && !all.checked; };
          syncAll();
          all.addEventListener('change', () => {
            draftReplacement = new Set(all.checked ? eligible : []);
            choices.querySelectorAll('input').forEach(check => { check.checked = !check.disabled && all.checked; }); clearFormError();
          });
          allLabel.append(all, node('span', 'form-check-label', copy.select_all)); fields.append(allLabel);
          row.forEach(tooth => {
            const label = node('label', 'form-selectgroup-item');
            const check = node('input', 'form-selectgroup-input'); check.type = 'checkbox'; check.checked = draftReplacement.has(tooth);
            const reason = dentureReason(selected) || replacementReason(tooth);
            if (reason) { check.disabled = true; check.dataset.selectionUnavailable = ''; label.title = reason; check.setAttribute('aria-label', toothLabel(tooth) + ': ' + reason); }
            check.addEventListener('change', () => { check.checked ? draftReplacement.add(tooth) : draftReplacement.delete(tooth); syncAll(); clearFormError(); });
            label.append(check, node('span', 'form-selectgroup-label' + (reason ? ' bg-secondary-lt text-muted' : ''), tooth)); choices.append(label);
          });
          fields.append(choices); details.append(fields);
        }
        if (active === 'fixed_orthodontic') {
          const fields = node('fieldset', 'mt-2');
          fields.append(node('legend', 'form-label', copy.attachment_teeth));
          const choices = node('div', 'form-selectgroup');
          toothArches.find(row => row.includes(selected)).forEach(tooth => choices.append(attachmentChoice(tooth)));
          fields.append(choices); details.append(fields, node('p', 'text-muted small mt-2', attachmentReason(selected) || copy.attachment_hint));
        }
        if (active === 'removable_orthodontic') {
          const field = node('label', 'form-label w-100 mt-2', copy.removable_extent);
          const select = node('select', 'form-select'); select.dataset.removableExtent = '';
          const row = toothArches.find(teeth => teeth.includes(selected));
          ['arch', ...row.map(String)].forEach(value => {
            const text = value === 'arch' ? copy.whole_arch : copy.extent_to.replace('%{number}', value);
            const option = node('option', '', text); option.value = value;
            option.disabled = !!removableReason(selected, value); select.append(option);
          });
          select.value = draftExtent;
          select.addEventListener('change', () => {
            draftExtent = select.value; clearFormError(); showDetails(false);
            details.querySelector('[data-removable-extent]').focus({ preventScroll: true });
          });
          field.append(select); details.append(field, node('p', 'text-muted small', removableReason(selected, draftExtent) || copy.removable_hint));
        }
        if (pairedCategories.includes(active)) {
          const pairLabel = node('label', 'form-label w-100 mt-2', copy[active === 'transposition' ? 'transposition_tooth' : 'paired_tooth']);
          const select = node('select', 'form-select');
          const placeholder = node('option', '', copy.choose_neighbor); placeholder.value = ''; select.append(placeholder);
          (active === 'transposition' ? transpositionPartners : pairedNeighbors)[selected].forEach(tooth => { const option = node('option', '', toothLabel(tooth)); option.value = tooth; select.append(option); });
          select.value = draftPair;
          select.addEventListener('change', () => { draftPair = select.value; clearFormError(); });
          pairLabel.append(select); details.append(pairLabel, node('p', 'text-muted small', copy[active === 'transposition' ? 'transposition_hint' : active === 'fusion' ? 'fusion_hint' : 'pair_hint']));
        }
        if (active === 'abnormal_position') {
          const fields = node('fieldset', 'mt-2');
          fields.append(node('legend', 'form-label', copy.position_label));
          const inward = window.OdontogramArtwork[selected].lower ? 'L' : 'P';
          ['M', 'D', 'V', inward].forEach(direction => {
            const label = node('label', 'form-check');
            const check = node('input', 'form-check-input'); check.type = 'checkbox'; check.value = direction; check.checked = draftPosition.has(direction);
            check.addEventListener('change', () => { check.checked ? draftPosition.add(direction) : draftPosition.delete(direction); clearFormError(); });
            label.append(check, node('span', 'form-check-label', copy.position_directions[direction]));
            fields.append(label);
          });
          details.append(fields, node('p', 'text-muted small', copy.position_hint));
        }
        if (active === 'rotation') {
          const directionLabel = node('label', 'form-label w-100 mt-2', copy.rotation_direction);
          const select = node('select', 'form-select');
          Object.entries(copy.rotation_directions).forEach(([value, text]) => {
            const option = node('option', '', text); option.value = value; select.append(option);
          });
          select.value = draftRotation;
          select.addEventListener('change', () => { draftRotation = select.value; clearFormError(); });
          directionLabel.append(select);
          details.append(directionLabel, node('p', 'text-muted small', copy.rotation_hint));
        }
        if (active === 'mobility') {
          const implant = entries.some(entry => present(entry) && entry.tooth === selected && entry.category === 'implant');
          details.append(node('p', 'text-muted small mb-2', implant ? copy.on_implant : copy.natural_tooth));
          const fields = node('div', 'row g-2');
          [['grade', 10], ['scale', 60]].forEach(([key, limit]) => {
            const column = node('div', key === 'grade' ? 'col-4' : 'col-8');
            const fieldLabel = node('label', 'form-label w-100 text-nowrap', copy['mobility_' + key]);
            const input = node('input', 'form-control'); input.type = 'text'; input.maxLength = limit;
            input.value = draftMobility[key];
            input.addEventListener('input', () => { draftMobility[key] = input.value; clearFormError(); });
            fieldLabel.append(input); column.append(fieldLabel); fields.append(column);
          });
          details.append(fields, node('p', 'text-muted small mb-0', copy.mobility_hint));
        }
        const dateLabel = node('label', 'form-label mt-2', copy.observation_date), date = node('input', 'form-control'); date.type = 'date'; date.value = draftDate;
        date.addEventListener('change', () => { draftDate = date.value; clearFormError(); }); dateLabel.append(date); details.append(dateLabel);
        const error = node('div', 'alert alert-danger py-2 mt-2 mb-0', formError);
        error.dataset.formError = ''; error.hidden = !formError; error.tabIndex = -1;
        error.setAttribute('role', 'alert');
        details.append(error);
        const submit = button(copy.add, () => add(selected, Array.from(draftSurfaces), draftDate), 'btn btn-primary mt-2');
        if ((active === 'fixed_orthodontic' && attachmentReason(selected)) || (active === 'removable_orthodontic' && removableReason(selected, draftExtent))) submit.dataset.selectionUnavailable = '';
        if (active === 'edentulous_arch' && archConflicts[archForTooth(selected)].length) submit.dataset.selectionUnavailable = '';
        if (active === 'fixed_bridge' && bridgeUnits(selected).some(unit => Object.keys(copy.bridge_roles).every(role => bridgeRoleReason(unit.tooth, role)))) submit.dataset.selectionUnavailable = '';
        if (['complete_denture', 'partial_denture'].includes(active) && !dentureAvailability(selected).eligible.length) submit.dataset.selectionUnavailable = '';
        details.append(submit);
      } else {
        const records = entries.filter(e => entryTeeth(e).includes(selected));
        if (!records.length) details.append(node('p', 'text-muted mt-2', copy.empty));
        records.forEach(entry => {
          const row = node('div', 'od-entry'), text = node('div', 'od-entry-description'); text.append(node('div', '', markingLabel(entry)));
          row.append(text);
          if (editable && entry.treatment_status === 'planned') {
            const done = button(copy.mark_done, () => { if (canWrite()) save({ operation: 'complete', entry_id: entry.id }, entry); }, 'btn btn-sm btn-ghost-primary text-nowrap');
            const icon = svgNode('svg', { class: 'icon', viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': 2, 'aria-hidden': 'true' });
            icon.append(svgNode('path', { d: 'M5 12l4 4L19 6' })); done.prepend(icon);
            text.append(done);
          }
          if (editable) row.append(button(copy.remove, () => { if (canWrite() && window.confirm(copy.confirm_remove.replace('%{marking}', label(entry)))) save({ operation: 'remove', entry_id: entry.id }, entry); }, 'btn btn-sm btn-ghost-danger flex-shrink-0'));
          details.append(row);
        });
        const error = node('div', 'alert alert-danger py-2 mt-2 mb-0', formError);
        error.dataset.formError = ''; error.hidden = !formError; error.tabIndex = -1; error.setAttribute('role', 'alert'); details.append(error);
        const footer = node('div', 'd-flex align-items-center justify-content-between gap-3 mt-2');
        if (editable) footer.append(button(copy.add, event => { event.stopPropagation(); openMenu(true); }));
        const history = node('a', 'small', copy.view_history);
        history.href = toothHistoryPath(root, selected);
        footer.append(history); details.append(footer);
      }
      details.querySelectorAll('button, input, select').forEach(control => { control.disabled = busy || !!pending || control.hasAttribute('data-attachment-anchor') || control.hasAttribute('data-selection-unavailable'); });
      const anchor = arches.querySelector('[data-tooth="' + selected + '"]');
      if (!anchor) { disposeDetailsPopover(); return; }
      detailsPopover = new tabler.Popover(anchor, {
        content: details, html: true, trigger: 'manual', animation: false, container: root,
        placement: 'right', fallbackPlacements: ['left', 'bottom', 'top'],
        customClass: 'od-tooth-popover shadow-lg' + (mode === 'add' && active && editable ? '' : ' od-inspect-popover'),
        template: '<div class="popover" role="dialog" aria-labelledby="' + heading.id + '"><div class="popover-arrow"></div><div class="popover-body"></div></div>',
        popperConfig: config => ({ ...config, strategy: 'fixed', modifiers: [...config.modifiers,
          { name: 'preventOverflow', options: { boundary: 'viewport', padding: 12 } }] })
      });
      detailsPopover.show();
      if (focus) details.querySelector('button').focus({ preventScroll: true });
    }
    let menuForTooth = false;
    function openMenu(forTooth = false) { if (!canChoose()) return; menuForTooth = forTooth; if (forTooth) disposeDetailsPopover(); else if (selected) closeDetails(false); $('[data-menu]').hidden = false; $('[data-tool]').setAttribute('aria-expanded', 'true'); $('[data-search]').value = ''; options(); $('[data-search]').focus(); }
    function closeMenu() { $('[data-menu]').hidden = true; $('[data-tool]').setAttribute('aria-expanded', 'false'); }
    function options() {
      const target = $('[data-options]'); target.replaceChildren();
      const inspect = button(copy.inspect, () => choose(''), 'dropdown-item fw-semibold'); inspect.prepend(inspectIcon.cloneNode(true)); target.append(inspect);
      const query = $('[data-search]').value.trim().toLocaleLowerCase(); let count = 0;
      const collator = new Intl.Collator(document.documentElement.lang || undefined, { sensitivity: 'base', numeric: true });
      const matches = presets.filter(preset => (preset.name + ' ' + copy.categories[preset.category]).toLocaleLowerCase().includes(query))
        .sort((a, b) => collator.compare(a.name, b.name));
      if (matches.length) {
        target.append(node('h6', 'dropdown-header', copy.custom_treatments));
        matches.forEach(preset => {
          const item = button('', () => choose(preset.category, preset), 'dropdown-item' + (activePreset && activePreset.id === preset.id ? ' active' : ''));
          const text = node('span'); text.append(node('span', 'd-block text-wrap', preset.name));
          if (preset.name.trim().toLocaleLowerCase() !== copy.categories[preset.category].toLocaleLowerCase()) text.append(node('small', 'd-block opacity-75', copy.categories[preset.category]));
          item.append(text); target.append(item); count++;
        });
      }
      const standardMatches = Object.entries(copy.categories).filter(([, name]) => name.toLocaleLowerCase().includes(query))
        .sort(([, a], [, b]) => collator.compare(a, b));
      if (presets.length && standardMatches.length) target.append(node('h6', 'dropdown-header', copy.standard_markings));
      standardMatches.forEach(([category, name]) => {
        count++;
        target.append(button(name, () => choose(category), 'dropdown-item' + (active === category && !activePreset ? ' active' : '')));
      });
      if (!count) target.append(node('p', 'text-muted small p-2', copy.no_matches));
    }
    function choose(category, preset = null) { const reconcile = !!pending || !ready; pending = null; active = category; activePreset = preset; closeMenu(); draftSurfaces.clear(); draftDate = ''; draftRotation = 'unspecified'; draftPosition = new Set(); draftPair = ''; draftExtent = 'arch'; draftMembers = new Set(selected ? [selected] : []); draftReplacement = new Set(); draftBridgeEnd = ''; draftBridgeRoles = {}; draftMobility = { grade: '', scale: '' }; formError = ''; if (menuForTooth && selected) mode = category ? 'add' : 'inspect'; else closeDetails(); render(); if (selected) showDetails(); else $('[data-tool]').focus(); if (reconcile) load(); }
    function add(tooth, surfaces, date = '') {
      if (!canWrite()) return;
      if (surfaceCategories.includes(active) && !optionalSurfaceCategories.includes(active) && !surfaces.length) { reportFormError(copy.choose_surface, tooth); return; }
      if (active === 'edentulous_arch') {
        const arch = archForTooth(tooth);
        if (archConflicts[arch].length) { reportFormError(copy.arch_conflict, tooth); return; }
        if (!window.confirm(copy.confirm_arch.replace('%{arch}', copy.arches[arch]))) return;
      }
      const entry = { tooth, category: active, surfaces: surfaceCategories.includes(active) ? surfaces : [], observed_on: date || null };
      if (treatmentCategories.includes(active)) entry.treatment_status = treatmentStatus;
      if (active === 'fixed_bridge') {
        const units = bridgeUnits(tooth);
        if (units.length < 2) { reportFormError(copy.bridge_choose_end, tooth); return; }
        if (units.some(unit => !unit.role)) { reportFormError(copy.bridge_choose_role, tooth); return; }
        const reason = units.map(unit => bridgeRoleReason(unit.tooth, unit.role)).find(Boolean);
        if (reason) { reportFormError(reason, tooth); return; }
        entry.bridge_units = units;
      }
      if (['complete_denture', 'partial_denture'].includes(active)) {
        const reason = dentureReason(tooth) || [...draftReplacement].map(replacementReason).find(Boolean);
        if (reason || !draftReplacement.size) { reportFormError(reason || copy.choose_replacement, tooth); return; }
        entry.arch = archForTooth(tooth);
        entry.replacement_teeth = toothArches.find(row => row.includes(tooth)).filter(number => draftReplacement.has(number));
      }
      if (active === 'edentulous_arch') entry.arch = archForTooth(tooth);
      if (groupCategories.includes(active)) {
        const row = toothArches.find(teeth => teeth.includes(tooth));
        entry.member_teeth = active === 'removable_orthodontic' ? extentTeeth(row, tooth, draftExtent) : row.filter(number => draftMembers.has(number));
      }
      if (pairedCategories.includes(active)) entry.paired_tooth = draftPair ? Number(draftPair) : null;
      if (active === 'abnormal_position') entry.position_directions = Array.from(draftPosition);
      if (active === 'rotation') entry.rotation_direction = draftRotation;
      if (active === 'mobility') Object.assign(entry, { mobility_grade: draftMobility.grade.trim() || null, mobility_scale: draftMobility.scale.trim() || null });
      if (activePreset) Object.assign(entry, { treatment_id: activePreset.id, treatment_version: activePreset.version,
        treatment_snapshot: { id: activePreset.id, name: activePreset.name } });
      const existing = entries.find(item => sameStage(item) && (groupCategories.includes(active) ? entryTeeth(item).some(number => entryTeeth(entry).includes(number)) : pairedCategories.includes(active) ? entryTeeth(item).includes(tooth) && entryTeeth(item).includes(entry.paired_tooth) : item.tooth === tooth) && item.category === active &&
        item.surfaces.slice().sort().join('') === entry.surfaces.slice().sort().join(''));
      if (existing) {
        reportFormError(groupCategories.includes(active) ? copy.appliance_overlap : copy.already_recorded.replace('%{marking}', label(existing)), tooth); return;
      }
      const { treatment_snapshot, ...attributes } = entry;
      save({ operation: 'add', odontogram_entry: attributes }, entry);
    }
    async function save(payload, entry, retainedBody) {
      if (busy || (!retainedBody && !canWrite())) return;
      const body = retainedBody || Object.assign({ request_id: uuid(), editor_id: editor, revision }, payload);
      formError = ''; busy = true; controls(); if (selected) showDetails(false); status(copy.saving, false);
      let response, result;
      try {
        response = await fetch(root.dataset.endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content }, body: JSON.stringify(body) });
        if (response.status >= 500) throw new Error('save');
        result = await response.json();
      } catch (_) {
        busy = false; pending = { payload, entry, body }; controls(); if (selected) showDetails(false); status(copy.failed); return;
      }
      busy = false; pending = null;
      if (!response.ok) {
        if (response.status === 403) { editable = false; undo = []; active = ''; activePreset = null; }
        if (response.status === 409) { ready = false; undo = []; $('[data-refresh]').hidden = false; }
        if (response.status === 403 || response.status === 409) { forgetEditorSession(); editor = uuid(); }
        controls();
        const message = result.error || (result.errors || []).join(' ') || copy.failed;
        if (response.status === 422) reportFormError(message, payload.operation === 'add' ? entry.tooth : selected || entry.tooth);
        else { if (selected) showDetails(false); status(message); }
        return;
      }
      entry = result.entries.find(saved => saved.id === result.id) || entry;
      draftSurfaces.clear(); draftDate = ''; draftRotation = 'unspecified'; draftPosition = new Set(); draftPair = ''; draftExtent = 'arch'; draftMembers = new Set(selected ? [selected] : []); draftReplacement = new Set(); draftBridgeEnd = ''; draftBridgeRoles = {}; draftMobility = { grade: '', scale: '' }; mode = 'inspect'; adopt(result);
      status(payload.operation === 'undo' ? copy.undone : (payload.operation === 'remove' ? copy.removed : copy.saved).replace('%{marking}', label(entry)));
      const targets = entryTeeth(entry).map(tooth => arches.querySelector('[data-tooth="' + tooth + '"]')).filter(Boolean);
      targets.forEach(tooth => { tooth.classList.add('od-saved'); setTimeout(() => tooth.classList.remove('od-saved'), 900); });
      if (selected) details.querySelector('button').focus(); else if (targets.length) targets[0].focus();
    }
    arches.addEventListener('click', event => {
      if (suppressClick || busy || pending) return;
      const b = event.target.closest('[data-tooth]'); if (!b) return;
      const tooth = Number(b.dataset.tooth);
      if (active && !['mobility', 'rotation', 'abnormal_position', 'edentulous_arch', 'complete_denture', 'partial_denture', 'fixed_bridge'].includes(active) && !pairedCategories.includes(active) && !groupCategories.includes(active) && editable && !surfaceCategories.includes(active) && !event.target.closest('.od-tooth-number')) { add(tooth, []); return; }
      selected = tooth; draftSurfaces.clear(); draftDate = ''; draftRotation = 'unspecified'; draftPosition = new Set(); draftPair = ''; draftExtent = 'arch'; draftMembers = new Set(selected ? [selected] : []); draftReplacement = new Set(); draftBridgeEnd = ''; draftBridgeRoles = {}; draftMobility = { grade: '', scale: '' }; formError = ''; mode = active && editable && !event.target.closest('.od-tooth-number') ? 'add' : 'inspect'; render(); showDetails();
    });
    arches.addEventListener('pointerdown', event => {
      const surface = event.target.closest('[data-part^="surface-"]'), b = event.target.closest('[data-tooth]');
      if (!surface || !b || !surfaceCategories.includes(active) || !canWrite() || event.button !== 0) return;
      event.preventDefault(); drag = { tooth: Number(b.dataset.tooth), surfaces: new Set([surface.dataset.part.slice(8)]) }; surface.setAttribute('data-preview', '');
    });
    document.addEventListener('pointermove', event => {
      if (!drag) return;
      const hit = document.elementFromPoint(event.clientX, event.clientY), surface = hit && hit.closest('[data-part^="surface-"]'), b = hit && hit.closest('[data-tooth]');
      if (surface && b && Number(b.dataset.tooth) === drag.tooth) { drag.surfaces.add(surface.dataset.part.slice(8)); surface.setAttribute('data-preview', ''); }
    });
    function clearDrag() { drag = null; root.querySelectorAll('[data-preview]').forEach(e => e.removeAttribute('data-preview')); }
    document.addEventListener('pointerup', () => { if (!drag) return; const current = drag; clearDrag(); suppressClick = true; setTimeout(() => { suppressClick = false; }, 0); add(current.tooth, Array.from(current.surfaces)); });
    document.addEventListener('pointercancel', clearDrag);
    $('[data-tool]').addEventListener('click', () => $('[data-menu]').hidden ? openMenu() : closeMenu());
    $('[data-treatment-status]').addEventListener('change', event => {
      if (!canChoose()) return;
      const reconcile = !!pending || !ready; pending = null;
      treatmentStatus = event.target.value;
      if (selected && active === 'fixed_orthodontic') draftMembers.add(selected);
      clearFormError(); render(); if (reconcile) load();
    });
    $('[data-search]').addEventListener('input', options);
    $('[data-dentition]').addEventListener('change', render);
    $('[data-retry]').addEventListener('click', () => { if (pending) save(pending.payload, pending.entry, pending.body); });
    $('[data-refresh]').addEventListener('click', () => { forgetEditorSession(); undo = []; editor = uuid(); closeDetails(); load(); });
    $('[data-undo]').addEventListener('click', () => {
      if (!canWrite() || !undo.length) return;
      const last = undo[undo.length - 1];
      if (last.operation === 'add' && !window.confirm(copy.confirm_remove.replace('%{marking}', label(last.entry)))) return;
      save({ operation: 'undo', change_id: last.id }, last.entry);
    });
    root.addEventListener('keydown', event => { if (event.key === 'Escape') { clearDrag(); closeMenu(); if (selected) closeDetails(); } });
    document.addEventListener('click', event => {
      const path = event.composedPath();
      if (!path.includes($('.od-tools'))) closeMenu();
      if (selected && !path.includes(details) && !path.includes(arches) && !path.includes($('.od-tools'))) closeDetails(false);
    });
    window.addEventListener('beforeunload', event => { if (busy || pending) { event.preventDefault(); event.returnValue = ''; } });
    window.addEventListener('pageshow', event => {
      if (!event.persisted || busy || pending) return;
      editor = editorSession(root)?.editor || uuid(); undo = []; editable = false; controls(); load();
    });
    desktop.addEventListener('change', () => { clearDrag(); closeMenu(); if (desktop.matches) { if (ready) { $('.od-desktop').hidden = false; render(); } else load(); } else { disposeDetailsPopover(); arches.replaceChildren(); $('.od-desktop').hidden = true; } });
    if (desktop.matches) load();
  }
  document.addEventListener('DOMContentLoaded', () => {
    prepareEditorSession(document.querySelector('[data-odontogram-session]'), window.performance?.getEntriesByType('navigation')[0]?.type);
    document.querySelectorAll('[data-odontogram]').forEach(start);
  });
  window.addEventListener('pageshow', event => {
    if (event.persisted) editorSession(document.querySelector('[data-odontogram-session]'));
  });
})();
