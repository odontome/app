class PracticeMailer < ApplicationMailer
  add_template_helper(ApplicationHelper)

  def welcome_email(practice)
    mail(to: practice.email, subject: I18n.t('mailers.practice.welcome.subject'))
  end

  def daily_recap_email(admin_user, patients_created_today, appointments_created_today, balance_created_today, date)
    @patients = patients_created_today
    @appointments = appointments_created_today
    @balance = balance_created_today
    @date = date

    if !@patients.nil? || !@appointments.nil? || !@balance.nil?
      @practice_timezone = admin_user.first['timezone']
      @practice_locale = admin_user.first['locale']
      @currency_unit = admin_user.first['currency_unit']

      # temporarely set the locale and then change it back
      # when the block finishes
      I18n.with_locale(@practice_locale) do
        mail(to: admin_user.first['email'],
             subject: I18n.t('mailers.practice.daily_recap.subject',
                             date: l(@date.in_time_zone(@practice_timezone).to_date, format: :day_and_date)))
      end
    end
  end

  def new_review_notification(review)
    # pre cache all the related content to this review
    @review = Review.where(id: review.id).includes(appointment: [datebook: [:practice]]).first

    practice = @review.appointment.datebook.practice
    admin_user = practice.users.first

    # temporarely set the locale and then change it back
    # when the block finishes
    I18n.with_locale(practice.locale) do
      mail(to: admin_user.email, subject: I18n.t('mailers.practice.new_review_notification.subject'))
    end
  end
end
