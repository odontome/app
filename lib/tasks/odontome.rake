namespace :odontome do
  desc "Acciones de usuarios"
  task :send_appointments_notifications => :environment do
    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end
    to_update = []
    appointments = Appointment.includes(:patient)
    .where("appointments.starts_at > ? AND appointments.ends_at < ? AND appointments.notified = ? 
                                      AND patients.email <> ''", 
                                      Time.now, Time.now + $appointment_notificacion_hours.hours, false)
    appointments.each do |appointment|
      PatientMailer.appointment_soon_email(appointment.patient.email, appointment.patient.firstname,
                                           appointment.patient.lastname, appointment.starts_at, appointment.ends_at, 
                                           appointment.practice.name, appointment.practice.locale,
                                           appointment.doctor.firstname, appointment.doctor.lastname).deliver

      to_update << appointment.id
    end
    Appointment.where(:id => to_update).update_all(:notified => true)
  end
end