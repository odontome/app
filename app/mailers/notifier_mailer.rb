class NotifierMailer < ActionMailer::Base

  helper :mail
  layout 'email'
  default :from => "hello@odonto.me"
  
  def deliver_password_reset_instructions(user)
    @user = user
    practice_locale = @user.practice.locale
    set_locale(practice_locale)
    @edit_password_reset_url = edit_password_reset_url(@user.perishable_token)
    mail(:to => user.email, :subject => _('Password reset instructions'))
  end

  def set_locale(practice_locale)
    I18n.locale = FastGettext.set_locale(practice_locale)
  end
  
end
