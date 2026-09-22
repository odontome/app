# frozen_string_literal: true

require 'test_helper'
require 'base64'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  SAMPLE_PNG_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+rXbQAAAAASUVORK5CYII='

  test 'connect account status i18n covers every status in every locale' do
    statuses = %w[not_started pending pending_review complete disabled something_unexpected]

    %i[en es pt].each do |locale|
      I18n.with_locale(locale) do
        statuses.each do |status|
          result = connect_account_status_i18n(status)

          assert_kind_of Hash, result, "expected a Hash for '#{status}' in #{locale}"
          assert result[:title].present?, "missing title for '#{status}' in #{locale}"
        end
      end
    end
  end

  test "should return 'active' when controller name matches string tab" do
    def controller
      OpenStruct.new(controller_name: 'patients')
    end

    assert_equal 'active', is_active_tab?('patients')
    assert_equal '', is_active_tab?('datebooks')
  end

  test 'avatar_for renders image when profile picture present' do
    doctor = doctors(:rebecca)
    doctor.profile_picture.attach(
      io: StringIO.new(Base64.decode64(SAMPLE_PNG_BASE64)),
      filename: 'avatar.png',
      content_type: 'image/png'
    )

    html = avatar_for(doctor, variant: :medium, classes: 'avatar test-class')

    assert_includes html, '<img'
    assert_includes html, 'class="avatar test-class"'
    assert_match %r{src="(?:https?://[^"/]+)?/rails/active_storage/representations/}, html
    assert_includes html, %(alt="#{I18n.t(:profile_picture_alt, name: doctor.fullname)}")
  ensure
    doctor.profile_picture.purge if doctor.profile_picture.attached?
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
    assert_includes html, 'class="avatar me-2 rounded-circle"'
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
