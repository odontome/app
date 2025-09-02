# frozen_string_literal: true

require 'test_helper'

class AnnouncementTest < ActiveSupport::TestCase
  def setup
    @user = users(:founder)
    @announcement = Announcement.create!(
      version: 1,
      announcement_type: 'info',
      i18n_key: 'announcements.v1.message',
      active: true,
      published_at: Time.current
    )
  end

  test 'should create announcement with valid attributes' do
    announcement = Announcement.new(
      version: 2,
      announcement_type: 'warning',
      i18n_key: 'announcements.v2.message',
      active: true
    )
    assert announcement.save
  end

  test 'should not save announcement without version' do
    announcement = Announcement.new(
      announcement_type: 'info',
      i18n_key: 'announcements.test.message'
    )
    assert_not announcement.save
  end

  test 'should not save announcement without announcement_type' do
    announcement = Announcement.new(
      version: 2,
      i18n_key: 'announcements.test.message'
    )
    assert_not announcement.save
  end

  test 'should not save announcement without i18n_key' do
    announcement = Announcement.new(
      version: 2,
      announcement_type: 'info'
    )
    assert_not announcement.save
  end

  test 'should not save announcement with duplicate version' do
    announcement = Announcement.new(
      version: 1, # Same as @announcement
      announcement_type: 'info',
      i18n_key: 'announcements.test.message'
    )
    assert_not announcement.save
  end

  test 'should validate announcement_type inclusion' do
    announcement = Announcement.new(
      version: 2,
      announcement_type: 'invalid',
      i18n_key: 'announcements.test.message'
    )
    assert_not announcement.save
  end

  test 'dismissed_by? should return false for non-dismissed announcement' do
    assert_not @announcement.dismissed_by?(@user)
  end

  test 'dismissed_by? should return true for dismissed announcement' do
    AnnouncementDismissal.create!(user: @user, announcement: @announcement)
    assert @announcement.dismissed_by?(@user)
  end

  test 'dismissed_by? should return false for nil user' do
    assert_not @announcement.dismissed_by?(nil)
  end

  test 'active scope should return only active announcements' do
    inactive_announcement = Announcement.create!(
      version: 2,
      announcement_type: 'info',
      i18n_key: 'announcements.v2.message',
      active: false
    )
    
    active_announcements = Announcement.active
    assert_includes active_announcements, @announcement
    assert_not_includes active_announcements, inactive_announcement
  end

  test 'published scope should respect published_at time' do
    future_announcement = Announcement.create!(
      version: 2,
      announcement_type: 'info',
      i18n_key: 'announcements.v2.message',
      active: true,
      published_at: 1.hour.from_now
    )
    
    published_announcements = Announcement.published
    assert_includes published_announcements, @announcement
    assert_not_includes published_announcements, future_announcement
  end

  test 'active_for_user should return all for nil user' do
    announcements = Announcement.active_for_user(nil)
    assert_includes announcements, @announcement
  end

  test 'active_for_user should filter dismissed announcements' do
    AnnouncementDismissal.create!(user: @user, announcement: @announcement)
    
    announcements = Announcement.active_for_user(@user)
    assert_not_includes announcements, @announcement
  end
end
