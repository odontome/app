# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/patient_mailer
class PatientMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/patient_mailer/review_recent_appointment
  def review_recent_appointment
    appointment = {
      'appointment_id' => 1,
      'patient_email' => 'raulriera@hotmail.com',
      'practice' => 'Bokanova Riviera Maya',
      'patient_name' => 'Raul'
    }

    PatientMailer.review_recent_appointment appointment
  end
end
