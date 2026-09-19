# frozen_string_literal: true

module OdontogramsHelper
  def odontogram_icon(name, css: 'icon')
    path = {
      add: 'M12 5v14M5 12h14',
      complete: 'M5 12l4 4L19 6',
      remove: 'M4 7h16M10 11v6M14 11v6M5 7l1 13h12l1 -13M9 7V4h6v3',
      undo: 'M9 14L4 9l5 -5M4 9h10a6 6 0 0 1 0 12h-2',
      history: 'M12 8v4l2 2M3.05 11a9 9 0 1 1 .5 4M3.55 20v-5h5',
      back: 'M5 12h14M5 12l6 6M5 12l6 -6',
      chart: 'M12 5c-2 -2 -7 -2 -8 2c-1 4 1 7 2 11c1 4 3 4 4 -1c1 -4 3 -4 4 0c1 5 3 5 4 1c1 -4 3 -7 2 -11c-1 -4 -6 -4 -8 -2z',
      chevron: 'M9 6l6 6l-6 6',
      records: 'M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01'
    }.fetch(name.to_sym)
    tag.svg(class: css, width: 24, height: 24, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
      'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': true, focusable: false) do
      tag.path(d: path)
    end
  end

  def report_treatment_name(entry)
    entry.treatment_snapshot['name'].presence || t("odontogram.categories.#{entry.category}")
  end

  def report_treatment_target(entry)
    target = entry.target_name
    if entry.replacement_teeth.present?
      target += " · #{t('odontogram.editor.replacement_positions', teeth: entry.replacement_teeth.join(', '))}"
    end
    target += " · #{entry.surfaces.join('')}" if entry.surfaces.present?
    target
  end
end
