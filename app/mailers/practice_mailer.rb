class PracticeMailer < ActionMailer::Base

  layout 'email'
  default :from => "Odonto.me <hello@odonto.me>"
  add_template_helper(ApplicationHelper)
  
  def welcome_email(practice)
  	mail(:to => practice.users.first.email, :subject => I18n.t("mailers.practice.welcome.subject"))
  end

  def daily_recap_email(admin_user, patients_created_today, appointments_created_today, date)
  	@patients = patients_created_today
  	@appointments = appointments_created_today
  	@date = date
	
  	if !@patients.nil? || !@appointments.nil?
  		# temporarely set the locale and then change it back
	    # when the block finishes
	    I18n.with_locale(admin_user.first["locale"]) do
  			mail(:to => admin_user.first["email"], :subject => I18n.t("mailers.practice.daily_recap.subject", :date => l(@date.to_date, :format => :day_and_date)))
  		end
  	end
  end
end
