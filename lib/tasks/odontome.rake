# frozen_string_literal: true

namespace :odontome do
  desc 'Send appointment reminders to patients'
  task send_appointment_reminder_notifications: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    to_update = []
    appointment_notificacion_hours = 48.hours

    appointments = Appointment.includes(:doctor, :patient).joins(:doctor, :patient)
                              .where('appointments.starts_at > ? AND appointments.ends_at < ?', Time.now, Time.now + appointment_notificacion_hours)
                              .where('appointments.notified_of_reminder = ?', false)
                              .where("patients.email <> ''")
                              .where('appointments.status = ?', Appointment.status[:confirmed])

    appointments.each do |appointment|
      practice = appointment.datebook.practice

      PatientMailer.appointment_soon_email(appointment.patient.email, appointment.patient.fullname,
                                           appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, appointment.doctor, practice.email).deliver_now

      to_update << appointment.id
    end
    Appointment.where(id: to_update).update_all(notified_of_reminder: true)
  end

  desc 'Send appointment schedule notification to patients'
  task send_appointment_scheduled_notifications: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    to_update = []

    appointments = Appointment.includes(:doctor, :patient).joins(:doctor, :patient)
                              .where('appointments.created_at < ? AND appointments.notified_of_schedule = ?', 5.minutes.ago, false)
                              .where('appointments.status = ?', Appointment.status[:confirmed])
                              .where("patients.email <> ''")

    appointments.each do |appointment|
      practice = appointment.datebook.practice

      PatientMailer.appointment_scheduled_email(appointment.patient.email, appointment.patient.fullname,
                                                appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, appointment.doctor, practice.email).deliver_now

      to_update << appointment.id
    end

    Appointment.where(id: to_update).update_all(notified_of_schedule: true)
  end

  desc 'Delete practices cancelled more than 15 days ago'
  task delete_practices_cancelled_a_while_ago: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    practices = Practice.where('cancelled_at < ?', 15.days.ago)
    practices.destroy_all
  end

  desc "Send today's appointments everyday in their timezone"
  task send_todays_appointments_to_doctors: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    # configuration
    hour_to_send_emails = 7
    timezones_where_hour_is = timezones_where_hour_are(hour_to_send_emails)
    practice_ids = practices_in_timezones(timezones_where_hour_is)

    if practice_ids.size.positive?
      today = Time.now.in_time_zone(timezones_where_hour_is.first).beginning_of_day
      end_of_today = today.end_of_day

      appointments_scheduled_for_today = Datebook.select('practices.name as practice, datebooks.practice_id, datebooks.name as datebook, appointments.starts_at, appointments.ends_at, appointments.notes, doctors.id as doctor_id, doctors.firstname as doctor_firstname, doctors.lastname as doctor_lastname, doctors.email as doctor_email, patients.firstname as patient_firstname, patients.lastname as patient_lastname')
                                                 .where("doctors.email <> ''")
                                                 .where('datebooks.practice_id' => practice_ids)
                                                 .where('appointments.starts_at >= ? AND appointments.ends_at <= ?', today, end_of_today)
                                                 .where('appointments.status = ?', Appointment.status[:confirmed])
                                                 .joins(appointments: %i[doctor patient])
                                                 .joins(:practice)
                                                 .order('appointments.starts_at')

      # create array of column values (hash) instead of an array of models
      appointments = ActiveRecord::Base.connection.select_all(appointments_scheduled_for_today)

      # group the arrays by practice_id
      appointments = appointments.group_by { |appointment| appointment['doctor_id'].to_s }

      appointments.each_value do |value|
        DoctorMailer.today_agenda(value).deliver_now
      end
    end
  end

  desc 'Send birthday wishes to patients in their timezone'
  task send_birthday_wishes_to_patients: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    hour_to_send_emails = 15
    timezones_where_hour_is = timezones_where_hour_are(hour_to_send_emails)
    practice_ids = practices_in_timezones(timezones_where_hour_is)

    if practice_ids.size.positive?
      today = Time.now.in_time_zone(timezones_where_hour_is.first).beginning_of_day

      admins_of_these_practices = admin_of_practice(practice_ids)

      patients_of_these_practices = Patient.select('practice_id, firstname, lastname, date_of_birth, patients.email, practices.locale, practices.name as practice_name')
                                           .where(practice_id: practice_ids)
                                           .where("patients.email <> ''")
                                           .where('extract(month from date_of_birth) = ? AND extract(day from date_of_birth) = ?', today.strftime('%m'), today.strftime('%d'))
                                           .joins(:practice)

      # create array of column values (hash) instead of an array of models
      patients = ActiveRecord::Base.connection.select_all(patients_of_these_practices)
      users = ActiveRecord::Base.connection.select_all(admins_of_these_practices)

      next if patients.empty?
      next if users.empty?

      # group the arrays by practice_id
      patients = patients.group_by { |patient| patient['practice_id'].to_s }
      users = users.group_by { |user| user['practice_id'].to_s }

      # go through every practice_id in this timezone and email them
      practice_ids.each do |practice_id|
        patients_in_practice = patients[practice_id.to_s]
        admin_user = users[practice_id.to_s].first

        next if patients_in_practice.nil?

        patients_in_practice.each do |patient|
          PatientMailer.birthday_wishes(admin_user, patient).deliver_now
        end
      end

    end
  end

  desc 'Send appointment review request to patients in their timezone'
  task send_appointment_review_to_patients: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    appointments_pending_review = Datebook.select("practices.name as practice,
    practices.id as practice_id, practices.locale as practice_locale, datebooks.name as datebook,
    patients.email as patient_email, patients.firstname as patient_name,
    appointments.id as appointment_id, appointments.starts_at, appointments.ends_at")
                                          .where("patients.email <> ''")
                                          .where('appointments.ends_at < ?', 45.minutes.ago)
                                          .where('appointments.ends_at > ?', 3.days.ago)
                                          .where('appointments.notified_of_review = ?', false)
                                          .where('appointments.status = ?', Appointment.status[:confirmed])
                                          .joins(appointments: %i[patient doctor])
                                          .joins(:practice)
                                          .order('appointments.ends_at')

    exit unless appointments_pending_review.exists?

    # mark all the appointments found as "reviewed"
    Appointment.where(id: appointments_pending_review.map(&:appointment_id)).update_all(notified_of_review: true)

    # go through every appointment found and email them
    appointments_pending_review.each do |appointment|
      PatientMailer.review_recent_appointment(appointment).deliver_now
    end
  end

  desc 'Send six-month checkup reminder to patients (one-time)'
  task send_six_month_checkup_reminders: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    # Consider practices where local time is mid-morning to avoid odd-hour sends
    hour_to_send_emails = 10
    timezones_where_hour_is = timezones_where_hour_are(hour_to_send_emails)
    practice_ids = practices_in_timezones(timezones_where_hour_is)

    next if practice_ids.empty?

    # Find patients whose last confirmed appointment was > 6 months ago but not older than 7 months, and who have an email
    # Group by patient to only send once, and respect per-practice locale/timezone
    six_months_ago = 6.months.ago
    seven_months_ago = 7.months.ago

    last_appointments = Appointment.select('patients.id as patient_id, patients.email as patient_email, patients.firstname as patient_firstname, patients.lastname as patient_lastname, practices.id as practice_id, practices.name as practice_name, practices.locale as practice_locale, practices.timezone as practice_timezone, practices.email as practice_email, MAX(appointments.ends_at) as last_visit_at')
                                   .joins(:patient, datebook: :practice)
                                   .where('appointments.status = ?', Appointment.status[:confirmed])
                                   .where('appointments.ends_at < ?', six_months_ago)
                                   .where('appointments.ends_at > ?', seven_months_ago)
                                   .where("patients.email <> ''")
                                   .where(patients: { practice_id: practice_ids,
                                                      notified_of_six_month_reminder: [false, nil] })
                                   .group('patients.id, patients.email, patients.firstname, patients.lastname, practices.id, practices.name, practices.locale, practices.timezone, practices.email')

    # Patients with a future confirmed appointment should not receive this reminder
    future_confirmed_patient_ids = Appointment.joins(:patient)
                                              .where('appointments.starts_at > ?', Time.now)
                                              .where('appointments.status = ?', Appointment.status[:confirmed])
                                              .where(patients: { practice_id: practice_ids })
                                              .distinct
                                              .pluck(:patient_id)

    last_appointments.each do |row|
      # Skip if they already have a future confirmed appointment
      pid = row['patient_id'] || row.patient_id
      next if future_confirmed_patient_ids.include?(pid)

      full_name = [row['patient_firstname'] || row.patient_firstname,
                   row['patient_lastname'] || row.patient_lastname].compact.join(' ')
      PatientMailer.six_month_checkup_reminder(row['patient_email'] || row.patient_email,
                                               full_name,
                                               row['practice_name'] || row.practice_name,
                                               row['practice_locale'] || row.practice_locale,
                                               row['practice_timezone'] || row.practice_timezone,
                                               row['practice_email'] || row.practice_email).deliver_now

      Patient.where(id: row['patient_id'] || row.patient_id).update_all(notified_of_six_month_reminder: true)
    end
  end

  desc 'Clean up audit logs older than 30 days to prevent database bloat'
  task cleanup_audit_logs: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    # Delete audit versions older than 30 days
    cutoff_date = 30.days.ago
    sql = ActiveRecord::Base.sanitize_sql_array(['DELETE FROM versions WHERE created_at < ?', cutoff_date])
    deleted_count = ActiveRecord::Base.connection.exec_delete(sql)

    Rails.logger.info "Cleaned up #{deleted_count} audit log entries older than #{cutoff_date.strftime('%Y-%m-%d')}"
  end

  desc 'Cleanup practices older than 7 days with 0 patients'
  task cleanup_old_practices: :environment do
    Rails.logger = Logger.new($stdout) if defined?(Rails) && (Rails.env == 'development')

    cutoff_date = 7.days.ago
    practices = Practice.where('created_at < ?', cutoff_date)
                        .where('patients_count = ?', 0)
    deleted_count = practices.destroy_all

    Rails.logger.info "Cleaned up #{deleted_count} practices older than #{cutoff_date.strftime('%Y-%m-%d')} with 0 patients"
  end

  # find all the timezones where the hour is @hour
  def timezones_where_hour_are(hour)
    time = Time.now
    timezones = ActiveSupport::TimeZone.all

    timezones.select do |z|
      t = time.in_time_zone(z)
      t.hour == hour
    end.map(&:name)
  end

  # find all the practices that match any of the @timezones
  def practices_in_timezones(timezones)
    return [] if timezones.empty?

    # Only include practices that are active or trialing, and not cancelled
    Practice.joins(:subscription)
            .where(timezone: timezones)
            .where(subscriptions: { status: %w[trialing active] })
            .pluck(:id)
  end

  # find all the admins for the given @practice_ids
  def admin_of_practice(practice_ids)
    User.select('firstname, lastname, practice_id, users.email, locale, timezone, practices.currency, subscribed_to_digest')
        .where(practice_id: practice_ids)
        .where('roles = ?', 'admin')
        .joins(:practice)
        .order(:practice_id)
  end
end
