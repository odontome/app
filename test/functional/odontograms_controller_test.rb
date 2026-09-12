# frozen_string_literal: true

require 'test_helper'

class OdontogramsControllerTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @practice = practices(:complete)
    @patient = patients(:one)
    @attributes = { category: 'caries', tooth: 16, surfaces: ['O'] }
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  def post(action, params:, **options)
    super(action, params: { request_id: SecureRandom.uuid, editor_id: SecureRandom.uuid,
      revision: Patient.find(params[:patient_id]).odontogram_revision }.merge(params), **options)
  end

  test 'disabled practice cannot open an empty chart or write directly' do
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_response :not_found

    assert_no_difference 'OdontogramEntry.count' do
      post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes }, as: :json
    end
    assert_response :forbidden
  end

  test 'enabled practice can record an entry with authoritative ownership and author' do
    @practice.update!(odontogram_enabled: true)
    assert_difference 'OdontogramEntry.count', 1 do
      post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes.merge(
        patient_id: patients(:three).id, recorded_by_id: users(:superadmin).id, recorded_by_name: 'Forged',
        created_at: '2000-01-01'
      ) }, as: :json
    end
    assert_response :created
    entry = @patient.odontogram_entries.last
    assert_equal users(:founder).id, entry.recorded_by_id
    assert_equal users(:founder).fullname, entry.recorded_by_name
    assert_equal ['O'], entry.surfaces
    assert_nil entry.observed_on
    assert_in_delta Time.current, entry.created_at, 5
  end

  test 'an open editor loses write access on the next request after disablement' do
    @practice.update!(odontogram_enabled: true)
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_response :success
    Practice.find(@practice.id).update!(odontogram_enabled: false)

    assert_no_difference 'OdontogramEntry.count' do
      post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes }, as: :json
    end
    assert_response :forbidden
  end

  test 'enable disable enable preserves records and read-only access' do
    @practice.update!(odontogram_enabled: true)
    post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes }, as: :json
    assert_response :created
    saved = @patient.odontogram_entries.first.attributes

    [false, true, false].each do |enabled|
      @practice.update!(odontogram_enabled: enabled)
      get :show, params: { patient_id: @patient.id }, as: :html
      assert_response :success
      assert_equal saved, @patient.odontogram_entries.first.reload.attributes
      assert_select '[data-odontogram-entry]', count: 1
      assert_select '[data-odontogram-records] form', count: 0
      assert_select 'canvas, svg[data-odontogram]', count: 0
      assert_select '[data-odontogram-read-only]', count: enabled ? 0 : 1
    end
  end

  test 'chart reads and writes cannot cross practices' do
    @practice.update!(odontogram_enabled: true)
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: patients(:three).id }
    end
    assert_no_difference 'OdontogramEntry.count' do
      assert_raises ActiveRecord::RecordNotFound do
        post :create, params: { patient_id: patients(:three).id, odontogram_entry: @attributes }, as: :json
      end
    end
  end

  test 'impersonation can read but cannot record entries' do
    @practice.update!(odontogram_enabled: true)
    @controller.session['impersonator_id'] = users(:superadmin).id
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_response :success
    assert_select '[data-odontogram-read-only]', count: 1
    assert_no_difference 'OdontogramEntry.count' do
      post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes }, as: :json
    end
    assert_response :forbidden
  end

  test 'chart requires authentication' do
    @controller.session['user'] = nil
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_redirected_to signin_path
    assert_no_difference 'OdontogramEntry.count' do
      post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes }, as: :json
    end
    assert_response :redirect
  end

  test 'invalid anatomy is rejected without persisting a partial record' do
    @practice.update!(odontogram_enabled: true)
    assert_no_difference 'OdontogramEntry.count' do
      post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes.merge(tooth: 99) }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test 'older saved entries remain reachable without leaking another patients cursor' do
    @practice.update!(odontogram_enabled: true)
    OdontogramEntry::TEETH.first(51).each do |tooth|
      @patient.odontogram_entries.create!(tooth: tooth, category: 'crown', surfaces: [], recorded_by_name: 'Sample Author')
    end
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_select '[data-odontogram-entry]', count: 50
    cursor = assigns(:entries).last
    assert_select "a[href='#{patient_odontogram_path(@patient, before: cursor.id)}']"
    get :show, params: { patient_id: @patient.id, before: cursor.id }, as: :html
    assert_select '[data-odontogram-entry]', count: 1

    other = patients(:three).odontogram_entries.create!(@attributes.merge(recorded_by_name: 'Other Author'))
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: @patient.id, before: other.id }, as: :html
    end
  end

  test 'saved records are localized escaped and useful on a phone' do
    @practice.update!(odontogram_enabled: true)
    post :create, params: { patient_id: @patient.id, odontogram_entry: @attributes }, as: :json
    @patient.odontogram_entries.last.update_column(:recorded_by_name, '<script>unsafe()</script>')
    @practice.update!(odontogram_enabled: false)
    { 'en' => 'Caries', 'es' => 'Caries', 'pt' => 'Cárie' }.each do |locale, label|
      @practice.update!(locale: locale)
      @request.user_agent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)'
      get :show, params: { patient_id: @patient.id }, as: :html
      assert_response :success
      assert_select '[data-odontogram-entry]', text: /#{label}/
      assert_includes response.body, '&lt;script&gt;unsafe()&lt;/script&gt;'
      assert_select '.translation_missing', count: 0
      assert_select '[data-odontogram-records] input, [data-odontogram-records] textarea, canvas', count: 0
    end
  end
end
