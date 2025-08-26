# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "should return 'active' when controller name matches string tab" do
    def controller
      OpenStruct.new(controller_name: 'patients')
    end

    assert_equal 'active', is_active_tab?('patients')
    assert_equal '', is_active_tab?('datebooks')
  end

  test "should return 'active' when controller name matches one tab in array" do
    def controller
      OpenStruct.new(controller_name: 'doctors')
    end

    assert_equal 'active', is_active_tab?(%i[patients doctors treatments])
    assert_equal '', is_active_tab?(%i[users])
  end

  test 'should throw an error for invalid tab' do
    assert_raises(RuntimeError) do
      is_active_tab?('invalid_tab')
    end
  end
end
