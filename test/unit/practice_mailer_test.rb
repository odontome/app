require 'test_helper'
 
class PracticeMailerTest < ActionMailer::TestCase

  test "practice welcome email" do
    practice = practices(:complete)
    practice.users << users(:founder)

    # Send the email, then test that it got queued
    email = PracticeMailer.welcome_email(practice).deliver
    assert !ActionMailer::Base.deliveries.empty?
  
    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t("mailers.practice.welcome.subject"), email.subject
    #assert_equal read_fixture('welcome_email').join, email.body.to_s
  end

end