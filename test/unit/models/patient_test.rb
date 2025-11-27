# frozen_string_literal: true

require 'test_helper'

class PatientTest < ActiveSupport::TestCase
  test 'patient attributes must not be empty' do
    patient = Patient.create

    assert patient.invalid?
    assert patient.errors[:practice_id].any?
    assert patient.errors[:firstname].any?
    assert patient.errors[:lastname].any?
    assert patient.errors[:date_of_birth].any?
  end

  test 'patient is not valid without an unique uid in the same practice' do
    users(:founder).authenticate('1234567890')

    patient = Patient.new(uid: 0o001,
                          practice_id: 1,
                          firstname: 'Daniella',
                          lastname: 'Sanguino')

    assert !patient.save
    assert_equal I18n.t('errors.messages.taken'), patient.errors[:uid].first
  end

  test 'patient is not valid without an unique email in the same practice' do
    patient = patients(:two)
    patient.email = patients(:four).email

    assert !patient.save
    assert_equal I18n.t('errors.messages.taken'), patient.errors[:email].first
  end

  test 'patient vices must be numbers' do
    patient = patients(:two)

    patient.cigarettes_per_day = 'none'
    patient.drinks_per_day = 'not a sip'

    assert !patient.save
    assert_equal I18n.t('errors.messages.not_a_number'), patient.errors[:cigarettes_per_day].join('; ')
    assert_equal I18n.t('errors.messages.not_a_number'), patient.errors[:drinks_per_day].join('; ')
  end

  test 'patient vices must be valid integers' do
    patient = patients(:two)

    patient.cigarettes_per_day = 0.5
    patient.drinks_per_day = 0.75

    assert !patient.save
    assert_equal I18n.t('errors.messages.not_an_integer'), patient.errors[:cigarettes_per_day].join('; ')
    assert_equal I18n.t('errors.messages.not_an_integer'), patient.errors[:drinks_per_day].join('; ')
  end

  test 'patient vices must be greater than or equal to zero' do
    patient = patients(:two)

    patient.cigarettes_per_day = -5
    patient.drinks_per_day = -2

    assert !patient.save
    assert_equal I18n.t('errors.messages.greater_than_or_equal_to', count: 0),
                 patient.errors[:cigarettes_per_day].join('; ')
    assert_equal I18n.t('errors.messages.greater_than_or_equal_to', count: 0),
                 patient.errors[:drinks_per_day].join('; ')
  end

  test 'patient uid must be between 0 and 25 characters' do
    patient = patients(:one)
    patient.uid = '00001111222233334444555666677778888'

    assert !patient.save
    assert_equal I18n.t('errors.messages.too_long', count: 25), patient.errors[:uid].join('; ')
  end

  test 'patient name must be between 1 and 25 characters' do
    patient = patients(:one)
    patient.firstname = 'A really long name that nobody will really use'
    patient.lastname = 'A really long last name as well really weird'

    assert !patient.save
    assert_equal I18n.t('errors.messages.too_long', count: 25), patient.errors[:firstname].join('; ')
    assert_equal I18n.t('errors.messages.too_long', count: 25), patient.errors[:lastname].join('; ')
  end

  test 'patient address must be between 0 and 100 characters' do
    patient = patients(:one)
    patient.address = 'A really long address, maybe this guy lives somewhere in Venezuela where the addresses are just insanely huge!'

    assert !patient.save
    assert_equal I18n.t('errors.messages.too_long', count: 100), patient.errors[:address].join('; ')
  end

  test 'patient phone numbers must be between 0 and 20 characters' do
    patient = patients(:one)
    patient.telephone = '+3491456789876456667890'
    patient.mobile = '+346645678987645643689032'

    assert !patient.save
    assert_equal I18n.t('errors.messages.too_long', count: 20), patient.errors[:telephone].join('; ')
    assert_equal I18n.t('errors.messages.too_long', count: 20), patient.errors[:mobile].join('; ')
  end

  test 'patient emergency telephone must be at least 5 characters long' do
    patient = patients(:one)
    patient.emergency_telephone = '0000'

    assert !patient.save
    assert_equal I18n.t('errors.messages.too_short', count: 5), patient.errors[:emergency_telephone].join('; ')
  end

  test 'patient emergency telephone must be a maximum of 20 chars long' do
    patient = patients(:one)
    patient.emergency_telephone = '+346645678987645643689032'

    assert !patient.save
    assert_equal I18n.t('errors.messages.too_long', count: 20), patient.errors[:emergency_telephone].join('; ')
  end

  test 'patient is not valid without a valid email address' do
    patient = patients(:one)
    patient.email = 'notvalid@'

    assert !patient.save
    assert_equal I18n.t('errors.messages.invalid'), patient.errors[:email].first
  end

  test 'patient fullname shortcut' do
    patient = patients(:one)
    another_patient = Patient.new(fullname: 'Daniella Sanguino')

    assert_equal patient.fullname, "#{patient.firstname} #{patient.lastname}"
    assert_equal "#{another_patient.firstname} #{another_patient.lastname}", another_patient.fullname
  end

  test 'patient age' do
    patient = patients(:one)

    assert patient.age.integer?
    assert patient.age.positive?
  end

  test 'patient is invalid if it has no date of birth' do
    patient = patients(:one)
    patient.date_of_birth = nil

    assert patient.invalid?
  end

  test 'patient firstname, and lastname will be squished' do
    patient = Patient.new(firstname: ' Peter ', lastname: ' Lopez ', practice_id: 1, date_of_birth: '1982-12-22')

    assert patient.save
    assert_equal patient.firstname, 'Peter'
    assert_equal patient.lastname, 'Lopez'
  end

  test 'patient fullname search is assigned automatically' do
    patient = Patient.create!(firstname: ' Carla ', lastname: 'Jones', practice_id: 1, date_of_birth: '1980-01-01')

    assert_equal 'carla jones', patient.fullname_search
  end

  test 'anything_with_letter scope filters by stored initial' do
    result_ids = Patient.anything_with_letter('E').map(&:id)

    assert_includes result_ids, patients(:one).id
  end

  test 'anything_not_in_alphabet scope returns non letter initials' do
    patient = Patient.create!(firstname: '9Lives', lastname: 'Cat', practice_id: 1, date_of_birth: '1990-01-01')

    assert_includes Patient.anything_not_in_alphabet.map(&:id), patient.id
  end

  test 'search scope matches normalized fullname' do
    results = Patient.search('BRI')

    assert_includes results.map(&:id), patients(:one).id
  end

  test 'patient name can be used as initials' do
    patient = Patient.new(firstname: 'Antonio', lastname: 'Santos')
    patient_empty_firstname = Patient.new(firstname: '', lastname: 'Santos')
    patient_empty_lastname = Patient.new(firstname: 'Antonio', lastname: '')

    assert_equal patient.initials, 'AS'
    assert_equal patient_empty_firstname.initials, 'S'
    assert_equal patient_empty_lastname.initials, 'A'
  end

  test 'find_or_create_from sets search fields when creating new patient' do
    practice_id = practices(:complete).id
    patient_id = Patient.find_or_create_from('Maria Garcia'.dup, practice_id)
    patient = Patient.find(patient_id)

    assert_equal 'Maria', patient.firstname
    assert_equal 'Garcia', patient.lastname
    assert_equal 'm', patient.firstname_initial, 'firstname_initial should be set for index lookup'
    assert_equal 'maria garcia', patient.fullname_search, 'fullname_search should be set for search'
  end

  test 'find_or_create_from patient is findable by anything_with_letter scope' do
    practice_id = practices(:complete).id
    patient_id = Patient.find_or_create_from('Carlos Rodriguez'.dup, practice_id)

    result_ids = Patient.anything_with_letter('C').with_practice(practice_id).map(&:id)

    assert_includes result_ids, patient_id, 'Patient created via find_or_create_from should appear in letter index'
  end

  test 'find_or_create_from patient is findable by search scope' do
    practice_id = practices(:complete).id
    patient_id = Patient.find_or_create_from('Sofia Martinez'.dup, practice_id)

    result_ids = Patient.search('Sofia').with_practice(practice_id).map(&:id)

    assert_includes result_ids, patient_id, 'Patient created via find_or_create_from should be searchable'
  end
end
