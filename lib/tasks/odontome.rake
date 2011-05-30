namespace :odontome do
  desc "Acciones de usuarios"
  task :send_appointments_notifications => :environment do
    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end
    to_update = []
    appointments = Appointment.select("appointments.id, appointments.starts_at AS start, appointments.ends_at AS end, appointments.notified,
                                      appointments.patient_id, appointments.practice_id, patients.firstname AS patient_firstname, 
                                      patients.lastname AS patient_lastname, patients.email AS patient_email,
                                      practices.name AS practice_name, practices.locale AS practice_locale,
                                      doctors.firstname AS doctor_firstname, doctors.lastname AS doctor_lastname")
                                      .joins("LEFT OUTER JOIN patients ON patients.id = appointments.patient_id")
                                      .joins("LEFT OUTER JOIN practices ON practices.id = appointments.practice_id")
                                      .joins("LEFT OUTER JOIN doctors ON doctors.id = appointments.doctor_id")
                                      .where("appointments.starts_at > ? AND appointments.ends_at < ? AND appointments.notified = ? 
                                      AND patients.email <> ''", 
                                      Time.now, Time.now + $appointment_notificacion_hours.hours, false)
    appointments.each do |appointment|
      PatientMailer.appointment_soon_email(appointment.patient_email, appointment.patient_firstname,
                                           appointment.patient_lastname, appointment.start, appointment.end, 
                                           appointment.practice_name, appointment.practice_locale,
                                           appointment.doctor_firstname,appointment.doctor_lastname).deliver

      to_update << appointment.id
    end
    Appointment.where(:id => to_update).update_all(:notified => true)
  end
end