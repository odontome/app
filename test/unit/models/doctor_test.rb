# frozen_string_literal: true

require 'test_helper'
require 'active_job/test_helper'

class DoctorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end
  test 'doctor attributes must not be empty' do
    doctor = Doctor.new
    assert doctor.invalid?
    assert doctor.errors[:practice_id].any?
    assert doctor.errors[:firstname].any?
    assert doctor.errors[:lastname].any?
  end

  test 'doctor is not valid without a valid email address' do
    doctor = doctors(:rebecca)
    doctor.email = 'notvalid@'

    assert !doctor.save
    assert_equal I18n.t('errors.messages.invalid'), doctor.errors[:email].first
  end

  test 'doctor is not valid without an unique uid in the same practice' do
    users(:founder).authenticate('1234567890')

    doctor = Doctor.new(uid: 'D001',
                        practice_id: 1,
                        firstname: 'Daniella',
                        lastname: 'Sanguino')

    assert !doctor.save
    assert_equal I18n.t('errors.messages.taken'), doctor.errors[:uid].first
  end

  test 'doctor is not valid without an unique email in the same practice' do
    doctor = doctors(:rebecca)
    doctor.email = doctors(:perishable).email

    assert !doctor.save
    assert_equal I18n.t('errors.messages.taken'), doctor.errors[:email].first
  end

  test 'doctor uid must be between 0 and 25 characters' do
    doctor = doctors(:rebecca)
    doctor.uid = '00001111222233334444555666677778888'

    assert !doctor.save
    assert_equal I18n.t('errors.messages.too_long', count: 25), doctor.errors[:uid].first
  end

  test 'doctor specialty must be between 0 and 50 characters' do
    doctor = doctors(:rebecca)
    doctor.speciality = 'A really long doctors specialty he treats everyone with real care and has study many fields of medicine and destistry'

    assert !doctor.save
    assert_equal I18n.t('errors.messages.too_long', count: 50), doctor.errors[:speciality].first
  end

  test 'doctor fullname shortcut' do
    doctor = doctors(:rebecca)

    assert_equal doctor.fullname, "#{I18n.t('female_doctor_prefix')} #{doctor.firstname} #{doctor.lastname}"
  end

  test 'doctors can not be deleted with associated appointments' do
    doctor = doctors(:rebecca)

    assert !doctor.is_deleteable
  end

  test 'doctor name can be used as initials' do
    doctor = Doctor.new(firstname: 'Ruth', lastname: 'Roberts')

    assert_equal doctor.initials, 'RR'
  end

  test 'destroying doctor purges profile picture attachment' do
    doctor = Doctor.create!(
      practice: practices(:complete),
      firstname: 'Delete',
      lastname: 'Asset',
      email: 'delete.asset@example.com'
    )

    doctor.profile_picture.attach(
      io: StringIO.new('image-data'),
      filename: 'avatar.png',
      content_type: 'image/png'
    )

    attachment = doctor.profile_picture.attachment
    blob = attachment.blob

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      assert_difference -> { ActiveStorage::Blob.count }, -1 do
        perform_enqueued_jobs only: ActiveStorage::PurgeJob do
          doctor.destroy
        end
      end
    end

    refute ActiveStorage::Attachment.exists?(attachment.id)
    refute ActiveStorage::Blob.exists?(blob.id)
  end
end
