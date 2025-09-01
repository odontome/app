# frozen_string_literal: true

require 'test_helper'

class DismissedAnnouncementTest < ActiveSupport::TestCase
  def setup
    @user = users(:founder)
    @dismissed_announcement = DismissedAnnouncement.new(
      user: @user,
      announcement_version: 1
    )
  end

  test 'should be valid with valid attributes' do
    assert @dismissed_announcement.valid?
  end

  test 'should require user' do
    @dismissed_announcement.user = nil
    assert_not @dismissed_announcement.valid?
    assert_includes @dismissed_announcement.errors[:user_id], "can't be blank"
  end

  test 'should require announcement_version' do
    @dismissed_announcement.announcement_version = nil
    assert_not @dismissed_announcement.valid?
    assert_includes @dismissed_announcement.errors[:announcement_version], "can't be blank"
  end

  test 'should validate uniqueness of announcement_version per user' do
    @dismissed_announcement.save!
    
    duplicate = DismissedAnnouncement.new(
      user: @user,
      announcement_version: 1
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:announcement_version], 'has already been taken'
  end

  test 'should allow same announcement_version for different users' do
    @dismissed_announcement.save!
    
    other_user = users(:admin)
    other_dismissed = DismissedAnnouncement.new(
      user: other_user,
      announcement_version: 1
    )
    
    assert other_dismissed.valid?
  end

  test 'should validate announcement_version is a positive integer' do
    @dismissed_announcement.announcement_version = 0
    assert_not @dismissed_announcement.valid?
    
    @dismissed_announcement.announcement_version = -1
    assert_not @dismissed_announcement.valid?
    
    @dismissed_announcement.announcement_version = 1.5
    assert_not @dismissed_announcement.valid?
  end

  test 'for_user scope should return dismissed announcements for specific user' do
    @dismissed_announcement.save!
    
    other_user = users(:admin)
    other_dismissed = DismissedAnnouncement.create!(
      user: other_user,
      announcement_version: 2
    )
    
    user_dismissed = DismissedAnnouncement.for_user(@user.id)
    assert_includes user_dismissed, @dismissed_announcement
    assert_not_includes user_dismissed, other_dismissed
  end

  test 'for_versions scope should return dismissed announcements for specific versions' do
    @dismissed_announcement.save!
    
    another_dismissed = DismissedAnnouncement.create!(
      user: @user,
      announcement_version: 2
    )
    
    versions_dismissed = DismissedAnnouncement.for_versions([1])
    assert_includes versions_dismissed, @dismissed_announcement
    assert_not_includes versions_dismissed, another_dismissed
  end
end