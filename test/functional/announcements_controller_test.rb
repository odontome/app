# frozen_string_literal: true

require 'test_helper'

class AnnouncementsControllerTest < ActionController::TestCase
  def setup
    @user = users(:founder)
    session[:user] = @user
  end

  test 'should dismiss announcement and store in database' do
    assert_difference 'DismissedAnnouncement.count', 1 do
      post :dismiss, params: { version: 1 }
    end

    assert_response :success
    
    dismissed = DismissedAnnouncement.find_by(user: @user, announcement_version: 1)
    assert_not_nil dismissed
    assert_equal 1, dismissed.announcement_version
  end

  test 'should return bad request for missing version' do
    assert_no_difference 'DismissedAnnouncement.count' do
      post :dismiss, params: {}
    end

    assert_response :bad_request
  end

  test 'should return bad request when no user is logged in' do
    session[:user] = nil

    assert_no_difference 'DismissedAnnouncement.count' do
      post :dismiss, params: { version: 1 }
    end

    assert_response :bad_request
  end

  test 'should not dismiss same announcement twice' do
    # First dismissal should create a record
    assert_difference 'DismissedAnnouncement.count', 1 do
      post :dismiss, params: { version: 1 }
    end
    assert_response :success

    # Second dismissal should not create another record (find_or_create_by)
    assert_no_difference 'DismissedAnnouncement.count' do
      post :dismiss, params: { version: 1 }
    end
    assert_response :success

    # Should still only have one record for this user/version combination
    dismissed_count = DismissedAnnouncement.where(user: @user, announcement_version: 1).count
    assert_equal 1, dismissed_count
  end
end
