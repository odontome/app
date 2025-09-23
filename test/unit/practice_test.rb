# frozen_string_literal: true

require 'test_helper'

class PracticeTest < ActiveSupport::TestCase
  test 'practice attributes must not be empty' do
    practice = Practice.new
    practice.users << User.new

    assert practice.invalid?
    assert practice.errors[:name].any?
  end

  test 'practice is created with a active status as default' do
    practice = Practice.new
    practice.users << User.new

    assert practice.invalid?
    assert_equal practice.status, 'active'
  end

  test 'practice can be set to cancelled' do
    practice = Practice.new
    practice.users << User.new

    practice.set_as_cancelled

    assert_equal practice.status, 'cancelled'
  end

  test 'practice has_connect_account? returns false when no account' do
    practice = Practice.new
    assert_not practice.has_connect_account?
  end

  test 'practice has_connect_account? returns true when account exists' do
    practice = Practice.new
    practice.stripe_account_id = 'acct_test123'
    assert practice.has_connect_account?
  end

  test 'practice connect_account_complete? returns false when not enabled' do
    practice = Practice.new
    practice.stripe_account_id = 'acct_test123'
    practice.connect_charges_enabled = false
    practice.connect_payouts_enabled = false
    assert_not practice.connect_account_complete?
  end

  test 'practice connect_account_complete? returns true when fully enabled' do
    practice = Practice.new
    practice.stripe_account_id = 'acct_test123'
    practice.connect_charges_enabled = true
    practice.connect_payouts_enabled = true
    assert practice.connect_account_complete?
  end

  test 'practice sets the first user name' do
    practice = Practice.new
    practice.users << User.new

    assert practice.invalid?
    assert_equal practice.users.first.firstname, I18n.t(:administrator)
    assert_equal practice.users.first.lastname, I18n.t(:user).downcase
  end

  test 'practice is created with a default datebook' do
    practice = Practice.new(name: 'Testing')
    practice.users << User.new(firstname: 'Firstname', lastname: 'Lastname', email: 'testing@odonto.me',
                               password: '1234567', password_confirmation: '1234567')

    assert practice.save
    assert_equal practice.datebooks.first.name, 'Your first datebook'
  end

  test 'practice is created with an trial subscription' do
    practice = Practice.new(name: 'Testing')
    practice.users << User.new(firstname: 'Firstname', lastname: 'Lastname', email: 'testing@odonto.me',
                               password: '1234567', password_confirmation: '1234567')

    assert practice.save
    assert_equal practice.subscription.status, 'trialing'
    assert_nil practice.stripe_customer_id
  end

  test 'practice allows blank custom_review_url' do
    practice = practices(:complete)
    practice.custom_review_url = ''
    assert practice.valid?
    
    practice.custom_review_url = nil
    assert practice.valid?
  end

  test 'practice validates custom_review_url format' do
    practice = practices(:complete)
    
    # Valid URLs
    practice.custom_review_url = 'https://example.com/reviews'
    assert practice.valid?
    
    practice.custom_review_url = 'http://example.com/reviews'
    assert practice.valid?
    
    # Invalid URLs
    practice.custom_review_url = 'not-a-url'
    assert practice.invalid?
    assert practice.errors[:custom_review_url].any?
    
    practice.custom_review_url = 'ftp://example.com'
    assert practice.invalid?
    assert practice.errors[:custom_review_url].any?
  end
end
