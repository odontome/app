# frozen_string_literal: true

class OdontogramsController < ApplicationController
  class Conflict < StandardError; end

  before_action :require_user
  before_action :load_patient

  def show
    @entries = @patient.odontogram_entries.recent
    @read_only = !editable?
    return head :not_found if !current_user.practice.odontogram_enabled? && !@entries.exists?

    if request.format.json?
      raise ActionController::BadRequest if params[:tooth].present? || params[:through].present?
      # Read the revision and entries from one consistent chart state.
      @patient.with_lock { render json: params[:at].present? ? saved_chart_state : chart_state }
      return
    end

    if params[:at].present?
      @patient.with_lock do
        state = saved_chart_state
        @snapshot_entries = state.fetch(:entries).map { |attributes| OdontogramEntry.new(attributes) }
        @comparison = state.fetch(:comparison)
        @compared_at = Time.current
      end
      render :snapshot
      return
    end

    load_history

    return if @history_cutoff

    records = @entries
    @entries = records.limit(50)
    if params[:before].present?
      cursor = records.find(params[:before])
      @entries = @entries.where('(created_at, id) < (?, ?)', cursor.created_at, cursor.id)
    end
    @earlier_entries = @entries.last && records.where(
      '(created_at, id) < (?, ?)', @entries.last.created_at, @entries.last.id
    ).exists?
  rescue Date::Error, ActionController::BadRequest
    head :bad_request
  end

  def create
    current_user.practice.with_lock do
      return render(json: { error: I18n.t('odontogram.read_only') }, status: :forbidden) unless editable?

      validate_request!
      @patient.with_lock do
        payload = { operation: params[:operation] || 'add', entry_id: params[:entry_id],
                    change_id: params[:change_id], editor_id: params[:editor_id], entry: entry_params.to_h }
        digest = Digest::SHA256.hexdigest(payload.to_json)
        previous = @patient.odontogram_changes.find_by(request_id: params[:request_id])
        if previous
          raise Conflict unless previous.request_digest == digest && previous.recorded_by_id == current_user.id

          return render json: chart_state.merge(change_id: previous.id, id: previous.odontogram_entry_id)
        end
        raise Conflict unless params[:revision].to_i == @patient.odontogram_revision

        change = record_change(payload, digest)
        render json: chart_state.merge(change_id: change.id, id: change.odontogram_entry_id), status: :created
      end
    end
  rescue Conflict
    render json: { error: I18n.t('odontogram.editor.conflict') }, status: :conflict
  rescue ActionController::BadRequest
    head :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def saved_chart_state
    value = params[:at]
    raise ActionController::BadRequest unless value.is_a?(String) && /\A[1-9]\d*\z/.match?(value)

    @snapshot = @patient.odontogram_changes.find(value)
    entries = @snapshot.chart_entries
    { revision: @snapshot.revision, editable: false, presets: [], entries: entries,
      comparison: @snapshot.comparison_with_current(entries) }
  end

  def load_history
    changes = @patient.odontogram_changes
    @history_filters = {}
    if params[:tooth].present?
      value = params[:tooth]
      raise ActionController::BadRequest unless value.is_a?(String) && OdontogramEntry::TEETH.map(&:to_s).include?(value)

      @history_tooth = value.to_i
      @history_filters[:tooth] = @history_tooth
      changes = changes.where("after_state ->> 'tooth' = :tooth OR after_state ->> 'paired_tooth' = :tooth OR (after_state -> 'member_teeth') @> CAST(:members AS jsonb)", tooth: value, members: [@history_tooth].to_json)
      @entries = @entries.touching(@history_tooth)
    end
    if params[:through].present?
      value = params[:through]
      raise ActionController::BadRequest unless value.is_a?(String) && /\A[1-9]\d*\z/.match?(value)

      @history_cutoff = @patient.odontogram_changes.find(value)
      @history_filters[:through] = @history_cutoff.id
      changes = changes.where('revision <= ?', @history_cutoff.revision)
    end
    @history_groups = []
    if params[:history_day].present?
      @history_day = history_date(params[:history_day])
      changes = changes.recorded_on(@history_day)
      if params[:before_change].present?
        cursor = changes.find(params[:before_change])
        changes = changes.where('revision < ?', cursor.revision)
      end
      @history_changes = changes.recent.limit(51).to_a
      @earlier_changes = @history_changes.length > 50
      @history_changes = @history_changes.first(50)
    else
      before = history_date(params[:before_day]) if params[:before_day].present?
      days = changes.recorded_days(before: before)
      @earlier_days = days.length > 10
      @history_groups = days.first(10).map do |day, count|
        { day: day, count: count, changes: changes.recorded_on(day).recent.limit(5).to_a }
      end
    end
  end

  def history_date(value)
    raise ActionController::BadRequest unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)

    Date.iso8601(value)
  end

  def load_patient
    @patient = Patient.with_practice(current_user.practice_id).find(params[:patient_id])
  end

  def editable?
    current_user.practice.odontogram_enabled? && !impersonating? && params[:at].blank? && params[:through].blank?
  end

  def validate_request!
    uuid = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    valid = params[:request_id].is_a?(String) && uuid.match?(params[:request_id]) &&
            params[:editor_id].is_a?(String) && uuid.match?(params[:editor_id]) &&
            /\A\d+\z/.match?(params[:revision].to_s) &&
            %w[add remove undo complete].include?(params[:operation] || 'add')
    raise ActionController::BadRequest unless valid
  end

  def record_change(payload, digest)
    operation = payload[:operation]
    before_state = nil
    reversed = nil
    case operation
    when 'add'
      entry = @patient.odontogram_entries.build(entry_params.except(:treatment_id, :treatment_version))
      if entry_params[:treatment_id].present?
        treatment = current_user.practice.treatments.lock.find_by(id: entry_params[:treatment_id])
        raise Conflict unless treatment && treatment.odontogram_category.present? && treatment.odontogram_category == entry.category &&
          treatment.updated_at.utc.iso8601(6) == entry_params[:treatment_version]

        entry.treatment_snapshot = { id: treatment.id, name: treatment.name }
      end
      entry.recorded_by = current_user
      entry.recorded_by_name = current_user.fullname
      if OdontogramEntry::IMPLANT_SUPPORTED_CATEGORIES.include?(entry.category)
        entry.implant_entry = @patient.odontogram_entries.present_in_mouth.find_by(tooth: entry.tooth, category: 'implant')
      end
    when 'complete'
      entry = @patient.odontogram_entries.find(params[:entry_id])
      raise Conflict unless entry.state == 'active' && entry.planned? && OdontogramEntry::TREATMENT_CATEGORIES.include?(entry.category)

      before_state = entry.chart_attributes
      entry.treatment_status = 'completed'
      entry.completed_at = Time.current
      if OdontogramEntry::IMPLANT_SUPPORTED_CATEGORIES.include?(entry.category)
        entry.implant_entry = @patient.odontogram_entries.present_in_mouth.find_by(tooth: entry.tooth, category: 'implant')
      end
    when 'remove'
      entry = @patient.odontogram_entries.find(params[:entry_id])
      raise Conflict unless entry.state == 'active'

      before_state = entry.chart_attributes
      entry.state = 'removed'
    when 'undo'
      reversed = @patient.odontogram_changes.find(params[:change_id])
      available = undoable_changes(params[:editor_id])
      raise Conflict unless available.recent.first == reversed

      entry = @patient.odontogram_entries.find(reversed.odontogram_entry_id)
      raise Conflict unless entry.chart_attributes == reversed.after_state
      before_state = entry.chart_attributes
      if reversed.before_state
        entry.assign_attributes(reversed.before_state.slice('state', 'treatment_status', 'completed_at', 'implant_entry_id'))
      else
        entry.state = 'removed'
      end
    end
    entry.save!
    @patient.update!(odontogram_revision: @patient.odontogram_revision + 1)
    @patient.odontogram_changes.create!(odontogram_entry: entry, operation: operation,
      recorded_by: current_user, recorded_by_name: current_user.fullname,
      request_id: params[:request_id], editor_id: params[:editor_id], request_digest: digest,
      revision: @patient.odontogram_revision, reverses_id: reversed&.id,
      before_state: before_state, after_state: entry.chart_attributes)
  end

  def chart_state
    entries = @patient.odontogram_entries.active.order(:id).to_a
    { revision: @patient.odontogram_revision, editable: editable?,
      presets: editable? ? current_user.practice.treatments.for_odontogram.map(&:odontogram_preset) : [],
      entries: entries.map(&:chart_attributes),
      arch_conflicts: OdontogramEntry::ARCH_TEETH.keys.to_h { |arch| [arch, OdontogramEntry.edentulous_conflicts(entries, arch).map(&:id)] }, undo: undo_state }
  end

  def undo_state
    return [] unless editable? && params[:editor_id].present?

    editor_id = params[:editor_id]
    uuid = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    raise ActionController::BadRequest unless editor_id.is_a?(String) && uuid.match?(editor_id)

    undoable_changes(editor_id).order(:revision).map do |change|
      { id: change.id, operation: change.operation, entry: change.after_state }
    end
  end

  def undoable_changes(editor_id)
    changes = @patient.odontogram_changes.where.not(operation: 'undo')
      .where.not(id: @patient.odontogram_changes.where.not(reverses_id: nil).select(:reverses_id))
    own = changes.where(editor_id: editor_id, recorded_by_id: current_user.id)
    # Undo can step back through this session only until another editor's change.
    barrier = changes.where.not(id: own.select(:id)).maximum(:revision)
    barrier ? own.where('revision > ?', barrier) : own
  end

  def entry_params
    params.fetch(:odontogram_entry, ActionController::Parameters.new).permit(
      :category, :treatment_status, :tooth, :arch, :paired_tooth, :observed_on, :rotation_direction, :mobility_grade, :mobility_scale, :treatment_id, :treatment_version, surfaces: [], position_directions: [], member_teeth: [], replacement_teeth: [], bridge_units: [:tooth, :role, :implant_entry_id])
  end
end
