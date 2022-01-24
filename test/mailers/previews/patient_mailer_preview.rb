# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/patient_mailer
class PatientMailerPreview < ActionMailer::Preview
  def review_recent_appointment
    appointment = {
      'appointment_id' => 1,
      'patient_email' => 'raulriera@hotmail.com',
      'practice' => 'Bokanova Riviera Maya',
      'patient_name' => 'Raul'
    }

    PatientMailer.review_recent_appointment appointment
  end

  def appointment_scheduled_email
    doctor = Doctor.last
    PatientMailer.appointment_scheduled_email("rieraraul@gmail.com", "Raul Riera", 12.hours.from_now, 13.hours.from_now, "Odonto Dev Practice", "es", "Eastern Time (US & Canada)", doctor, "practice@practice.com")
  end
end
