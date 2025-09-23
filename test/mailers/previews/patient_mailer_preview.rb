# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/patient_mailer
class PatientMailerPreview < ActionMailer::Preview
  def review_recent_appointment
    appointment = OpenStruct.new({
      'appointment_id' => 1,
      'patient_email' => 'raulriera@hotmail.com',
      'practice' => Practice.first || OpenStruct.new(name: 'Bokanova Riviera Maya', custom_review_url: nil, locale: 'es'),
      'patient_name' => 'Raul'
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
