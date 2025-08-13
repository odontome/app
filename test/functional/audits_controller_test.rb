# frozen_string_literal: true

require 'test_helper'

class AuditsControllerTest < ActionController::TestCase
  def setup
    @admin_user = users(:founder)
    @regular_user = users(:perishable)
    @practice = @admin_user.practice
  end

  test "should redirect to login when not logged in" do
    get :index
    assert_redirected_to signin_path
  end

  test "should redirect non-admin users to unauthorized" do
    @controller.stubs(:current_user).returns(@regular_user)
    @controller.stubs(:user_is_admin?).returns(false)
    
    get :index
    assert_redirected_to '/401'
  end

  test "should allow admin users to view audit index" do
    @controller.stubs(:current_user).returns(@admin_user)
    @controller.stubs(:user_is_admin?).returns(true)
    
    # Create a version for testing
    patient = patients(:one)
    patient.update(firstname: 'Edwin Updated')
    
    get :index
    assert_response :success
    assert_not_nil assigns(:versions)
    assert_not_nil assigns(:available_item_types)
    assert_not_nil assigns(:available_users)
  end

  test "should filter audit records by item_type" do
    @controller.stubs(:current_user).returns(@admin_user)
    @controller.stubs(:user_is_admin?).returns(true)
    
    # Create versions for testing
    patient = patients(:one)
    patient.update(firstname: 'Edwin Updated')
    
    get :index, params: { item_type: 'Patient' }
    assert_response :success
    
    versions = assigns(:versions)
    assert versions.all? { |v| v.item_type == 'Patient' }
  end

  test "should filter audit records by event type" do
    @controller.stubs(:current_user).returns(@admin_user)
    @controller.stubs(:user_is_admin?).returns(true)
    
    get :index, params: { event: 'update' }
    assert_response :success
    
    versions = assigns(:versions)
    assert versions.all? { |v| v.event == 'update' }
  end

  test "should paginate audit records" do
    @controller.stubs(:current_user).returns(@admin_user)
    @controller.stubs(:user_is_admin?).returns(true)
    
    get :index, params: { page: 1 }
    assert_response :success
    
    assert_equal 1, assigns(:page)
    assert_equal 25, assigns(:per_page)
  end

  test "should show individual audit record for admin" do
    @controller.stubs(:current_user).returns(@admin_user)
    @controller.stubs(:user_is_admin?).returns(true)
    
    # Create a version for testing
    patient = patients(:one)
    patient.update(firstname: 'Edwin Updated')
    version = PaperTrail::Version.last
    
    get :show, params: { id: version.id }
    assert_response :success
    assert_equal version, assigns(:version)
  end

  test "should not show audit records from other practices" do
    @controller.stubs(:current_user).returns(@admin_user)
    @controller.stubs(:user_is_admin?).returns(true)
    
    # Create a version with different practice_id
    version = PaperTrail::Version.create!(
      item_type: 'Patient',
      item_id: 999,
      event: 'create',
      practice_id: 999, # Different practice
      created_at: Time.current
    )
    
    assert_raises(ActiveRecord::RecordNotFound) do
      get :show, params: { id: version.id }
    end
  end
end