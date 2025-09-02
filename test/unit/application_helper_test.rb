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
    # Create test announcements
    @announcement1 = Announcement.create!(
      version: 1,
      announcement_type: 'info',
      i18n_key: 'announcements.v1.message',
      active: true,
      published_at: Time.current
    )
    @announcement2 = Announcement.create!(
      version: 2,
      announcement_type: 'warning',
      i18n_key: 'announcements.v2.message',
      active: true,
      published_at: Time.current
    )
    @announcement3 = Announcement.create!(
      version: 3,
      announcement_type: 'success',
      i18n_key: 'announcements.v3.message',
      active: true,
      published_at: Time.current
    )
  end

  def teardown_announcements
    # Clean up test announcements
    Announcement.destroy_all
    AnnouncementDismissal.destroy_all
  end

  test 'active_announcements returns all announcements when no user' do
    setup_announcements
    
    # Test helper can directly call the method without mocking current_user
    # since it will be nil by default in the test environment
    active = active_announcements
    assert_equal 3, active.length
    assert_equal [1, 2, 3], active.map(&:version).sort
    
    teardown_announcements
  end

  test 'active_announcements filters dismissed announcements for logged in user' do
    setup_announcements
    
    # Dismiss announcement version 2
    AnnouncementDismissal.create!(user: @user, announcement: @announcement2)

    # Set up the session like the controller tests do
    session[:user] = @user

    active = active_announcements
    assert_equal 2, active.length
    assert_equal [1, 3], active.map(&:version).sort
    
    teardown_announcements
  end

  test 'active_announcements returns all when user has no dismissed announcements' do
    setup_announcements
    
    # Set up the session like the controller tests do
    session[:user] = @user

    active = active_announcements
    assert_equal 3, active.length
    assert_equal [1, 2, 3], active.map(&:version).sort
    
    teardown_announcements
  end
end
