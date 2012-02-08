desc "This task is called by the Heroku cron add-on"
task :cron => :environment do
  if Time.now.utc.hour == $appointment_notificacion_time # run at whatever is set in environment.rb
    Rake::Task["odontome:send_appointments_notifications"].execute
  end
end