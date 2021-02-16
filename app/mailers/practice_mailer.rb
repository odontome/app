# frozen_string_literal: true

class PracticeMailer < ApplicationMailer
  add_template_helper(ApplicationHelper)

  def welcome_email(practice)
    mail(to: practice.email, subject: I18n.t('mailers.practice.welcome.subject'))
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
