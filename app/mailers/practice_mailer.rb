class PracticeMailer < ActionMailer::Base

  default :from => "hello@odonto.me"
  
  def welcome_email(practice)
    set_locale(practice)
    mail(:to => practice.users.first.email, :subject => _("Welcome to Odonto.me!"))
  end
  
  def set_locale(practice)
    I18n.locale = FastGettext.set_locale(practice.locale)
  end

end
