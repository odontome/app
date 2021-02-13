require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'reset password instructions mail' do
    user = users(:founder)

    # Send the email, then test that it got queued
    email = user.deliver_password_reset_instructions!

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t('mailers.notifier.password_reset.subject'), email.subject
  end
end
