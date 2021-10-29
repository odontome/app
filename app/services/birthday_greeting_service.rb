class BirthdayGreetingService < ApplicationService
  attr_reader :hour_of_day
  
  RETURNS = [
    SUCCESS = :success,
    FAILURE = :failure,
  ]

  def initialize(hour_of_day)
    @hour_of_day = hour_of_day
  end

  def call
    SUCCESS
  end

  private

  # find all the timezones where the hour is @hour
  def timezones_where_hour_are(hour)
    time = Time.now
    timezones = ActiveSupport::TimeZone.all

    timezones.select do |z|
      t = time.in_time_zone(z)
      t.hour == hour
    end.map(&:name)
  end
end

    hour_to_send_emails = 15
    timezones_where_hour_is = timezones_where_hour_are(hour_to_send_emails)
    practice_ids = Practice.ids_in_timezone timezones_where_hour_is

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

