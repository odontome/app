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

  test 'activation nudge email' do
    practice = practices(:complete_another_language) # locale: es

    email = PracticeMailer.activation_nudge(practice)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ['hello@odonto.me'], email.from
    assert_equal [practice.email], email.to
    assert_equal I18n.t('mailers.practice.activation_nudge.subject', locale: :es), email.subject
    assert_match(%r{https://my.odonto.me/patients/new}, email.encoded)
  end

  test 'trial ending email includes date and price' do
    practice = practices(:trialing_practice)

    email = PracticeMailer.trial_ending(practice)

    assert_equal [practice.email], email.to
    assert_equal I18n.t('mailers.practice.trial_ending.subject'), email.subject
    assert_match practice.subscription.current_period_end.strftime('%d/%m/%Y'), email.encoded
    assert_match(/\$6 USD/, email.encoded)
    assert_match(%r{https://my.odonto.me/practice/settings}, email.encoded)
  end

  test 'trial ended email' do
    practice = practices(:trialing_practice)

    email = PracticeMailer.trial_ended(practice)

    assert_equal [practice.email], email.to
    assert_equal I18n.t('mailers.practice.trial_ended.subject'), email.subject
    assert_match(%r{https://my.odonto.me/practice/settings}, email.encoded)
  end

  test 'deletion warning email' do
    practice = practices(:trialing_practice)

    email = PracticeMailer.deletion_warning(practice)

    assert_equal [practice.email], email.to
    assert_equal I18n.t('mailers.practice.deletion_warning.subject'), email.subject
    assert_match(%r{https://my.odonto.me/practice/settings}, email.encoded)
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
end
