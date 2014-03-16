class PracticeMailer < ActionMailer::Base

  layout 'email'
  default :from => "Odonto.me <hello@odonto.me>"
  
  def welcome_email(practice)
  	@show_logo_in_header = true

  	mail(:to => practice.users.first.email, :subject => I18n.t("mailers.practice.welcome.subject"))
  end

end
