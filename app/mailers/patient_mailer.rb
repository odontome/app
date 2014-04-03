class PatientMailer < ActionMailer::Base

  layout 'email'

  def appointment_soon_email(patient_email, patient_name, start_time, end_time, practice_name, practice_locale, practice_timezone, doctor, practice_email)
        
    # temporarely set the locale and then change it back
    # when the block finishes
    I18n.with_locale(practice_locale) do
      @patient_name = patient_name      
      @practice_name = practice_name
      @practice_timezone = practice_timezone
      @doctor_name = doctor.fullname
      @appointment_date = I18n.l start_time.in_time_zone(@practice_timezone).to_date, :format => :day_and_date
      @appointment_start_time = I18n.l start_time.to_time.in_time_zone(@practice_timezone), :format => :just_the_time
      @appointment_end_time = I18n.l end_time.to_time.in_time_zone(@practice_timezone), :format => :just_the_time

      mail(:from => "#{practice_name} <hello@odonto.me>", 
           :to => patient_email, 
           :subject => I18n.t("mailers.patient.appointment_soon_email.subject", practice_name: practice_name), 
           :reply_to => practice_email)
    end
  end

  def appointment_scheduled_email(patient_email, patient_name, start_time, end_time, practice_name, practice_locale, practice_timezone, doctor, practice_email, passbook_url)
        
    # temporarely set the locale and then change it back
    # when the block finishes
    I18n.with_locale(practice_locale) do
      @patient_name = patient_name      
      @practice_name = practice_name
      @practice_timezone = practice_timezone
      @doctor_name = doctor.fullname
      @passbook_url = passbook_url
      @appointment_date = I18n.l start_time.in_time_zone(@practice_timezone).to_date, :format => :day_and_date
      @appointment_start_time = I18n.l start_time.to_time.in_time_zone(@practice_timezone), :format => :just_the_time
      @appointment_end_time = I18n.l end_time.to_time.in_time_zone(@practice_timezone), :format => :just_the_time

      mail(:from => "#{practice_name} <hello@odonto.me>", 
           :to => patient_email, 
           :subject => I18n.t("mailers.patient.appointment_scheduled_email.subject", practice_name: practice_name), 
           :reply_to => practice_email)
    end
  end

  def birthday_wishes(admin, patient)
    @admin = admin
    @patient = patient

    # temporarely set the locale and then change it back
    # when the block finishes
    I18n.with_locale(@patient["locale"]) do
      mail(:from => "#{@patient['practice_name']} <hello@odonto.me>",
           :to => @patient["email"], 
           :subject => I18n.t("mailers.patient.birthday.subject"),
           :reply_to => @admin["email"])
    end
  end

end
