# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/practice_mailer
class PracticeMailerPreview < ActionMailer::Preview
  def activation_nudge
    practice = Practice.last
    raise 'Create a Practice record in development to preview this email.' unless practice

    PracticeMailer.activation_nudge practice
  end

  def trial_ending
    practice = Practice.last
    raise 'Create a Practice record in development to preview this email.' unless practice

    PracticeMailer.trial_ending practice
  end

  def trial_ended
    practice = Practice.last
    raise 'Create a Practice record in development to preview this email.' unless practice

    PracticeMailer.trial_ended practice
  end

  def deletion_warning
    practice = Practice.last
    raise 'Create a Practice record in development to preview this email.' unless practice

    PracticeMailer.deletion_warning practice
  end

  def new_review_notification
    review = Review.last
    raise 'Create a Review record in development to preview this email.' unless review

    PracticeMailer.new_review_notification review
  end
end
