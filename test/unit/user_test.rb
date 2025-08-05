# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'user attributes must not be empty' do
    user = User.new
    assert user.invalid?
    assert user.errors[:firstname].any?
    assert user.errors[:lastname].any?
    assert user.errors[:email].any?
    assert user.errors[:password].any?
  end

  test 'user is not valid without an unique email' do
    user = User.new(firstname: 'Raul',
                    lastname: 'Riera',
                    email: users(:founder).email)

    assert !user.save
    assert_equal I18n.t('errors.messages.taken'), user.errors[:email].first
  end

  test 'user is not valid without a valid email address' do
    user = User.new(firstname: 'Raul',
                    lastname: 'Riera',
                    email: 'notvalid@')

    assert !user.save
    assert_equal I18n.t('errors.messages.invalid'), user.errors[:email].first
  end

  test 'user name should be less than 20 chars long each' do
    user = User.new(firstname: 'A really long firstname for a user IMHO',
                    lastname: 'A really long lastname as well if you ask me',
                    email: 'anok@email.com')

    assert !user.save
    assert_equal I18n.t('errors.messages.too_long', count: 20), user.errors[:firstname].first
    assert_equal I18n.t('errors.messages.too_long', count: 20), user.errors[:lastname].first
  end

  test 'user password must be at least 7 chars long' do
    user = users(:founder)
    user.password = '123'
    user.password_confirmation = '123'

    assert !user.save
    assert_equal I18n.t('errors.messages.too_short', count: 7), user.errors[:password].first
  end

  test 'user password must be confirmed' do
    user = User.new(firstname: 'Raul',
                    lastname: 'Riera',
                    email: 'new@email.com')
    user.password = '1234567890'
    user.password_confirmation = '1111111111'

    assert !user.save
    assert_equal I18n.t('errors.messages.confirmation', attribute: 'Password'),
                 user.errors[:password_confirmation].first
  end

  test 'user fullname shortcut' do
    user = users(:founder)

    assert_equal user.fullname, "#{user.firstname} #{user.lastname}"
  end

  test 'user perishable token changes when deliver password is invoked' do
    user = users(:founder)
    initial_token = user.perishable_token

    user.deliver_password_reset_instructions!
    assert_not_equal initial_token, user.perishable_token
  end

  test 'user perishable token changes when the user is updated' do
    user = users(:founder)
    initial_token = user.perishable_token

    user.firstname = 'Paul'
    assert user.save
    assert_not_equal initial_token, user.perishable_token
  end

  test 'user name can be used as initials' do
    user = User.new(firstname: 'Esteban', lastname: 'Roberts')

    assert_equal user.initials, 'ER'
  end

  test 'remember_me! sets remember token and expiration' do
    user = users(:founder)
    assert user.remember_token.blank?
    assert user.remember_token_expires_at.blank?

    user.remember_me!

    assert user.remember_token.present?
    assert user.remember_token_expires_at.present?
    assert user.remember_token_expires_at > Time.current
    assert user.remember_token_valid?
  end

  test 'forget_me! clears remember token and expiration' do
    user = users(:founder)
    user.remember_me!
    assert user.remember_token.present?
    assert user.remember_token_expires_at.present?

    user.forget_me!

    assert user.remember_token.blank?
    assert user.remember_token_expires_at.blank?
    assert_not user.remember_token_valid?
  end

  test 'remember_token_valid? returns false for expired tokens' do
    user = users(:founder)
    user.remember_token = 'valid_token'
    user.remember_token_expires_at = 1.day.ago
    user.save!(validate: false)

    assert_not user.remember_token_valid?
  end

  test 'remember_token_valid? returns true for valid tokens' do
    user = users(:founder)
    user.remember_token = 'valid_token'
    user.remember_token_expires_at = 1.day.from_now
    user.save!(validate: false)

    assert user.remember_token_valid?
  end
end
