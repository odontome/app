namespace :odontome do
  desc "Send appointment reminders to patients"
  task :send_appointments_notifications => :environment do

    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end

    to_update = []
    appointments = Appointment.includes(:doctor, :patient)
    .where("appointments.starts_at > ? AND appointments.ends_at < ? AND appointments.notified = ? 
                                      AND patients.email <> ''", 
                                      Time.now, Time.now + $appointment_notificacion_hours.hours, false)
    appointments.each do |appointment|
      PatientMailer.appointment_soon_email(appointment.patient.email, appointment.patient.fullname, appointment.starts_at, appointment.ends_at, appointment.practice.name, appointment.practice.locale, appointment.practice.timezone, appointment.doctor.fullname, appointment.practice.users.first.email).deliver

      to_update << appointment.id
    end
    Appointment.where(:id => to_update).update_all(:notified => true)
    
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