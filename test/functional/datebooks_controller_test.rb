# frozen_string_literal: true

require 'test_helper'
require 'open3'

class DatebooksControllerTest < ActionController::TestCase
  setup do
    @previous_locale = I18n.locale
    @controller.session['user'] = users(:founder)
    @datebook = { name: 'Bokanova Dental' }
  end

  teardown do
    I18n.locale = @previous_locale
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:datebooks)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should not get new if not admin' do
    @controller.session['user'] = users(:perishable)

    get :new
    assert_response :redirect
  end

  test 'should create datebook' do
    assert_difference('Datebook.count') do
      post :create, params: { datebook: @datebook }
    end
    assert_redirected_to datebooks_url
  end

  test 'should show datebook' do
    get :show, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
  end

  test 'calendar does not display a timezone label' do
    users(:founder).practice.update!(timezone: 'Eastern Time (US & Canada)')
    get :show, params: { id: datebooks(:playa_del_carmen).id }
    assert_response :success
    assert_select '#calendar', count: 1
    assert_select '.page-header p', text: /Eastern Time/, count: 0
  end

  test 'calendar uses the Tabler FullCalendar integration and official theme controls' do
    get :show, params: { id: datebooks(:playa_del_carmen).id }
    assert_response :success

    assert_includes response.body, 'new FullCalendar.Calendar'
    assert_includes response.body, 'tabler.Modal.getOrCreateInstance'
    assert_includes response.body, "timeZone: 'UTC'"
    assert_includes response.body, "slotDuration: '00:30:00'"
    assert_includes response.body, "snapDuration: '00:15:00'"
    assert_includes response.body, "wall_clock: '1'"
    assert_not_includes response.body, '.fullCalendar('
    assert_not_includes response.body, 'ignoreTimezone'
    assert_select 'script[src*="/theme-"]', count: 1
    assert_select 'body#app-body:not(.theme-light):not(.theme-dark)', count: 1
    assert_select 'a.hide-theme-dark[aria-label=?]', I18n.t(:enable_dark_mode), count: 1
    assert_select 'a.hide-theme-light[aria-label=?]', I18n.t(:enable_light_mode), count: 1
  end

  test 'should get edit' do
    get :edit, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
  end

  %w[en es pt].product(%w[wide compact], %w[UTC Pacific/Honolulu]).each do |locale, layout, timezone|
    test "calendar keeps 12-hour times in #{locale} on #{layout} screens with #{timezone} host time" do
      users(:founder).practice.update!(locale: locale)
      get :show, params: { id: datebooks(:playa_del_carmen).id }
      assert_response :success

      output, error, status = Open3.capture3(
        { 'TZ' => timezone },
        'node', Rails.root.join('test/support/calendar_time_formats.js').to_s, layout,
        stdin_data: response.body
      )
      assert status.success?, error
      calendar = JSON.parse(output)
      assert_equal locale, calendar.fetch('locale')
      assert_equal layout == 'compact' ? 'timeGridDay' : 'timeGridWeek', calendar.fetch('view')
      assert_equal ['1–2', '1:30–2:30', '11:30–12:30'], calendar.fetch('ranges')

      expected_times = ['12am', '9am', '9:15am', '12pm', '1:30pm', '9pm', '11:45pm']
      assert_equal expected_times.length, calendar.fetch('results').length
      calendar.fetch('results').zip(expected_times).each do |result, expected|
        assert_equal expected, result.fetch('slot')
        assert_equal expected.sub(/[ap]m\z/, ''), result.fetch('event')
        %w[newTitle editTitle].each do |surface|
          assert_equal expected, result.fetch(surface).split(' · ').last,
                       "#{locale} #{layout} #{surface} at #{result.fetch('time')}"
        end
      end
    end
  end

  test 'should not get edit if not admin' do
    @controller.session['user'] = users(:perishable)

    get :edit, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :redirect
  end

  test 'should update datebook' do
    put :update, params: { id: datebooks(:playa_del_carmen).to_param, datebook: @datebook }
    assert_redirected_to datebooks_url
  end

  test 'should destroy datebook without appointments' do
    assert_difference('Datebook.count', -1) do
      delete :destroy, params: { id: datebooks(:without_appointments).to_param }
    end

    assert_redirected_to datebooks_url
  end

  # test "should not destroy datebook with appointments" do
  #   assert_no_difference('Datebook.count') do
  #     delete :destroy, params: {id: datebooks(:playa_del_carmen).to_param}
  #   end

  #   assert_redirected_to datebooks_url
  # end
end
