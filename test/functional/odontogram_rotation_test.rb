# frozen_string_literal: true

require 'test_helper'

class OdontogramRotationTest < ActionController::TestCase
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
      odontogram_entry: { tooth: 16, category: 'rotation', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'recorded direction survives correction undo and saved history in each locale' do
    change({ rotation_direction: 'clockwise' })
    assert_response :created
    entry = @patient.odontogram_entries.sole
    addition = @patient.odontogram_changes.sole
    assert_equal 'clockwise', entry.rotation_direction
    change({ rotation_direction: 'counterclockwise' })
    assert_response :unprocessable_entity
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    change({ rotation_direction: 'counterclockwise' })
    assert_response :created
    corrected = @patient.odontogram_changes.recent.first
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show, params: { patient_id: @patient.id, tooth: 16 }, as: :html
      assert_select "[data-history-change='#{addition.id}']", text: /#{Regexp.escape(I18n.t('odontogram.editor.rotation_directions.clockwise'))}/
      get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
      assert_equal 'clockwise', response.parsed_body['entries'].sole['rotation_direction']
      assert_equal 'counterclockwise', response.parsed_body['comparison']['added'].sole['rotation_direction']
    end
    change({}, operation: 'undo', change_id: corrected.id)
    assert_response :created
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'clockwise', @patient.odontogram_entries.active.sole.rotation_direction
  end

  test 'unspecified direction is explicit and invalid or unrelated directions do not save' do
    [{ rotation_direction: 'left' }, { rotation_direction: '' }, { surfaces: ['O'] },
     { category: 'crown', rotation_direction: 'clockwise' }].each do |attributes|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change(attributes)
        assert_response :unprocessable_entity
      end
    end
    change
    assert_response :created
    assert_equal 'unspecified', response.parsed_body['entries'].sole['rotation_direction']
  end
end
