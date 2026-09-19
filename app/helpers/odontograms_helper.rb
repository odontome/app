# frozen_string_literal: true

module OdontogramsHelper
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
