class NotifierMailer < ActionMailer::Base

  layout 'email'
  default :from => "hello@odonto.me"
  
  def deliver_password_reset_instructions(user)
    @user = user
    @edit_password_reset_url = edit_password_reset_url(@user.perishable_token)
    mail(:to => user.email, :subject => I18n.t("mailers.notifier.password_reset.subject"))
  end
  
end
