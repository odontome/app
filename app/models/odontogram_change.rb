# frozen_string_literal: true

class OdontogramChange < ApplicationRecord
  belongs_to :patient
  belongs_to :odontogram_entry
  belongs_to :recorded_by, class_name: 'User', optional: true

  validates :operation, inclusion: { in: %w[add remove undo complete] }
  validates :recorded_by_name, :request_id, :editor_id, :request_digest, :revision, presence: true

  scope :recent, -> { order(revision: :desc) }
  scope :recorded_on, ->(day) { where(created_at: day.in_time_zone...day.next_day.in_time_zone) }

  def self.recorded_days(before: nil)
    local_day = Arel.sql("(created_at AT TIME ZONE 'UTC' AT TIME ZONE #{connection.quote(Time.zone.tzinfo.name)})::date")
    changes = before ? where('created_at < ?', before.in_time_zone) : all
    changes.group(local_day).order(local_day.desc).limit(11).count
  end

  def saved_entry
    @saved_entry ||= OdontogramEntry.new(after_state.slice('treatment_status', 'completed_at', 'bridge_units', 'replacement_teeth', 'arch', 'member_teeth', 'paired_tooth', 'tooth', 'category', 'surfaces', 'observed_on', 'treatment_snapshot', 'implant_entry_id', 'mobility_grade', 'mobility_scale', 'rotation_direction', 'position_directions'))
  end

  def chart_entries
    states = patient.odontogram_entries.to_h { |entry| [entry.id, entry.chart_attributes] }
    patient.odontogram_changes.where('revision > ?', revision).recent.pluck(:odontogram_entry_id, :before_state).each do |entry_id, before|
      before ? states[entry_id] = before : states.delete(entry_id)
    end
    states.values.select do |entry|
      entry.fetch('state') == 'active' && Time.iso8601(entry.fetch('created_at')) <= created_at
    end.sort_by { |entry| entry.fetch('id') }
  end

  def comparison_with_current(past_entries)
    past = past_entries.index_by { |entry| entry.fetch('id') }
    current = patient.odontogram_entries.active.map(&:chart_attributes).index_by { |entry| entry.fetch('id') }
    added = (current.keys - past.keys).map { |id| current.fetch(id) }
    removed = (past.keys - current.keys).map { |id| past.fetch(id) }
    fields = %w[treatment_status completed_at bridge_units replacement_teeth arch member_teeth paired_tooth tooth category surfaces observed_on treatment_snapshot implant_entry_id mobility_grade mobility_scale rotation_direction position_directions]
    updated = (past.keys & current.keys).filter_map do |id|
      { 'before' => past.fetch(id), 'after' => current.fetch(id) } unless past.fetch(id).slice(*fields) == current.fetch(id).slice(*fields)
    end
    teeth = (added + removed + updated.flat_map(&:values)).flat_map { |entry| entry['member_teeth'].presence || [entry.fetch('tooth'), entry['paired_tooth']] }.compact.uniq.sort
    { 'added' => added, 'removed' => removed, 'updated' => updated, 'teeth' => teeth }
  end

  def action_label
    if operation == 'complete'
      I18n.t('odontogram.editor.completed_action')
    elsif operation == 'undo' && before_state['treatment_status'] == 'completed' && after_state['treatment_status'] == 'planned'
      I18n.t('odontogram.editor.completion_undone')
    elsif operation == 'undo'
      I18n.t("odontogram.history.undo_#{after_state.fetch('state') == 'active' ? 'restored' : 'removed'}")
    else
      I18n.t("odontogram.editor.#{operation == 'add' ? 'added_action' : 'removed_action'}")
    end
  end
end
