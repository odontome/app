# frozen_string_literal: true

require 'test_helper'

class PaperTrailIntegrationTest < ActiveSupport::TestCase
  def setup
    @practice = practices(:complete)
    @user = users(:founder)
    @patient = patients(:one)
  end

  test "should create version when patient is updated" do
    PaperTrail.request.whodunnit = @user.id
    PaperTrail.request.controller_info = { 
      practice_id: @practice.id,
      user_agent: 'Test Agent',
      remote_ip: '127.0.0.1'
    }
    
    original_firstname = @patient.firstname
    
    assert_difference('PaperTrail::Version.count', 1) do
      @patient.update!(firstname: 'Updated Name')
    end
    
    version = PaperTrail::Version.last
    assert_equal 'Patient', version.item_type
    assert_equal @patient.id, version.item_id
    assert_equal 'update', version.event
    assert_equal @user.id.to_s, version.whodunnit
    assert_equal @practice.id, version.practice_id
    
    changeset = version.changeset
    assert_equal original_firstname, changeset['firstname'][0]
    assert_equal 'Updated Name', changeset['firstname'][1]
  end

  test "should create version when user is created" do
    PaperTrail.request.whodunnit = @user.id
    PaperTrail.request.controller_info = { 
      practice_id: @practice.id,
      user_agent: 'Test Agent',
      remote_ip: '127.0.0.1'
    }
    
    assert_difference('PaperTrail::Version.count', 1) do
      User.create!(
        practice: @practice,
        firstname: 'Test',
        lastname: 'User',
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        roles: 'user'
      )
    end
    
    version = PaperTrail::Version.last
    assert_equal 'User', version.item_type
    assert_equal 'create', version.event
    assert_equal @user.id.to_s, version.whodunnit
    assert_equal @practice.id, version.practice_id
  end

  test "should create version when appointment is deleted" do
    appointment = appointments(:first_visit)
    
    PaperTrail.request.whodunnit = @user.id
    PaperTrail.request.controller_info = { 
      practice_id: @practice.id,
      user_agent: 'Test Agent',
      remote_ip: '127.0.0.1'
    }
    
    assert_difference('PaperTrail::Version.count', 1) do
      appointment.destroy!
    end
    
    version = PaperTrail::Version.last
    assert_equal 'Appointment', version.item_type
    assert_equal appointment.id, version.item_id
    assert_equal 'destroy', version.event
    assert_equal @user.id.to_s, version.whodunnit
  end

  test "should scope versions by practice_id" do
    # Create versions for different practices
    patient1 = patients(:one) # practice_id: 1
    patient2 = patients(:three) # practice_id: 3
    
    PaperTrail.request.whodunnit = @user.id
    
    # Update patient in practice 1
    PaperTrail.request.controller_info = { practice_id: 1 }
    patient1.update!(firstname: 'Updated 1')
    
    # Update patient in practice 3
    PaperTrail.request.controller_info = { practice_id: 3 }
    patient2.update!(firstname: 'Updated 3')
    
    practice1_versions = PaperTrail::Version.where(practice_id: 1)
    practice3_versions = PaperTrail::Version.where(practice_id: 3)
    
    assert practice1_versions.exists?
    assert practice3_versions.exists?
    
    # Ensure versions are properly scoped
    assert practice1_versions.all? { |v| v.practice_id == 1 }
    assert practice3_versions.all? { |v| v.practice_id == 3 }
  end

  test "should not track versions when PaperTrail is disabled" do
    PaperTrail.enabled = false
    
    assert_no_difference('PaperTrail::Version.count') do
      @patient.update!(firstname: 'No Version Should Be Created')
    end
    
    PaperTrail.enabled = true
  end
end