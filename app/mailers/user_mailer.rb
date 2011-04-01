class UserMailer < ActionMailer::Base

  before_filter :set_locale

  default :from => "hello@odonto.me"
  
  def welcome_email(user)
    mail(:to => user.email, :subject => _("Welcome to Odonto.me!")
  end
  
  def set_locale
    I18n.locale = FastGettext.set_locale(user.practice.locale)
  end

end
