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
    .where("appointments.created_at < ? AND appointments.notified_of_schedule = ? 
                                      AND patients.email <> ''", 5.minutes.ago, false)
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

  desc "Send an activity recap everyday at 8am in their timezone"
  task :send_daily_recap_to_administrators => :environment do 

    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end

    # configuration
    HOUR_TO_SEND_EMAILS = 8
    TODAY = Time.zone.now.beginning_of_day
    YESTERDAY = TODAY - 1.day

    practice_ids = practices_in_timezones(timezones_where_hour_are(HOUR_TO_SEND_EMAILS))

    if practice_ids.size > 0
      admins_of_these_practices = admin_of_practice(practice_ids)

      patients_created_today = Patient.select("id, firstname, lastname, practice_id, email")
      .where(:practice_id => practice_ids)
      .where("patients.created_at >= ? AND patients.created_at <= ?", YESTERDAY, TODAY)
      .order(:practice_id)

      appointments_created_today = Datebook.select("datebooks.practice_id, datebooks.name, appointments.starts_at, doctors.firstname as doctor_firstname, doctors.lastname as doctor_lastname, patients.firstname as patient_firstname, patients.lastname as patient_lastname")
      .where("datebooks.practice_id" => practice_ids)
      .where("appointments.created_at >= ? AND appointments.created_at <= ?", YESTERDAY, TODAY)
      .joins(:appointments => [:doctor, :patient])
      .order("datebooks.practice_id")

      # create array of column values (hash) instead of an array of models
      patients = ActiveRecord::Base.connection.select_all(patients_created_today)
      appointments = ActiveRecord::Base.connection.select_all(appointments_created_today)
      users = ActiveRecord::Base.connection.select_all(admins_of_these_practices)

      # group the arrays by practice_id
      patients = patients.group_by { |patient| patient["practice_id"].to_s }
      appointments = appointments.group_by { |appointment| appointment["practice_id"].to_s }
      users = users.group_by { |user| user["practice_id"].to_s }

      # go through every practice_id in this timezone and send them an
      # email with their daily recap
      practice_ids.each do |practice_id|
        PracticeMailer.daily_recap_email(users["#{practice_id}"], patients["#{practice_id}"], appointments["#{practice_id}"], YESTERDAY).deliver
      end
    end

  end

  desc "Send birthday wishes to patients in their timezone"
  task :send_birthday_wishes_to_patients => :environment do

    if defined?(Rails) && (Rails.env == 'development')
      Rails.logger = Logger.new(STDOUT)
    end

    HOUR_TO_SEND_EMAILS = 15
    TODAY = Time.zone.now.to_date

    practice_ids = practices_in_timezones(timezones_where_hour_are(HOUR_TO_SEND_EMAILS))

    if practice_ids.size > 0
      admins_of_these_practices = admin_of_practice(practice_ids)

      patients_of_these_practices = Patient.select("practice_id, firstname, lastname, date_of_birth, email, practices.locale, practices.name as practice_name")
      .where(:practice_id => practice_ids)
      .where("patients.email <> ''")
      .where("extract(month from date_of_birth) = ? AND extract(day from date_of_birth) = ?", TODAY.strftime('%m'), TODAY.strftime('%d'))
      .joins(:practice)

      # create array of column values (hash) instead of an array of models
      patients = ActiveRecord::Base.connection.select_all(patients_of_these_practices)
      users = ActiveRecord::Base.connection.select_all(admins_of_these_practices)

      # group the arrays by practice_id
      patients = patients.group_by { |patient| patient["practice_id"].to_s }
      users = users.group_by { |user| user["practice_id"].to_s }

      # go through every practice_id in this timezone and email them
      practice_ids.each do |practice_id|
        patients_in_practice = patients["#{practice_id}"]
        admin_user = users["#{practice_id}"].first

        if patients_in_practice
          patients_in_practice.each do |patient|
            PatientMailer.birthday_wishes(admin_user, patient).deliver
          end
        end
      end

    end

  end

  # find all the timezones where the hour is @hour
  def timezones_where_hour_are(hour)
    time = Time.now
    timezones = ActiveSupport::TimeZone.all

    timezones.select { |z|
      t = time.in_time_zone(z)
      t.hour == hour
    }.map(&:name)
  end

  # find all the practices that match any of the @timezones
  def practices_in_timezones(timezones)
    return [] if timezones.empty?
    Practice.select(:id).where(:timezone => timezones).pluck(:id)
  end

  # find all the admins for the given @practice_ids
  def admin_of_practice(practice_ids)
    User.select("firstname, lastname, practice_id, email, locale")
      .where(:practice_id => practice_ids)
      .where("roles = ?", "admin")
      .joins(:practice)
      .order(:practice_id)
  end

end