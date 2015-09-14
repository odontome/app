require 'test_helper'

class ReviewTest < ActiveSupport::TestCase

  test "review attributes must not be empty" do
  	review = Review.new
  	assert review.invalid?
  	assert review.errors[:appointment_id].any?
  	assert review.errors[:score].any?
  	assert review.errors[:comment].any?
  end

  test "review is not valid without an unique appointment" do
  	review = Review.new
    review.appointment_id = 1
    review.score = 3
    review.comment = "Pretty good service, very professional"

  	assert !review.save
  	assert_equal I18n.t("errors.messages.taken"), review.errors[:appointment_id].first
  end
end
