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
end
