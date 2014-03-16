class NotifierMailer < ActionMailer::Base

  layout 'email'
  default :from => "Odonto.me <hello@odonto.me>"
  
  def deliver_password_reset_instructions(user)
    @show_logo_in_header = true
    @user = user
    @edit_password_reset_url = edit_password_reset_url(@user.perishable_token)

    # temporarely set the locale and then change it back
    # when the block finishes
    I18n.with_locale(@user.practice.locale) do
    	mail(:to => user.email, 
           :subject => I18n.t("mailers.notifier.password_reset.subject"))
    end
  end
  
end
