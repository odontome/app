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
    assert user.remember_token_digest.blank?
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

    assert user.remember_token_digest.blank?
    assert user.remember_token_expires_at.blank?
    assert_not user.remember_token_valid?
  end

  test 'remember_token_valid? returns false for expired tokens' do
    user = users(:founder)
    user.update_columns(remember_token_digest: User.digest_remember_token('valid_token'),
                        remember_token_expires_at: 1.day.ago)

    assert_not user.remember_token_valid?
  end

  test 'remember_token_valid? returns true for valid tokens' do
    user = users(:founder)
    user.update_columns(remember_token_digest: User.digest_remember_token('valid_token'),
                        remember_token_expires_at: 1.day.from_now)

    assert user.remember_token_valid?
  end

  test 'should clear remember tokens when password is changed' do
    user = users(:founder)
    user.remember_me!
    assert user.remember_token.present?
    assert user.remember_token_expires_at.present?

    # Change password
    user.password = 'newpassword123'
    user.password_confirmation = 'newpassword123'
    user.save!

    # Reload to get fresh data
    user.reload
    assert user.remember_token_digest.blank?
    assert user.remember_token_expires_at.blank?
  end

  test 'cannot elevate roles to superadmin for new user' do
    user = User.new(firstname: 'New', lastname: 'User', email: 'new@odonto.me', roles: 'superadmin')
    user.password = '1234567890'
    user.password_confirmation = '1234567890'
    assert_not user.save
    assert_includes user.errors[:roles], I18n.t('errors.messages.unauthorised')
  end

  test 'cannot elevate existing non-superadmin to superadmin' do
    user = users(:founder)
    user.roles = 'superadmin'
    assert_not user.save
    assert_includes user.errors[:roles], I18n.t('errors.messages.unauthorised')
  end

  test 'allows persisting existing superadmin fixture' do
    user = users(:superadmin)
    user.firstname = 'Super'
    assert user.save
  end

  test 'admin user cannot be destroyed' do
    admin = users(:founder)

    assert_no_difference('User.count') do
      assert_not admin.destroy
    end
    assert_equal I18n.t('errors.messages.unauthorised'), admin.errors[:base].first
  end

  test 'changing the password gives the user a new session token' do
    user = users(:founder)
    user.update_columns(session_token: 'old-token')

    user.update!(password: 'brand-new-pass', password_confirmation: 'brand-new-pass')

    assert user.reload.session_token.present?
    assert_not_equal 'old-token', user.session_token
  end

  test 'updating other details keeps the session token' do
    user = users(:founder)
    user.update_columns(session_token: 'old-token')

    user.update!(firstname: 'Raulito')

    assert_equal 'old-token', user.reload.session_token
  end

  test 'session_token_matches? compares against the current token' do
    user = users(:founder)
    user.update_columns(session_token: 'current-token')

    assert user.session_token_matches?('current-token')
    assert_not user.session_token_matches?('old-token')
    assert_not user.session_token_matches?(nil)
  end

  test 'session_token_matches? accepts sessions of users who have no token yet' do
    user = users(:founder)
    user.update_columns(session_token: nil)

    assert user.session_token_matches?(nil)
  end

  test 'ensure_session_token! only fills in a missing token' do
    user = users(:founder)
    user.update_columns(session_token: nil)

    user.ensure_session_token!
    token = user.reload.session_token
    assert token.present?

    user.ensure_session_token!
    assert_equal token, user.reload.session_token
  end

  test 'remember_me! stores only a digest of the token' do
    user = users(:founder)

    user.remember_me!
    raw_token = user.remember_token

    stored = User.find(user.id)
    assert_nil stored.remember_token
    assert_equal User.digest_remember_token(raw_token), stored.remember_token_digest
    assert_not_equal raw_token, stored.remember_token_digest
  end

  test 'find_by_remember_token finds the user by the raw token only' do
    user = users(:founder)
    user.remember_me!
    raw_token = user.remember_token

    assert_equal user, User.find_by_remember_token(raw_token)
    assert_nil User.find_by_remember_token(user.reload.remember_token_digest)
    assert_nil User.find_by_remember_token(nil)
  end

  test 'changing the email notifies the previous address' do
    user = users(:founder)
    previous_email = user.email

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      user.update!(email: 'new-address@odonto.me')
    end

    assert_equal [previous_email], ActionMailer::Base.deliveries.last.to
  end

  test 'updating other fields does not send an email changed notice' do
    user = users(:founder)

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.update!(firstname: 'Raúl')
    end
  end
end
