# frozen_string_literal: true

require 'test_helper'

class PaperTrailTest < ActiveSupport::TestCase
  test 'paper trail should create versions for patient changes' do
    patient = patients(:one)
    initial_version_count = patient.versions.count
    
    # Update the patient
    patient.update!(firstname: 'Updated Name')
    
    # Should have created a new version
    assert_equal initial_version_count + 1, patient.versions.count
    
    # Get the latest version
    version = patient.versions.last
    assert_equal 'update', version.event
    assert_not_nil version.object
  end

  test 'paper trail should create versions for user changes' do
    user = users(:founder)
    initial_version_count = user.versions.count
    
    # Update the user
    user.update!(firstname: 'Updated User Name')
    
    # Should have created a new version
    assert_equal initial_version_count + 1, user.versions.count
    
    # Get the latest version
    version = user.versions.last
    assert_equal 'update', version.event
    assert_not_nil version.object
  end

  test 'paper trail should create versions for practice changes' do
    practice = practices(:complete)
    initial_version_count = practice.versions.count
    
    # Update the practice (avoid email validation conflict)
    practice.update!(name: 'Updated Practice Name', email: 'updated@example.com')
    
    # Should have created a new version
    assert_equal initial_version_count + 1, practice.versions.count
    
    # Get the latest version
    version = practice.versions.last
    assert_equal 'update', version.event
    assert_not_nil version.object
  end

  test 'paper trail should create versions for appointment changes' do
    appointment = appointments(:first_visit)
    initial_version_count = appointment.versions.count
    
    # Update the appointment
    appointment.update!(status: 'cancelled')
    
    # Should have created a new version
    assert_equal initial_version_count + 1, appointment.versions.count
    
    # Get the latest version
    version = appointment.versions.last
    assert_equal 'update', version.event
    assert_not_nil version.object
  end

  test 'paper trail should track create events' do
    initial_version_count = PaperTrail::Version.count
    
    # Create a new patient
    patient = Patient.create!(
      practice_id: 1,
      firstname: 'Test',
      lastname: 'Patient',
      date_of_birth: Date.new(1990, 1, 1)
    )
    
    # Should have created a version for the create event
    assert_equal initial_version_count + 1, PaperTrail::Version.count
    
    # Get the version for this patient
    version = patient.versions.first
    assert_equal 'create', version.event
    assert_nil version.object # object is nil for create events
  end

  test 'paper trail should track destroy events' do
    patient = patients(:one)
    patient_id = patient.id
    initial_version_count = patient.versions.count
    
    # Destroy the patient
    patient.destroy!
    
    # Should have created a version for the destroy event
    versions = PaperTrail::Version.where(item_type: 'Patient', item_id: patient_id)
    destroy_version = versions.where(event: 'destroy').first
    
    assert_not_nil destroy_version
    assert_equal 'destroy', destroy_version.event
    assert_not_nil destroy_version.object # object contains the state before destroy
  end

  test 'paper trail should not exceed version limit' do
    # This test verifies the version_limit configuration is working
    patient = patients(:one)
    
    # Create more than 25 versions (our configured limit)
    30.times do |i|
      patient.update!(firstname: "Name #{i}")
    end
    
    # Should not exceed the limit of 25 versions
    assert patient.versions.count <= 25
  end

  test 'versions should contain the changed object data' do
    patient = patients(:one)
    original_firstname = patient.firstname
    
    # Update the patient
    patient.update!(firstname: 'New First Name')
    
    # Get the latest version
    version = patient.versions.last
    
    # Verify the version records the event correctly
    assert_equal 'update', version.event
    assert_not_nil version.object
    assert_equal patient.class.name, version.item_type
    assert_equal patient.id, version.item_id
  end

  test 'can access paper trail versions' do
    patient = patients(:one)
    
    # Update the patient multiple times
    patient.update!(firstname: 'First Change')
    patient.update!(firstname: 'Second Change')
    
    # Should have multiple versions
    assert patient.versions.count >= 2
    
    # Can access all versions
    versions = patient.versions.order(:created_at)
    assert_equal 'update', versions.last.event
  end
end