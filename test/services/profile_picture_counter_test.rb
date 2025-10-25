# frozen_string_literal: true

require 'test_helper'

class ProfilePictureCounterTest < ActiveSupport::TestCase
  setup do
    @practice = practices(:complete)
    @doctor = doctors(:rebecca)
    @patient = patients(:one)
  end

  teardown do
    purge_attachment(@doctor)
    purge_attachment(@patient)
  end

  test 'counts attachments for a single practice' do
    attach_picture(@doctor)
    attach_picture(@patient)

    counts = ProfilePictureCounter.counts_for_practices(@practice)

    assert_equal 2, counts[@practice.id]
    assert_equal 0, counts[9999]
  end

  test 'counts attachments when practice array provided' do
    attach_picture(@doctor)

    counts = ProfilePictureCounter.counts_for_practices([
                                                          @practice,
                                                          practices(:trialing_practice)
                                                        ])

    assert_equal 1, counts[@practice.id]
    assert_equal 0, counts[practices(:trialing_practice).id]
  end

  test 'instance count delegates to class method' do
    attach_picture(@doctor)
    attach_picture(@patient)

    assert_equal 2, ProfilePictureCounter.new(practice: @practice).count
  end

  private

  def attach_picture(record)
    record.profile_picture.attach(
      io: StringIO.new('binary-data'),
      filename: "#{record.class.name.underscore}.png",
      content_type: 'image/png'
    )
  end

  def purge_attachment(record)
    return unless record.profile_picture.attached?

    record.profile_picture.purge
  end
end
