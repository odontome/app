# frozen_string_literal: true
require 'test_helper'

class OdontogramDiastemaTest < ActionController::TestCase
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
      odontogram_entry: { tooth: 11, paired_tooth: 21, category: 'diastema', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'one shared record appears in both histories and survives snapshot removal and undo' do
    change
    assert_response :created
    entry = @patient.odontogram_entries.sole
    addition = @patient.odontogram_changes.sole
    assert_equal 21, response.parsed_body['entries'].sole['paired_tooth']
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      [11, 21].each do |tooth|
        get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
        assert_select "[data-history-change='#{addition.id}']", text: /11–21/
        assert_select "[data-odontogram-entry='#{entry.id}']", count: 1
      end
    end
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    assert_empty @patient.odontogram_entries.active
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal 21, response.parsed_body['entries'].sole['paired_tooth']
    assert_equal [11, 21], response.parsed_body['comparison']['teeth']
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 21, @patient.odontogram_entries.active.sole.paired_tooth
  end

  test 'reversed pairs deduplicate while a different neighboring gap remains independent' do
    change({ tooth: 21, paired_tooth: 11 })
    assert_response :created
    assert_equal [11, 21], @patient.odontogram_entries.sole.attributes.values_at('tooth', 'paired_tooth')
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change
      assert_response :unprocessable_entity
    end
    change({ tooth: 11, paired_tooth: 12 })
    assert_response :created
    assert_equal 2, @patient.odontogram_entries.active.count
  end

  test 'missing cross arch nonneighbor and unrelated pair targets cannot save' do
    [{ paired_tooth: nil }, { paired_tooth: 11 }, { paired_tooth: 31 }, { paired_tooth: 61 },
     { paired_tooth: 22 }, { paired_tooth: 99 }, { surfaces: ['M'] }, { category: 'crown' }].each do |attributes|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change(attributes)
        assert_response :unprocessable_entity
      end
    end
    %w[missing implant retained_root].each do |category|
      state = @patient.odontogram_entries.create!(tooth: 21, category: category, surfaces: [], recorded_by_name: 'Sample')
      change
      assert_response :unprocessable_entity
      state.update!(state: 'removed')
    end
    change
    assert_response :created
    %w[missing implant retained_root].each do |category|
      change({ tooth: 21, category: category, paired_tooth: nil })
      assert_response :unprocessable_entity
    end
  end
end
