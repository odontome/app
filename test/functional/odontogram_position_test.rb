# frozen_string_literal: true

require 'test_helper'

class OdontogramPositionTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    @practice = practices(:complete)
    @practice.update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
  end

  teardown { I18n.locale = I18n.default_locale }

  def change(entry = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 16, category: 'abnormal_position', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'multiple directions survive correction undo and localized history' do
    change({ position_directions: %w[M V] })
    assert_response :created
    entry = @patient.odontogram_entries.sole
    addition = @patient.odontogram_changes.sole
    assert_equal %w[M V], response.parsed_body['entries'].sole['position_directions']
    change({ position_directions: ['D'] })
    assert_response :unprocessable_entity
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    change({ position_directions: ['D'] })
    assert_response :created
    corrected = @patient.odontogram_changes.recent.first
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show, params: { patient_id: @patient.id, tooth: 16 }, as: :html
      %w[M V].each do |direction|
        assert_select "[data-history-change='#{addition.id}']", text: /#{Regexp.escape(I18n.t("odontogram.editor.position_directions.#{direction}"))}/
      end
      get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
      assert_equal %w[M V], response.parsed_body['entries'].sole['position_directions']
      assert_equal ['D'], response.parsed_body['comparison']['added'].sole['position_directions']
    end
    change({}, operation: 'undo', change_id: corrected.id)
    assert_response :created
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal %w[M V], @patient.odontogram_entries.active.sole.position_directions
  end

  test 'unspecified is allowed but invalid conflicting and unrelated directions cannot save' do
    [{ position_directions: ['unknown'] }, { position_directions: %w[M M] },
     { position_directions: %w[M D] }, { position_directions: %w[V P] },
     { position_directions: ['L'] }, { tooth: 36, position_directions: ['P'] },
     { tooth: 36, position_directions: %w[V L] }, { surfaces: ['O'] },
     { category: 'crown', position_directions: ['M'] }].each do |attributes|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change(attributes)
        assert_response :unprocessable_entity
      end
    end
    change
    assert_response :created
    assert_equal [], response.parsed_body['entries'].sole['position_directions']
    change({ tooth: 36, position_directions: %w[D L] })
    assert_response :created
    assert_equal %w[D L], @patient.odontogram_entries.find_by!(tooth: 36).position_directions
  end
end
