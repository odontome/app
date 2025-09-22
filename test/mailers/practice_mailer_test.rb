# frozen_string_literal: true

require 'test_helper'

class PracticeMailerTest < ActionMailer::TestCase
  setup :yesterday_date

  def yesterday_date
    @today = Time.zone.now.beginning_of_day
    @yesterday = @today - 1.day
  end

  test 'practice welcome email' do
    practice = practices(:complete)
    practice.users << users(:founder)

    # Send the email, then test that it got queued
    email = PracticeMailer.welcome_email(practice).deliver_now
    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t('mailers.practice.welcome.subject'), email.subject
    assert_match(/Welcome to Odonto.me/, email.encoded)
  end

  test 'new_review_notification' do
    review = reviews(:valid)
    practice = review.appointment.datebook.practice
    admin_user = practice.users.first

    mail = PracticeMailer.new_review_notification(review)
    assert_equal I18n.t('mailers.practice.new_review_notification.subject'), mail.subject
    assert_equal admin_user.email, mail.to.first
    assert_equal ['hello@odonto.me'], mail.from
    assert_match 'View more at', mail.body.encoded
  end

  test 'new_review_notification with custom_review_url' do
    review = reviews(:valid)
    practice = review.appointment.datebook.practice
    practice.update!(custom_review_url: 'https://custom.example.com/reviews')
    admin_user = practice.users.first

    mail = PracticeMailer.new_review_notification(review)
    assert_equal I18n.t('mailers.practice.new_review_notification.subject'), mail.subject
    assert_equal admin_user.email, mail.to.first
    assert_equal ['hello@odonto.me'], mail.from
    assert_match 'View more at https://custom.example.com/reviews', mail.body.encoded
  end

  test 'new_review_notification falls back to default when no custom_review_url' do
    review = reviews(:valid)
    practice = review.appointment.datebook.practice
    practice.update!(custom_review_url: nil)
    admin_user = practice.users.first

    mail = PracticeMailer.new_review_notification(review)
    assert_equal I18n.t('mailers.practice.new_review_notification.subject'), mail.subject
    assert_equal admin_user.email, mail.to.first
    assert_equal ['hello@odonto.me'], mail.from
    assert_match 'View more at', mail.body.encoded
    # Should contain the default reviews URL pattern
    assert_match %r{/reviews}, mail.body.encoded
  end
end
