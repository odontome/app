# frozen_string_literal: true

require 'test_helper'

class InitialsTest < ActiveSupport::TestCase
  test 'returns uppercase initials from firstname and lastname' do
    user = users(:founder)
    assert_equal 'RR', user.initials
  end

  test 'works across all models that include the concern' do
    assert_equal 'RR', doctors(:rebecca).initials
    assert_equal 'EB', patients(:one).initials
  end

  test 'handles single character names' do
    user = User.new(firstname: 'A', lastname: 'B')
    assert_equal 'AB', user.initials
  end

  test 'handles lowercase names' do
    user = User.new(firstname: 'raul', lastname: 'riera')
    assert_equal 'RR', user.initials
  end

  test 'handles empty strings' do
    user = User.new(firstname: '', lastname: '')
    assert_equal '', user.initials
  end
end
