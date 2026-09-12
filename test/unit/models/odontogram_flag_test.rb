# frozen_string_literal: true

require 'test_helper'

class OdontogramFlagTest < ActiveSupport::TestCase
  test 'new and existing practices default to disabled' do
    assert_equal false, Practice.new.odontogram_enabled
    assert_equal [false], Practice.distinct.pluck(:odontogram_enabled)
    column = Practice.columns_hash.fetch('odontogram_enabled')
    assert_not column.null
    assert_equal false, column.default
  end
end
