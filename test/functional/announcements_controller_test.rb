# frozen_string_literal: true

require 'test_helper'

class AnnouncementsControllerTest < ActionController::TestCase
  def setup
    @user = users(:founder)
    session[:user] = @user
    
    # Create a test announcement
    @announcement = Announcement.create!(
      version: 1,
      announcement_type: 'info',
      i18n_key: 'announcements.v1.message',
      active: true,
      published_at: Time.current
    )
  end

  test 'should dismiss announcement and store in database' do
    assert_difference 'AnnouncementDismissal.count', 1 do
      post :dismiss, params: { version: 1 }
    end

    assert_response :success
    
    dismissal = AnnouncementDismissal.find_by(user: @user, announcement: @announcement)
    assert_not_nil dismissal
  end

  test 'should return bad request for missing version' do
    assert_no_difference 'AnnouncementDismissal.count' do
      post :dismiss, params: {}
    end

    assert_response :bad_request
  end

  test 'should return bad request when no user is logged in' do
    session[:user] = nil

    assert_no_difference 'AnnouncementDismissal.count' do
      post :dismiss, params: { version: 1 }
    end

    assert_response :bad_request
  end

  test 'should return not found for non-existent announcement version' do
    assert_no_difference 'AnnouncementDismissal.count' do
      post :dismiss, params: { version: 999 }
    end

    assert_response :not_found
  end

  test 'should not dismiss same announcement twice' do
    # First dismissal should create a record
    assert_difference 'AnnouncementDismissal.count', 1 do
      post :dismiss, params: { version: 1 }
    end
    assert_response :success

    # Second dismissal should not create another record (find_or_create_by)
    assert_no_difference 'AnnouncementDismissal.count' do
      post :dismiss, params: { version: 1 }
    end
    assert_response :success

    # Should still only have one record for this user/announcement combination
    dismissal_count = AnnouncementDismissal.where(user: @user, announcement: @announcement).count
    assert_equal 1, dismissal_count
  end
end
