# frozen_string_literal: true

require 'test_helper'

class OdontogramChangesTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
  end

  def change(attributes = {})
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid,
      editor_id: @editor, revision: @patient.reload.odontogram_revision,
      operation: 'add', odontogram_entry: { tooth: 16, category: 'caries', surfaces: %w[M O] }
    }.merge(attributes), as: :json
  end

  test 'chart changes use odontogram history without duplicate patient audit events' do
    previous_enabled = PaperTrail.enabled?
    PaperTrail.enabled = true

    assert_no_difference 'PaperTrail::Version.count' do
      change(odontogram_entry: { tooth: 16, category: 'crown', surfaces: [], treatment_status: 'planned' })
      assert_response :created
      entry = @patient.odontogram_entries.sole
      addition = @patient.odontogram_changes.sole
      change(operation: 'complete', entry_id: entry.id)
      assert_response :created
      completion = @patient.odontogram_changes.recent.first
      change(operation: 'undo', change_id: completion.id)
      assert_response :created
      change(operation: 'remove', entry_id: entry.id)
      assert_response :created
      change(operation: 'undo', change_id: @patient.odontogram_changes.recent.first.id)
      assert_response :created
      assert_equal 'planned', entry.reload.treatment_status
      assert_equal 'active', entry.state
      assert_equal 5, @patient.reload.odontogram_revision
      assert_equal 5, @patient.odontogram_changes.count
      assert_equal users(:founder).fullname, completion.recorded_by_name
      assert_equal 'planned', addition.chart_entries.sole['treatment_status']
      assert_equal 'completed', completion.chart_entries.sole['treatment_status']
    end
  ensure
    PaperTrail.enabled = previous_enabled
  end

  test 'patient profile edits retain their audit without the internal chart revision' do
    previous_enabled = PaperTrail.enabled?
    PaperTrail.enabled = true
    old_name = @patient.firstname

    PaperTrail.request(enabled: true) do
      assert_difference -> { @patient.versions.count }, 1 do
        @patient.update!(firstname: 'Updated', odontogram_revision: 1)
      end
      version = @patient.versions.last
      assert_equal [old_name, 'Updated'], version.changeset['firstname']
      assert_not_includes version.changeset.keys, 'odontogram_revision'
      assert_not_includes PaperTrail.serializer.load(version.object).keys, 'odontogram_revision'
    end
  ensure
    PaperTrail.enabled = previous_enabled
  end

  test 'add retry remove and undo retain an exact change trail' do
    request_id = SecureRandom.uuid
    change(request_id: request_id)
    assert_response :created
    entry = @patient.odontogram_entries.sole
    assert_equal %w[M O], entry.surfaces
    assert_equal 1, @patient.reload.odontogram_revision
    assert_equal users(:founder).fullname, @patient.odontogram_changes.sole.recorded_by_name

    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change(request_id: request_id, revision: 0)
    end
    assert_response :success

    change(operation: 'remove', entry_id: entry.id)
    assert_response :created
    assert_equal 'removed', entry.reload.state
    removal = @patient.odontogram_changes.order(:id).last
    assert_equal 'active', removal.before_state['state']
    assert_equal 'removed', removal.after_state['state']

    change(operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'active', entry.reload.state
    assert_equal 3, @patient.odontogram_changes.count
    assert_equal 3, @patient.reload.odontogram_revision
  end

  test 'stale writes and changed retry payloads cannot modify the chart' do
    request_id = SecureRandom.uuid
    change(request_id: request_id)
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change(revision: 0)
      assert_response :conflict
      change(request_id: request_id, revision: 0, odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
      assert_response :conflict
    end
  end

  test 'failed validation leaves no entry change or revision increment' do
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change(odontogram_entry: { tooth: 16, category: 'caries', surfaces: ['I'] })
    end
    assert_response :unprocessable_entity
    assert_equal 0, @patient.reload.odontogram_revision
  end

  test 'repeated crown clicks do not create another current crown or change' do
    attributes = { tooth: 11, category: 'crown', surfaces: [] }
    change(odontogram_entry: attributes)
    assert_response :created
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      3.times do
        change(odontogram_entry: attributes)
        assert_response :unprocessable_entity
      end
    end
    assert_equal 1, @patient.reload.odontogram_revision
  end

  test 'one veneer per tooth rejects repeat taps and supports removal and undo' do
    attributes = { tooth: 11, category: 'veneer', surfaces: [] }
    change(odontogram_entry: attributes)
    assert_response :created
    entry = @patient.odontogram_entries.sole
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change(odontogram_entry: attributes)
      assert_response :unprocessable_entity
      change(odontogram_entry: attributes.merge(surfaces: %w[F D]))
      assert_response :unprocessable_entity
    end
    assert_equal [], entry.reload.surfaces
    change(operation: 'remove', entry_id: entry.id)
    assert_response :created
    assert_equal 'removed', entry.reload.state
    change(operation: 'undo', change_id: @patient.odontogram_changes.recent.first.id)
    assert_response :created
    assert_equal 'active', entry.reload.state
    assert_equal [], entry.surfaces
    assert_equal [], @patient.odontogram_changes.recent.first.after_state['surfaces']
  end

  test 'surface order does not turn an identical marking into another entry' do
    change
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change(odontogram_entry: { tooth: 16, category: 'caries', surfaces: %w[O M] })
    end
    assert_response :unprocessable_entity
  end

  test 'different markings and surface selections can coexist' do
    change
    change(odontogram_entry: { tooth: 16, category: 'filling', surfaces: %w[M O] })
    assert_response :created
    change(odontogram_entry: { tooth: 16, category: 'filling', surfaces: ['B'] })
    assert_response :created
    change(odontogram_entry: { tooth: 16, category: 'crown', surfaces: [] })
    assert_response :created
    change(odontogram_entry: { tooth: 16, category: 'rct', surfaces: [] })
    assert_response :created
    assert_equal 5, @patient.odontogram_entries.active.count
  end

  test 'temporary and definitive work coexist until an explicit correction with retained history' do
    %w[temporary_crown crown pulpotomy].each do |category|
      change(odontogram_entry: { tooth: 16, category: category, surfaces: [] })
      assert_response :created
    end
    %w[temporary_filling filling wear caries].each do |category|
      change(odontogram_entry: { tooth: 16, category: category, surfaces: ['O'] })
      assert_response :created
    end
    assert_equal 7, @patient.odontogram_entries.active.count
    temporary = @patient.odontogram_entries.find_by!(category: 'temporary_filling')
    change(operation: 'remove', entry_id: temporary.id)
    assert_response :created
    assert_equal 6, @patient.odontogram_entries.active.count
    change(operation: 'undo', change_id: @patient.odontogram_changes.recent.first.id)
    assert_response :created
    assert_equal 'active', temporary.reload.state
    assert_equal 7, @patient.odontogram_entries.active.count
    assert_equal 9, @patient.odontogram_changes.count
  end

  test 'a corrected marking can be recorded again without deleting its history' do
    change
    original = @patient.odontogram_entries.sole
    change(operation: 'remove', entry_id: original.id)
    change
    assert_response :created
    assert_equal 'removed', original.reload.state
    assert_equal 2, @patient.odontogram_entries.count
    assert_equal 1, @patient.odontogram_entries.active.count
  end

  test 'facial restorations core and findings preserve their distinct records and history' do
    [ ['veneer', []], ['core', []], ['enamel_defect', []], ['deep_fissures', ['I']] ].each do |category, surfaces|
      change(odontogram_entry: { tooth: 11, category: category, surfaces: surfaces })
      assert_response :created
    end
    assert_equal %w[veneer core enamel_defect deep_fissures], @patient.odontogram_entries.order(:id).pluck(:category)
    assert_equal [], @patient.odontogram_entries.find_by!(category: 'enamel_defect').surfaces
    original = @patient.odontogram_changes.recent.first
    change(operation: 'undo', change_id: original.id)
    assert_response :created
    assert_equal 'removed', original.odontogram_entry.reload.state
    assert_equal 5, @patient.odontogram_changes.count
  end

  test 'removals are scoped and undo belongs to its author and editor session' do
    other = patients(:three).odontogram_entries.create!(tooth: 11, category: 'crown', surfaces: [], recorded_by_name: 'Other')
    assert_raises ActiveRecord::RecordNotFound do
      change(operation: 'remove', entry_id: other.id)
    end
    change
    addition = @patient.odontogram_changes.sole
    change(operation: 'undo', change_id: addition.id, editor_id: SecureRandom.uuid)
    assert_response :conflict
    @controller.session['user'] = users(:superadmin)
    change(operation: 'undo', change_id: addition.id)
    assert_response :conflict
    assert_equal 'active', @patient.odontogram_entries.sole.state
  end

  test 'JSON chart includes all current entries and disabled eligibility' do
    change
    practices(:complete).update!(odontogram_enabled: false)
    get :show, params: { patient_id: @patient.id }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal false, body['editable']
    assert_equal 1, body['revision']
    assert_equal %w[M O], body['entries'].sole['surfaces']
  end

  test 'missing request identity and malformed revision are rejected' do
    change(request_id: nil)
    assert_response :bad_request
    change(revision: 'wrong')
    assert_response :bad_request
    assert_equal 0, @patient.odontogram_entries.count
  end

  test 'session undo steps back while retaining each original change' do
    change
    first = @patient.odontogram_changes.sole
    change(odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
    second = @patient.odontogram_changes.recent.first
    change(operation: 'undo', change_id: second.id)
    assert_response :created
    change(operation: 'undo', change_id: first.id)
    assert_response :created
    assert_equal 0, @patient.odontogram_entries.active.count
    assert_equal 4, @patient.odontogram_changes.count
  end

  test 'returning from history recovers only this authors current editor undo stack' do
    change
    first = @patient.odontogram_changes.sole
    change(odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
    second = @patient.odontogram_changes.recent.first
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_response :success
    get :show, params: { patient_id: @patient.id, editor_id: @editor }, as: :json
    assert_response :success
    assert_equal [first.id, second.id], response.parsed_body.fetch('undo').pluck('id')
    assert_equal second.after_state, response.parsed_body.fetch('undo').last.fetch('entry')
    change(operation: 'undo', change_id: second.id)
    assert_response :created
    assert_equal [first.id], response.parsed_body.fetch('undo').pluck('id')

    get :show, params: { patient_id: @patient.id, editor_id: SecureRandom.uuid }, as: :json
    assert_equal [], response.parsed_body.fetch('undo')
    @controller.session['user'] = users(:superadmin)
    get :show, params: { patient_id: @patient.id, editor_id: @editor }, as: :json
    assert_equal [], response.parsed_body.fetch('undo')
  end

  test 'resumed undo stops at another editors intervening change' do
    change
    other_editor = SecureRandom.uuid
    change(editor_id: other_editor, odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
    change(odontogram_entry: { tooth: 12, category: 'crown', surfaces: [] })
    last = @patient.odontogram_changes.recent.first
    get :show, params: { patient_id: @patient.id, editor_id: @editor }, as: :json
    assert_equal [last.id], response.parsed_body.fetch('undo').pluck('id')
    change(operation: 'undo', change_id: last.id)
    assert_response :created
    assert_equal [], response.parsed_body.fetch('undo')
    practices(:complete).update!(odontogram_enabled: false)
    get :show, params: { patient_id: @patient.id, editor_id: other_editor }, as: :json
    assert_equal [], response.parsed_body.fetch('undo')
  end

  test 'malformed editor identities cannot be used to recover undo' do
    ['invalid', ['invalid']].each do |editor_id|
      get :show, params: { patient_id: @patient.id, editor_id: editor_id }, as: :json
      assert_response :bad_request
    end
  end

  test 'a later change from another editor blocks an unsafe undo' do
    change
    first = @patient.odontogram_changes.sole
    change(editor_id: SecureRandom.uuid, odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
    change(operation: 'undo', change_id: first.id)
    assert_response :conflict
    assert_equal 2, @patient.odontogram_entries.active.count
  end

  test 'structural changes never silently replace existing markings' do
    change
    change(odontogram_entry: { tooth: 16, category: 'missing', surfaces: [] })
    assert_response :unprocessable_entity
    assert_equal ['caries'], @patient.odontogram_entries.active.pluck(:category)
  end

  test 'missing implant and its crowns coexist with explicit support and reversible history' do
    %w[missing implant crown temporary_crown].each do |category|
      change(odontogram_entry: { tooth: 16, category: category, surfaces: [] })
      assert_response :created, category
    end
    implant = @patient.odontogram_entries.find_by!(category: 'implant')
    crowns = @patient.odontogram_entries.where(category: %w[crown temporary_crown]).order(:id)
    crowns.each do |crown|
      assert_equal implant.id, crown.implant_entry_id
      assert_equal implant.id, crown.odontogram_changes.sole.after_state['implant_entry_id']
    end
    revision = @patient.reload.odontogram_revision
    assert_no_difference 'OdontogramChange.count' do
      change(operation: 'remove', entry_id: implant.id)
      assert_response :unprocessable_entity
    end
    assert_equal revision, @patient.reload.odontogram_revision
    assert_equal 'active', implant.reload.state

    crowns.each do |crown|
      change(operation: 'remove', entry_id: crown.id)
      assert_response :created
    end
    crown_removal = @patient.odontogram_changes.recent.first
    change(operation: 'remove', entry_id: implant.id)
    assert_response :created
    implant_removal = @patient.odontogram_changes.recent.first
    change(operation: 'undo', change_id: implant_removal.id)
    assert_response :created
    change(operation: 'undo', change_id: crown_removal.id)
    assert_response :created
    assert_equal implant.id, crowns.find_by!(category: 'temporary_crown').reload.implant_entry_id
    assert_equal %w[implant missing temporary_crown], @patient.odontogram_entries.active.pluck(:category).sort
    get :show, params: { patient_id: @patient.id }, as: :json
    assert_equal implant.id, response.parsed_body['entries'].find { |e| e['category'] == 'temporary_crown' }['implant_entry_id']
  end

  test 'a retained root preserves missing status and reverses through recorded history' do
    change(odontogram_entry: { tooth: 16, category: 'missing', surfaces: [] })
    assert_response :created
    change(odontogram_entry: { tooth: 16, category: 'retained_root', surfaces: [] })
    assert_response :created
    root = @patient.odontogram_entries.find_by!(category: 'retained_root')
    addition = @patient.odontogram_changes.recent.first
    change(operation: 'remove', entry_id: root.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    assert_equal ['missing'], @patient.odontogram_entries.active.pluck(:category)
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal %w[missing retained_root], response.parsed_body['entries'].map { |entry| entry['category'] }.sort
    change(operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal %w[missing retained_root], @patient.odontogram_entries.active.pluck(:category).sort
  end

  test 'an implant accepts a crown without needing a separate missing entry' do
    change(odontogram_entry: { tooth: 16, category: 'implant', surfaces: [] })
    assert_response :created
    implant = @patient.odontogram_entries.sole
    request_id = SecureRandom.uuid
    attributes = { tooth: 16, category: 'crown', surfaces: [] }
    change(request_id: request_id, odontogram_entry: attributes)
    assert_response :created
    crown = @patient.odontogram_entries.find_by!(category: 'crown')
    assert_equal implant.id, crown.implant_entry_id
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change(request_id: request_id, revision: 1, odontogram_entry: attributes)
      assert_response :success
      change(odontogram_entry: attributes)
      assert_response :unprocessable_entity
    end
  end

  test 'structural changes reject incompatible entries in both directions without losing history' do
    %w[missing implant].each_with_index do |structural, index|
      tooth = 16 + index
      change(odontogram_entry: { tooth: tooth, category: structural, surfaces: [] })
      assert_response :created
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change(odontogram_entry: { tooth: tooth, category: 'rct', surfaces: [] })
        assert_response :unprocessable_entity
        change(odontogram_entry: { tooth: tooth, category: 'caries', surfaces: ['O'] })
        assert_response :unprocessable_entity
      end
    end
    change(odontogram_entry: { tooth: 16, category: 'crown', surfaces: [] })
    assert_response :unprocessable_entity
    change(odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
    assert_response :created
    crown = @patient.odontogram_entries.find_by!(tooth: 11)
    %w[missing implant].each do |category|
      change(odontogram_entry: { tooth: 11, category: category, surfaces: [] })
      assert_response :unprocessable_entity
    end
    assert_equal 'active', crown.reload.state
    change(operation: 'remove', entry_id: crown.id)
    assert_response :created
    change(odontogram_entry: { tooth: 11, category: 'missing', surfaces: [] })
    assert_response :created
    assert_equal 'removed', crown.reload.state
    assert_equal 2, crown.odontogram_changes.count
  end

  test 'a failure writing the change rolls back the entry and revision' do
    record_change = @controller.method(:record_change)
    failure = lambda do |*args|
      record_change.call(*args)
      raise ActiveRecord::RecordInvalid, OdontogramChange.new
    end
    @controller.stub(:record_change, failure) do
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change
      end
    end
    assert_response :unprocessable_entity
    assert_equal 0, @patient.reload.odontogram_revision
  end
end
