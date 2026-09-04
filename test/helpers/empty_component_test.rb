# frozen_string_literal: true

require 'test_helper'

class EmptyComponentTest < ActionView::TestCase
  test 'empty illustrations have explicit responsive dimensions' do
    render partial: 'components/empty', locals: {
      title: 'No appointments', description: 'Create an appointment', image_name: 'no-data.svg'
    }

    assert_select '.empty-img img[height="128"].mw-100.object-fit-contain', count: 1
  end
end
