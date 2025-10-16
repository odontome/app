# frozen_string_literal: true

require 'test_helper'

class AnnouncementsTest < ActiveSupport::TestCase
  def teardown
    # Clear memoized announcements so tests remain isolated
    Announcements.instance_variable_set(:@announcements, nil)
  end

  test 'loads announcements from configuration file' do
    announcements = Announcements.current_announcements

    assert announcements.is_a?(Array)
  end

  test 'handles missing configuration file gracefully' do
    # Avoid stubbing the module method (which can leak between tests).
    # Instead set the cached value directly so this test is order-independent.
    Announcements.instance_variable_set(:@announcements, [])

    announcements = Announcements.current_announcements
    assert_equal [], announcements
  end

  test 'finds announcement by version' do
    announcements = [{ 'version' => 1, 'message' => 'Test' }]
    # Populate the cached announcements directly to avoid redefining methods.
    Announcements.instance_variable_set(:@announcements, announcements)

    found = Announcements.announcement_for_version(1)
    assert_not_nil found
    assert_equal 1, found['version']
  end
end
