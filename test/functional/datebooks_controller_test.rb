# frozen_string_literal: true

require 'test_helper'

class DatebooksControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
    @datebook = { name: 'Bokanova Dental' }
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
