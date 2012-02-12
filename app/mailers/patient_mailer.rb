class PatientMailer < ActionMailer::Base

  layout 'email'
  default :from => "hello@odonto.me"
  
  def appointment_soon_email(patient_email, patient_firstname, patient_lastname, start_time, end_time, practice_name, practice_locale, doctor_firstname, doctor_lastname)
    set_locale(practice_locale)
    @patient_firstname = patient_firstname
    @patient_lastname = patient_lastname
    @start_time = start_time
    @end_time = end_time
    @practice_name = practice_name
    @doctor_firstname = doctor_firstname
    @doctor_lastname = doctor_lastname
    mail(:to => patient_email, :subject => _("You have an appointment soon in") + " " + practice_name)
  end
  
  def set_locale(practice_locale)
    I18n.locale = FastGettext.set_locale(practice_locale)
  end

end
