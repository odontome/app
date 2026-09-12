# frozen_string_literal: true

require 'test_helper'

class OdontogramSnapshotsTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    @practice = practices(:complete)
    @practice.update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  def change(**attributes)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 16, category: 'caries', surfaces: ['O'] } }.merge(attributes), as: :json
    assert_response :created
    @patient.odontogram_changes.recent.first
  end

  test 'a saved chart excludes later backdated entries and compares against current markings' do
    earlier = change
    later = change(odontogram_entry: { tooth: 11, category: 'crown', surfaces: [], observed_on: Date.current - 10.years })
    get :show, params: { patient_id: @patient.id, at: earlier.id }, as: :json
    assert_response :success
    result = response.parsed_body
    assert_equal false, result['editable']
    assert_equal [], result['presets']
    assert_equal earlier.revision, result['revision']
    assert_equal [earlier.odontogram_entry_id], result['entries'].pluck('id')
    assert_equal [later.odontogram_entry_id], result['comparison']['added'].pluck('id')
    assert_equal [], result['comparison']['removed']
    assert_equal [11], result['comparison']['teeth']
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_select "a[href='#{patient_odontogram_path(@patient, at: later.id)}']"
    assert_select "a[href='#{patient_odontogram_path(@patient, at: earlier.id)}']"
  end

  test 'removal and undo reconstruct exact states without a lasting difference' do
    added = change
    removal = change(operation: 'remove', entry_id: added.odontogram_entry_id)
    change(operation: 'undo', change_id: removal.id)
    get :show, params: { patient_id: @patient.id, at: added.id }, as: :json
    assert_equal [added.after_state], response.parsed_body['entries']
    assert_equal({ 'added' => [], 'removed' => [], 'updated' => [], 'teeth' => [] }, response.parsed_body['comparison'])
    get :show, params: { patient_id: @patient.id, at: removal.id }, as: :json
    assert_equal [], response.parsed_body['entries']
    assert_equal [added.odontogram_entry_id], response.parsed_body['comparison']['added'].pluck('id')
  end

  test 'implant crown support and original labels survive historical reconstruction' do
    implant = change(odontogram_entry: { tooth: 16, category: 'implant', surfaces: [] })
    crown = change(odontogram_entry: { tooth: 16, category: 'crown', surfaces: [] })
    change(operation: 'remove', entry_id: crown.odontogram_entry_id)
    change(operation: 'remove', entry_id: implant.odontogram_entry_id)
    get :show, params: { patient_id: @patient.id, at: crown.id }, as: :json
    assert_equal [implant.odontogram_entry_id, crown.odontogram_entry_id], response.parsed_body['entries'].pluck('id')
    assert_equal implant.odontogram_entry_id, response.parsed_body['entries'].last['implant_entry_id']
    assert_equal 2, response.parsed_body['comparison']['removed'].length
  end

  test 'preexisting records retain their earlier state without including later untracked records' do
    baseline = @patient.odontogram_entries.create!(tooth: 11, category: 'crown', surfaces: [], recorded_by_name: 'Original')
    earlier = change
    change(operation: 'remove', entry_id: baseline.id)
    @patient.odontogram_entries.create!(tooth: 12, category: 'crown', surfaces: [], recorded_by_name: 'Later')
    get :show, params: { patient_id: @patient.id, at: earlier.id }, as: :json
    assert_equal [baseline.id, earlier.odontogram_entry_id], response.parsed_body['entries'].pluck('id')
  end

  test 'historical pages and phone summaries are dated read only and use the selected state' do
    earlier = change
    change(odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] })
    @practice.update!(odontogram_enabled: false)
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show, params: { patient_id: @patient.id, at: earlier.id }, as: :html
      assert_response :success
      assert_select '[data-saved-chart] time'
      assert_select "[data-snapshot-id='#{earlier.id}']"
      assert_select '[data-odontogram-summary]', text: /16/
      assert_select '[data-odontogram-summary]', text: /11/, count: 0
      assert_select '[data-comparison] [data-added]', count: 1
      assert_select '.translation_missing', count: 0
    end
  end

  test 'historical URLs reject writes even when their revision is current' do
    earlier = change
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      post :create, params: { patient_id: @patient.id, at: earlier.id, request_id: SecureRandom.uuid,
        editor_id: @editor, revision: earlier.revision, operation: 'add',
        odontogram_entry: { tooth: 11, category: 'crown', surfaces: [] } }, as: :json
      assert_response :forbidden
    end
  end

  test 'snapshot identity is scoped to the patient and malformed identities are rejected' do
    earlier = change
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: patients(:three).id, at: earlier.id }, as: :json
    end
    ['invalid', "#{earlier.id}junk", ['1']].each do |value|
      get :show, params: { patient_id: @patient.id, at: value }, as: :json
      assert_response :bad_request
    end
  end
  test 'correcting a tooth size observation preserves both saved states and localized history' do
    large = change(odontogram_entry: { tooth: 22, category: 'macrodontia', surfaces: [] })
    removal = change(operation: 'remove', entry_id: large.odontogram_entry_id)
    small = change(odontogram_entry: { tooth: 22, category: 'microdontia', surfaces: [], observed_on: Date.yesterday })
    get :show, params: { patient_id: @patient.id, at: large.id }, as: :json
    assert_equal ['macrodontia'], response.parsed_body['entries'].pluck('category')
    assert_equal ['microdontia'], response.parsed_body['comparison']['added'].pluck('category')
    assert_equal ['macrodontia'], response.parsed_body['comparison']['removed'].pluck('category')
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show, params: { patient_id: @patient.id, tooth: 22, through: small.id }, as: :html
      assert_select "[data-history-change='#{large.id}']", text: /#{Regexp.escape(I18n.t('odontogram.categories.macrodontia'))}/
      assert_select "[data-history-change='#{small.id}']", text: /#{Regexp.escape(I18n.t('odontogram.categories.microdontia'))}/
      assert_select '.translation_missing', count: 0
    end
    change(operation: 'undo', change_id: small.id)
    change(operation: 'undo', change_id: removal.id)
    assert_equal ['macrodontia'], @patient.odontogram_entries.active.pluck(:category)
  end

end
