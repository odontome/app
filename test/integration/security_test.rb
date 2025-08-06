# frozen_string_literal: true

require 'test_helper'

class SecurityTest < ActionDispatch::IntegrationTest
  test "should sanitize patient allergies field to prevent XSS" do
    practice = Practice.create!(
      name: 'Test Practice',
      email: 'test@example.com',
      locale: 'en',
      timezone: 'UTC'
    )
    
    user = User.create!(
      firstname: 'Test',
      lastname: 'User',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      practice: practice,
      roles: 'admin'
    )
    
    patient = Patient.create!(
      firstname: 'Test',
      lastname: 'Patient',
      date_of_birth: 20.years.ago,
      practice: practice,
      allergies: '<script>alert("XSS")</script>Peanuts'
    )
    
    # Login as user
    post '/user_session', params: {
      signin: {
        email: user.email,
        password: 'password123'
      }
    }
    
    # Visit patient page
    get patient_path(patient)
    assert_response :success
    
    # Verify that script tags are stripped
    assert_not_includes response.body, '<script>'
    assert_includes response.body, 'Peanuts'
  end
  
  test "should sanitize note content to prevent XSS" do
    practice = Practice.create!(
      name: 'Test Practice',
      email: 'test@example.com',
      locale: 'en',
      timezone: 'UTC'
    )
    
    user = User.create!(
      firstname: 'Test',
      lastname: 'User',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      practice: practice,
      roles: 'admin'
    )
    
    patient = Patient.create!(
      firstname: 'Test',
      lastname: 'Patient',
      date_of_birth: 20.years.ago,
      practice: practice
    )
    
    note = Note.create!(
      notes: '<script>alert("XSS")</script>Patient seems fine',
      noteable: patient,
      user: user
    )
    
    # Login as user
    post '/user_session', params: {
      signin: {
        email: user.email,
        password: 'password123'
      }
    }
    
    # Visit patient page with note
    get patient_path(patient)
    assert_response :success
    
    # Verify that script tags are stripped from notes
    assert_not_includes response.body, '<script>'
    assert_includes response.body, 'Patient seems fine'
  end
  
  test "should use secure session handling" do
    practice = Practice.create!(
      name: 'Test Practice',
      email: 'test@example.com',
      locale: 'en',
      timezone: 'UTC'
    )
    
    user = User.create!(
      firstname: 'Test',
      lastname: 'User', 
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      practice: practice,
      roles: 'admin'
    )
    
    # Login as user
    post '/user_session', params: {
      signin: {
        email: user.email,
        password: 'password123'
      }
    }
    
    # Verify session is properly structured
    session_user = session[:user]
    assert session_user.is_a?(Hash)
    assert_equal user.id, session_user['id']
    assert_nil session_user['password_digest']  # Ensure password not in session
  end
end