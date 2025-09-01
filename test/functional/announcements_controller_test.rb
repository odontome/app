# frozen_string_literal: true

require 'test_helper'

class AnnouncementsControllerTest < ActionController::TestCase
  def setup
    @user = users(:founder)
    session[:user] = @user
  end

  test 'should dismiss announcement and store in session' do
    post :dismiss, params: { version: 1 }

    assert_response :success
    assert_includes session[:dismissed_announcements], 1
  end

  test 'should return bad request for missing version' do
    post :dismiss, params: {}

    assert_response :bad_request
  end

  test 'should not dismiss same announcement twice' do
    post :dismiss, params: { version: 1 }
    post :dismiss, params: { version: 1 }

    assert_response :success
    assert_equal 1, session[:dismissed_announcements].count(1)
  end
end
