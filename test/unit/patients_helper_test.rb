# frozen_string_literal: true

require 'test_helper'

class PatientsHelperTest < ActionView::TestCase
  include PatientsHelper

  test 'letter_options flags letters with patients in current practice' do
    def current_user
      users(:founder)
    end

    options = letter_options

    assert_equal 26, options.count

    present_initial = options.find { |option| option[:value] == 'E' }
    missing_initial = options.find { |option| option[:value] == 'Z' }

    assert present_initial[:included?]
    refute missing_initial[:included?]
  end
end
