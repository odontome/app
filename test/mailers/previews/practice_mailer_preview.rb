# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/practice_mailer
class PracticeMailerPreview < ActionMailer::Preview
  def new_review_notification
    review = Review.last
    raise 'Create a Review record in development to preview this email.' unless review

    PracticeMailer.new_review_notification review
  end
end
