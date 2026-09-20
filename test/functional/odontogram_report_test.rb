# frozen_string_literal: true
require 'test_helper'

class OdontogramReportTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    @practice = practices(:complete)
    @editor = SecureRandom.uuid
  end

  def change(attributes = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 16, category: 'crown', surfaces: [], treatment_status: 'planned' }.merge(attributes) }.merge(operation), as: :json
    assert_response :created
    @patient.odontogram_entries.recent.first
  end

  test 'saved prices survive catalogue changes completion removal undo and history' do
    treatment = @practice.treatments.create!(builtin_category: 'crown', price: 125.50)
    entry = change({ price: 1, currency: 'eur' })
    assert_equal BigDecimal('125.50'), entry.price
    assert_equal 'usd', entry.currency
    original = @patient.odontogram_changes.sole
    treatment.update!(price: 500)
    @practice.update!(currency: 'cad')
    assert_no_difference 'Balance.count' do
      change({}, operation: 'complete', entry_id: entry.id)
      change({}, operation: 'remove', entry_id: entry.id)
      change({}, operation: 'undo', change_id: @patient.odontogram_changes.recent.first.id)
    end
    assert_equal BigDecimal('125.50'), entry.reload.price
    assert_equal 'usd', entry.currency
    assert_equal '125.5', original.chart_entries.sole['price']
    get :report, format: :html, params: { patient_id: @patient.id }
    assert_response :success
    assert_select '[data-report-total="usd"]', text: /125.50/
    assert_select '[data-report-total="cad"]', count: 0
  end

  test 'custom prices including zero are saved but old entries stay unpriced' do
    old = @patient.odontogram_entries.create!(category: 'crown', tooth: 15, treatment_status: 'planned', recorded_by_name: 'Sample')
    custom = @practice.treatments.create!(name: 'Ceramic crown', odontogram_category: 'crown', price: 0)
    entry = change({ treatment_id: custom.id, treatment_version: custom.updated_at.utc.iso8601(6) })
    assert_equal 0, entry.price
    custom.update!(price: 50, name: 'New name')
    get :report, format: :html, params: { patient_id: @patient.id }
    assert_select '[data-report-entry]', count: 2
    assert_select "[data-report-entry='#{entry.id}']", text: /Ceramic crown/
    assert_select "[data-report-entry='#{old.id}']", text: /No price/
    assert_select '[data-report-total]', text: /Total of priced treatments.*0.00/
    assert_nil old.reload.price
  end

  test 'unpriced reports omit amounts and exclude existing work findings and removed entries' do
    visible = change
    change({ tooth: 15, treatment_status: 'existing' })
    change({ tooth: 14, category: 'caries', surfaces: ['O'], treatment_status: 'existing' })
    removed = change({ tooth: 13 })
    change({}, operation: 'remove', entry_id: removed.id)
    get :report, format: :html, params: { patient_id: @patient.id }
    assert_select '[data-report-entry]', count: 1
    assert_select "[data-report-entry='#{visible.id}']", count: 1
    assert_select '.report-price', count: 0
    assert_select '[data-report-total]', count: 0
  end

  test 'grouped work is one priced row and different currencies have separate totals' do
    @practice.treatments.create!(builtin_category: 'fixed_bridge', price: 300)
    bridge = change({ category: 'fixed_bridge', bridge_units: [{ tooth: 16, role: 'natural_support' }, { tooth: 15, role: 'pontic' }] })
    @practice.treatments.create!(builtin_category: 'crown', price: 200)
    @practice.update!(currency: 'cad')
    change({ tooth: 13 })
    get :report, format: :html, params: { patient_id: @patient.id }
    assert_select '[data-report-entry]', count: 2
    assert_select "[data-report-entry='#{bridge.id}']", text: /16, 15/
    assert_select '[data-report-total="usd"]', text: /300.00/
    assert_select '[data-report-total="cad"]', text: /200.00/
  end

  test 'reports are available without activation and respect patient and practice boundaries' do
    change
    get :report, format: :html, params: { patient_id: @patient.id }
    assert_response :success
    assert_equal 'no-store', response.headers['Cache-Control']
    assert_raises(ActiveRecord::RecordNotFound) { get :report, format: :html, params: { patient_id: patients(:three).id } }
    get :report, format: :html, params: { patient_id: patients(:two).id }
    assert_response :success
  end

  test 'print controls and empty report render in all locales' do
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :report, format: :html, params: { patient_id: @patient.id }
      assert_response :success
      assert_select 'html[lang=?]', locale
      assert_select '[data-print-report]', count: 1
      assert_select 'link[rel="stylesheet"][href*="treatment-report"][media="all"]', count: 1
      assert_select 'link[rel="stylesheet"][href*="application"][media="screen"]', count: 1
      assert_select '.container-xl', count: 0
      assert_select 'a[href=?]', patient_path(@patient)
      assert_no_match(/translation_missing|Translation missing/, response.body)
    end
  end

  test 'report loads entries once without catalogue lookups as it grows' do
    [16, 15, 14, 13, 12, 11, 21, 22, 23, 24].each do |tooth|
      @patient.odontogram_entries.create!(category: 'crown', tooth: tooth, treatment_status: 'planned', recorded_by_name: 'Sample', price: 100, currency: 'usd')
    end
    queries = []
    subscriber = ->(*args) do
      payload = args.last
      queries << payload[:sql] if payload[:name] != 'SCHEMA' && payload[:sql].match?(/\ASELECT/i) && payload[:sql].match?(/"odontogram_entries"|"treatments"/)
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        get :report, format: :html, params: { patient_id: @patient.id }
      end
    end
    assert_response :success
    assert_select '[data-report-entry]', count: 10
    assert_equal 1, queries.size, queries.join("\n")
  end

  test 'the report does not pretend to serve a downloadable PDF' do
    get :report, params: { patient_id: @patient.id, format: :pdf }
    assert_response :not_acceptable
  end
end
