# frozen_string_literal: true

require 'test_helper'

class AnnouncementDismissalTest < ActiveSupport::TestCase
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

  test 'should create dismissal with valid attributes' do
    dismissal = AnnouncementDismissal.new(
      user: @user,
      announcement: @announcement
    )
    assert dismissal.save
  end

  test 'should not save dismissal without user' do
    dismissal = AnnouncementDismissal.new(
      announcement: @announcement
    )
    assert_not dismissal.save
  end

  test 'should not save dismissal without announcement' do
    dismissal = AnnouncementDismissal.new(
      user: @user
    )
    assert_not dismissal.save
  end

  test 'should not save duplicate dismissal for same user and announcement' do
    AnnouncementDismissal.create!(
      user: @user,
      announcement: @announcement
    )
    
    duplicate_dismissal = AnnouncementDismissal.new(
      user: @user,
      announcement: @announcement
    )
    assert_not duplicate_dismissal.save
  end

  test 'should allow different users to dismiss same announcement' do
    another_user = users(:admin)
    
    AnnouncementDismissal.create!(
      user: @user,
      announcement: @announcement
    )
    
    another_dismissal = AnnouncementDismissal.new(
      user: another_user,
      announcement: @announcement
    )
    assert another_dismissal.save
  end
end
