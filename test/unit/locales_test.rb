# frozen_string_literal: true

require 'test_helper'

class LocalesTest < ActiveSupport::TestCase
  test 'yes and no are translated in every locale' do
    %i[en es pt].each do |locale|
      assert I18n.exists?(:yes, locale), "missing :yes in #{locale}"
      assert I18n.exists?(:no, locale), "missing :no in #{locale}"
    end
  end
end
