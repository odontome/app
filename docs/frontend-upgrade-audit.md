# Tabler and FullCalendar upgrade audit

This audit accompanies the move to Tabler 1.4.0 and its FullCalendar 6.1.18
integration.

## Removed or migrated in this upgrade

- Removed the vendored Tabler beta CSS and JavaScript in favor of the pinned
  `@tabler/core` package.
- Removed FullCalendar 1.6.4, its legacy stylesheet, and the jQuery touch-drag
  shim. FullCalendar 6 supplies pointer/touch interaction itself.
- Removed the custom body-class dark-mode implementation and its palette
  overrides. Tabler's `tabler-theme` script now owns `data-bs-theme`, storage,
  and the light/dark controls.
- Retained DOM-ready tooltip/popover initialization using Tabler's idempotent
  APIs. Its automatic initialization runs too early with our head-loaded bundle.
- Load Tabler's official neutral palette stylesheet and select it in `theme.js`,
  alongside the upstream theme switcher. No custom dark palette is needed.
- Preserve the previous page gutters and 35px calendar slots, and explicitly
  constrain empty-state illustrations to 128px high. These dimensions no longer
  come from the new vendor defaults.
- Normalize missing appointment notes to empty event titles for FullCalendar 6.
- Replaced classes removed by current Tabler: `font-weight-medium`,
  `alert-title`, the old timeline component, and `navbar-light`.
- Replaced obsolete Bootstrap tooltip data attributes and the dead
  `form-group` class.
- Removed the datebook controller's user-agent regex. The calendar now chooses
  its compact layout from the actual viewport.
- Removed invalid nested headings and nested links encountered in the affected
  Tabler components.

## Retained intentionally

- `app/assets/stylesheets/calendar.css` is still needed for the FullCalendar
  theme-token bridge, readable slot height, and waiting-room indicator. It no
  longer contains a separate light or dark palette.
- jQuery UI remains because `jquery-autosuggest.js` still uses its autocomplete
  widget for patient selection. FullCalendar no longer depends on it.
- `jstz.min.js` remains because the practice form uses it to detect a timezone.
- ApexCharts, Masonry, and Tom Select each still have active call sites.

## Safe follow-up candidate

The next removable bundle is jQuery UI. Replace the patient autocomplete in
`jquery-autosuggest.js` with the already-loaded Tom Select (or a small native
combobox), verify keyboard and screen-reader behavior, then remove
`jquery-ui.min.js` and its associated image assets. This is a separate behavior
change and was not folded into the library upgrade.

`text-muted` remains a supported Tabler 1.4.0 utility and does not need a bulk
rewrite.

## Regression verification

- Full Rails suite: 658 tests, 4,287 assertions, no failures or errors.
- JavaScript suite: 10 tests pass, including DOM-ready help initialization and
  the upstream light/dark preference combined with the neutral palette.
- Browser checks at 1280px and 380px: page gutters are 24px and 16px,
  respectively; empty illustrations are 128px high; calendar half-hour slots
  are 35px; no horizontal page overflow. Dark mode resolves to the official
  neutral background (#171717), and light mode restores correctly.
- Status help opens its popover in the signed-in datebook list.
- Model tests cover nil, empty, and populated notes in both calendar JSON modes.
  The browser calendar used for these layout checks had no appointments, so
  populated event interaction was not reverified in this correction pass.
