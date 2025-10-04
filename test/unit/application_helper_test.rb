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

  test 'avatar_for renders image when profile picture present' do
    record_class = Struct.new(:fullname, :profile_picture_url) do
      def profile_picture_resized(width:, height:)
        "#{profile_picture_url}?w=#{width}&h=#{height}"
      end

      def initials
        'DW'
      end
    end
    record = record_class.new('Dr. Who', 'https://example.com/pic.png')

    html = avatar_for(record, size: 128, classes: 'avatar test-class')

    assert_includes html, '<img'
    assert_includes html, 'class="avatar test-class"'
    assert_includes html, 'w=128'
    assert_includes html, %(alt="#{I18n.t(:profile_picture_alt, name: 'Dr. Who')}")
  end

  test 'avatar_for falls back to initials without profile picture' do
    record_class = Struct.new(:fullname) do
      def initials
        ''
      end
    end
    record = record_class.new('Jane Doe')

    html = avatar_for(record)

    assert_includes html, '<span'
    assert_includes html, 'class="avatar rounded-circle"'
    assert_includes html, '>JD<'
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
