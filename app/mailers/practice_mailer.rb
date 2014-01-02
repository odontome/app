class PracticeMailer < ActionMailer::Base

  layout 'email'
  default :from => "hello@odonto.me"
  
  def welcome_email(practice)
  	mail(:to => practice.users.first.email, :subject => I18n.t("mailers.practice.welcome.subject"))
  end

end
