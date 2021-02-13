class DoctorMailer < ApplicationMailer
  def today_agenda(agenda)
    @practice = Practice.find agenda.first['practice_id']
    @doctor_name = agenda.first['doctor_firstname']
    @doctor_email = agenda.first['doctor_email']
    @appointments = agenda

    # temporarely set the locale and then change it back
    # when the block finishes
    I18n.with_locale(@practice.locale) do
      @practice_timezone = @practice.timezone
      mail(to: @doctor_email,
           subject: I18n.t('mailers.doctor.today_agenda.subject'),
           reply_to: @practice.email)
    end
  end
end
