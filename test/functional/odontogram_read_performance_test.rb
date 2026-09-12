# frozen_string_literal: true
require 'test_helper'
require 'benchmark'

class OdontogramReadPerformanceTest < ActionController::TestCase
  tests OdontogramsController
  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
  end

  def measure(label)
    sql = []
    elapsed = Benchmark.realtime do
      ActiveRecord::Base.uncached do
        subscriber = ->(_name, start, finish, _id, payload) do
          sql << { sql: payload[:sql], milliseconds: (finish - start) * 1000 } if payload[:name] != 'SCHEMA' && payload[:sql].match?(/\ASELECT/i) && payload[:sql].match?(/odontogram_|"treatments"/)
        end
        ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') { yield }
      end
    end
    puts "#{label}: #{sql.size} SELECTs, #{sql.sum { |query| query[:milliseconds] }.round(1)} ms SQL, #{(elapsed * 1000).round(1)} ms request" if ENV['ODONTOGRAM_PROFILE'] == '1'
    sql
  end

  def add_filling_records(count)
    # Distinct valid surface sets; bulk insertion only keeps performance-fixture setup outside the measurement.
    rows = OdontogramEntry::TEETH.flat_map do |tooth|
      surfaces = [tooth % 10 <= 3 ? 'F' : 'B', 'M', [1,2,5,6].include?(tooth / 10) ? 'P' : 'L', 'D', tooth % 10 <= 3 ? 'I' : 'O']
      (1..8).map do |mask|
        { patient_id: @patient.id, category: 'filling', tooth: tooth, surfaces: surfaces.each_with_index.filter_map { |surface, index| surface if mask[index] == 1 },
          recorded_by_name: 'Sample', created_at: Time.current, updated_at: Time.current }
      end
    end
    OdontogramEntry.insert_all!(rows.first(count))
  end

  test 'loading a dense chart uses a fixed number of queries and returns every current marking' do
    small = measure('Empty chart') { get :show, params: { patient_id: @patient.id }, as: :json }
    assert_response :success
    add_filling_records(400)
    large = measure('400-entry chart') { get :show, params: { patient_id: @patient.id }, as: :json }
    assert_response :success
    assert_equal 400, response.parsed_body['entries'].size
    assert_operator large.size, :<=, small.size
    assert_operator large.size, :<=, 3
  end

  test 'history preview stays bounded when the recorded days grow' do
    event_count = Integer(ENV.fetch('ODONTOGRAM_HISTORY_EVENTS', '600'))
    assert_operator event_count, :>=, 600
    stamp = (event_count / 20 + 1).days.ago.change(hour: 12)
    entry = @patient.odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], recorded_by_name: 'Sample', created_at: stamp)
    changes = event_count.times.map do |index|
      active = index.even?
      state = entry.chart_attributes.merge('state' => active ? 'active' : 'removed')
      { patient_id: @patient.id, odontogram_entry_id: entry.id, operation: active ? (index.zero? ? 'add' : 'undo') : 'remove', recorded_by_name: 'Sample',
        request_id: SecureRandom.uuid, request_digest: 'fixture', editor_id: SecureRandom.uuid, revision: index + 1,
        before_state: index.zero? ? nil : state.merge('state' => active ? 'removed' : 'active'), after_state: state,
        created_at: stamp + (index / 20).days + (index % 20).minutes, updated_at: stamp }
    end
    # One addition followed by explicit corrections/restorations; the payload is a rendering fixture.
    OdontogramChange.insert_all!(changes.first(20))
    measure('1-day history') { get :show, params: { patient_id: @patient.id }, as: :html }
    assert_response :success
    OdontogramChange.insert_all!(changes.drop(20))
    entry.update!(state: 'removed')
    @patient.update!(odontogram_revision: event_count)
    loaded = measure("#{event_count / 20}-day / #{event_count}-event history") { get :show, params: { patient_id: @patient.id }, as: :html }
    assert_response :success
    assert_select '[data-history-change]', count: 50
    assert_operator loaded.size, :<=, 15
    day = changes.last[:created_at].in_time_zone.to_date
    expanded = measure('Expanded history day') { get :show, params: { patient_id: @patient.id, history_day: day.to_s }, as: :html }
    assert_response :success
    assert_select '[data-history-change]', count: 20
    assert_operator expanded.size, :<=, 6
    snapshot = @patient.odontogram_changes.find_by!(revision: 1)
    saved = measure("Snapshot across #{event_count} events") { get :show, params: { patient_id: @patient.id, at: snapshot.id }, as: :json }
    assert_response :success
    assert_equal 'active', response.parsed_body['entries'].sole['state']
    assert_operator saved.size, :<=, 5
  end
end
