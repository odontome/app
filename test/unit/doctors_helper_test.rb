# frozen_string_literal: true

require 'test_helper'

class DoctorsHelperTest < ActionView::TestCase
  include DoctorsHelper

  test 'link_to_suspend_or_delete adds text-red without changing the given options' do
    options = { class: 'dropdown-item' }.freeze

    result = link_to_suspend_or_delete(doctors(:rebecca), options)

    assert_includes result, 'class="dropdown-item text-red"'
    assert_equal 'dropdown-item', options[:class]
  end
end
