# frozen_string_literal: true

require 'ostruct'

# Preview all emails at http://localhost:3000/rails/mailers/patient_mailer
class PatientMailerPreview < ActionMailer::Preview
  def review_recent_appointment
    # Get a practice to use for the preview (without custom URL)
    if Practice.any? && Practice.first.respond_to?(:custom_review_url)
      practice = Practice.first
      practice.custom_review_url = nil if practice.custom_review_url.present? # Reset for this preview
    else
      # Fallback for when no practices exist or migration hasn't run
      practice = OpenStruct.new(
        name: 'Demo Practice',
        custom_review_url: nil,
        locale: 'en',
        timezone: 'UTC',
        email: 'practice@example.com'
      )
    end
    
    appointment = OpenStruct.new({
      'appointment_id' => 1,
      'patient_email' => 'patient@example.com',
      'practice' => practice,
      'patient_name' => 'John Smith',
      'practice_locale' => practice.respond_to?(:locale) ? practice.locale : 'en'
    })

    PatientMailer.review_recent_appointment appointment
  end

  def review_recent_appointment_with_custom_url
    # Practice with custom review URL to demonstrate hybrid routing
    if Practice.any? && Practice.first.respond_to?(:custom_review_url)
      practice = Practice.first.dup
      practice.custom_review_url = 'https://g.page/demo-practice/review'
    else
      # Fallback for when no practices exist or migration hasn't run
      practice = OpenStruct.new(
        name: 'Demo Practice with Custom Reviews',
        custom_review_url: 'https://g.page/demo-practice/review',
        locale: 'en',
        timezone: 'UTC',
        email: 'practice@example.com'
      )
    end
    
    appointment = OpenStruct.new({
      'appointment_id' => 2,
      'patient_email' => 'patient@example.com',
      'practice' => practice,
      'patient_name' => 'Jane Doe',
      'practice_locale' => practice.respond_to?(:locale) ? practice.locale : 'en'
    })

    PatientMailer.review_recent_appointment appointment
  end

  def appointment_scheduled_email
    doctor = Doctor.last
    PatientMailer.appointment_scheduled_email("rieraraul@gmail.com", "Raul Riera", 12.hours.from_now, 13.hours.from_now, "Odonto Dev Practice", "es", "Eastern Time (US & Canada)", doctor, "practice@practice.com")
  end

  def appointment_soon_email
    doctor = Doctor.last
    PatientMailer.appointment_soon_email("patient@example.com", "John Doe", 24.hours.from_now, 25.hours.from_now, "Dental Practice Example", "en", "Eastern Time (US & Canada)", doctor, "practice@example.com")
  end

  def six_month_checkup_reminder_en
    PatientMailer.six_month_checkup_reminder(
      "patient@example.com",
      "John Doe",
      "Dental Practice Example",
      "en",
      "Eastern Time (US & Canada)",
      "practice@example.com"
    )
  end

  def six_month_checkup_reminder_es
    PatientMailer.six_month_checkup_reminder(
      "paciente@example.com",
      "Juan Pérez",
      "Clínica Dental Ejemplo",
      "es",
      "Eastern Time (US & Canada)",
      "practica@example.com"
    )
  end
end
