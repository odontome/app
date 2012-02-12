class PatientMailer < ActionMailer::Base

  layout 'email'
  default :from => "hello@odonto.me"
  
  def appointment_soon_email(patient_email, patient_name, start_time, end_time, practice_name, practice_locale, doctor_name)
    set_locale(practice_locale)
    @patient_name = patient_name
    @start_time = start_time
    @end_time = end_time
    @practice_name = practice_name
    @doctor_name = doctor_name
    mail(:to => patient_email, :subject => _("You have an appointment soon in") + " " + practice_name)
  end
  
  def set_locale(practice_locale)
    I18n.locale = FastGettext.set_locale(practice_locale)
  end

end
