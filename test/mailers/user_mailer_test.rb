# frozen_string_literal: true

require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'reset password instructions rotate the persisted token and deliver it once' do
    user = users(:founder)
    previous_token = user.perishable_token

    assert_emails 1 do
      user.deliver_password_reset_instructions!
    end

    current_token = user.reload.perishable_token
    assert current_token.present?
    assert_not_equal previous_token, current_token
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, current_token
  end
end
