# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/practice_mailer
class PracticeMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/practice_mailer/new_review_notification
  def new_review_notification
    review = reviews(:valid)
    PracticeMailer.new_review_notification review
  end
end
