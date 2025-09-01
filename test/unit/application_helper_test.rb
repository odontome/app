# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "should return 'active' when controller name matches string tab" do
    def controller
      OpenStruct.new(controller_name: 'patients')
    end

    assert_equal 'active', is_active_tab?('patients')
    assert_equal '', is_active_tab?('datebooks')
  end

  test "should return 'active' when controller name matches one tab in array" do
    def controller
      OpenStruct.new(controller_name: 'doctors')
    end

    assert_equal 'active', is_active_tab?(%i[patients doctors treatments])
    assert_equal '', is_active_tab?(%i[users])
  end

  test 'should throw an error for invalid tab' do
    assert_raises(RuntimeError) do
      is_active_tab?('invalid_tab')
    end
  end

  # Tests for active_announcements method
  def setup_announcements
    @user = users(:founder)
    # Set up some mock announcements
    mock_announcements = [
      { 'version' => 1, 'message' => 'First announcement' },
      { 'version' => 2, 'message' => 'Second announcement' },
      { 'version' => 3, 'message' => 'Third announcement' }
    ]
    Announcements.instance_variable_set(:@announcements, mock_announcements)
  end

  def teardown_announcements
    # Clear memoized announcements so tests remain isolated
    Announcements.instance_variable_set(:@announcements, nil)
  end

  test 'active_announcements returns all announcements when no user' do
    setup_announcements
    
    # Simulate no current user
    def current_user
      nil
    end

    active = active_announcements
    assert_equal 3, active.length
    assert_equal [1, 2, 3], active.map { |a| a['version'] }
    
    teardown_announcements
  end

  test 'active_announcements filters dismissed announcements for logged in user' do
    setup_announcements
    
    # Dismiss announcement version 2
    DismissedAnnouncement.create!(user: @user, announcement_version: 2)

    # Simulate current user
    def current_user
      @user
    end

    active = active_announcements
    assert_equal 2, active.length
    assert_equal [1, 3], active.map { |a| a['version'] }
    
    teardown_announcements
  end

  test 'active_announcements returns all when user has no dismissed announcements' do
    setup_announcements
    
    # Simulate current user with no dismissed announcements
    def current_user
      @user
    end

    active = active_announcements
    assert_equal 3, active.length
    assert_equal [1, 2, 3], active.map { |a| a['version'] }
    
    teardown_announcements
  end
end
