# frozen_string_literal: true

require 'test_helper'

class NotifierMailerTest < ActionMailer::TestCase
  test 'password reset instructions email' do
    user = users(:founder)

    emails_before = ActionMailer::Base.deliveries.size

    email = NotifierMailer.deliver_password_reset_instructions(user).deliver_now

    assert_equal emails_before + 1, ActionMailer::Base.deliveries.size
    assert_equal ['hello@odonto.me'], email.from
    assert_equal [user.email], email.to
    assert_equal I18n.t('mailers.notifier.password_reset.subject'), email.subject
    assert_match user.perishable_token, email.body.encoded
  end

  test 'password reset email uses the practice locale' do
    user = users(:user_in_yet_another_practice)
    user.practice.update!(locale: 'es')

    emails_before = ActionMailer::Base.deliveries.size

    email = NotifierMailer.deliver_password_reset_instructions(user).deliver_now

    assert_equal emails_before + 1, ActionMailer::Base.deliveries.size
    expected_subject = I18n.with_locale(:es) { I18n.t('mailers.notifier.password_reset.subject') }
    assert_equal expected_subject, email.subject
  end

  test 'email changed notice goes to the previous address' do
    user = users(:founder)

    email = NotifierMailer.email_changed(user, 'old-address@odonto.me').deliver_now

    assert_equal ['old-address@odonto.me'], email.to
    assert_equal I18n.t('mailers.notifier.email_changed.subject'), email.subject
    assert_match user.email, email.body.encoded
  end

  test 'email changed notice uses the practice locale' do
    user = users(:user_in_yet_another_practice)
    user.practice.update!(locale: 'pt')

    email = NotifierMailer.email_changed(user, 'old-address@odonto.me').deliver_now

    expected_subject = I18n.with_locale(:pt) { I18n.t('mailers.notifier.email_changed.subject') }
    assert_equal expected_subject, email.subject
  end
end
