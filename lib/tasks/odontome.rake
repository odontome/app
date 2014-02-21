namespace :odontome do
  desc "Send appointment reminders to patients"
  task :send_appointment_reminder_notifications => :environment do

    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end

    to_update = []
    appointments = Appointment.includes(:doctor, :patient)
    .where("appointments.starts_at > ? AND appointments.ends_at < ? AND appointments.notified_of_reminder = ? 
                                      AND patients.email <> ''", 
                                      Time.now, Time.now + $appointment_notificacion_hours.hours, false)
    appointments.each do |appointment|
      practice = appointment.datebook.practice

      PatientMailer.appointment_soon_email(appointment.patient.email, appointment.patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, appointment.doctor.fullname, practice.users.first.email).deliver

      to_update << appointment.id
    end
    Appointment.where(:id => to_update).update_all(:notified_of_reminder => true)
    
  end

  desc "Send appointment schedule notification to patients"
  task :send_appointment_scheduled_notifications => :environment do
    
    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end

    to_update = []
    appointments = Appointment.includes(:doctor, :patient)
    .where("appointments.created_at < ? AND appointments.created_at > ? AND appointments.notified_of_schedule = ? 
                                      AND patients.email <> ''", 
                                      10.minutes.ago, 30.minutes.ago, false)
    appointments.each do |appointment|
      practice = appointment.datebook.practice
      passbook_url = appointment.ciphered_url

      PatientMailer.appointment_scheduled_email(appointment.patient.email, appointment.patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, appointment.doctor.fullname, practice.users.first.email, passbook_url).deliver

      to_update << appointment.id
    end

    Appointment.where(:id => to_update).update_all(:notified_of_schedule => true)
  end

  desc "Delete practices cancelled more than 15 days ago"
  task :delete_practices_cancelled_a_while_ago => :environment do
    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end

    practices = Practice.where("cancelled_at < ?", 15.days.ago)

    practices.each do |practice|
      practice.destroy
    end

  end

end