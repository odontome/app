# frozen_string_literal: true

class PracticeMailer < ApplicationMailer
  helper ApplicationHelper

  def welcome_email(practice)
    I18n.with_locale(practice.locale) do
      mail(to: practice.email, subject: I18n.t('mailers.practice.welcome.subject'))
    end
  end

  def activation_nudge(practice)
    I18n.with_locale(practice.locale) do
      mail(to: practice.email, subject: I18n.t('mailers.practice.activation_nudge.subject'))
    end
  end

  def trial_ending(practice)
    @trial_ends_on = practice.subscription.current_period_end.strftime('%d/%m/%Y')
    @price = Rails.configuration.stripe[:price_display]

    I18n.with_locale(practice.locale) do
      mail(to: practice.email, subject: I18n.t('mailers.practice.trial_ending.subject'))
    end
  end

  def trial_ended(practice)
    @price = Rails.configuration.stripe[:price_display]

    I18n.with_locale(practice.locale) do
      mail(to: practice.email, subject: I18n.t('mailers.practice.trial_ended.subject'))
    end
  end

  def deletion_warning(practice)
    I18n.with_locale(practice.locale) do
      mail(to: practice.email, subject: I18n.t('mailers.practice.deletion_warning.subject'))
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
