# frozen_string_literal: true

require 'test_helper'

class ReviewsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:reviews)
  end

  test 'index handles no reviews gracefully and sets average_score to 0' do
    # Switch session to a user in a practice with no reviews
    @controller.session['user'] = users(:user_in_yet_another_practice)

    # Sanity check: this practice should have zero reviews
    assert_equal 0, Review.with_practice(users(:user_in_yet_another_practice).practice_id).count

    get :index
    assert_response :success
    assert_equal 0, assigns(:average_score)
  end

  test 'index floors average_score when reviews exist' do
    # There is already one review in fixtures create another review to make the average 4.5
    Review.create!(appointment_id: appointments(:unreviewed).id, score: 5, comment: 'Great!')

    get :index
    assert_response :success
    assert_equal 4, assigns(:average_score)
  end

  test 'should get new when passing a valid appointment id' do
    ciphered_appointment_id = appointments(:unreviewed).ciphered_id

    get :new, params: { appointment_id: ciphered_appointment_id }
    assert_response :success
  end

  test 'should not get new when passing an invalid appointment id' do
    ciphered_appointment_id = 'not-ciphered-correctly'

    get :new, params: { appointment_id: ciphered_appointment_id }
    assert_redirected_to 'https://www.odonto.me'
  end

  test 'should create review' do
    assert_difference('Review.count') do
      post :create,
           params: { review: { appointment_id: appointments(:unreviewed).ciphered_id, comment: 'I loved this place', score: 5 } }, format: :js
    end

    assert_response :success
    # assert_redirected_to review_path(assigns(:review))
  end

  test 'index escapes HTML in review comments' do
    Review.create!(appointment_id: appointments(:unreviewed).id, score: 5, comment: '<script>alert(1)</script>')

    get :index
    assert_response :success
    assert_includes response.body, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_not_includes response.body, '<script>alert(1)</script>'
  end

  test 'index escapes HTML in the custom review url message' do
    users(:founder).practice.update_column(:custom_review_url, '<img src=x onerror=alert(1)> http://a.co')

    get :index
    assert_response :success
    assert_includes response.body, '&lt;img src=x onerror=alert(1)&gt;'
    assert_not_includes response.body, '<img src=x onerror=alert(1)>'
  end

  test 'should not create review with a score outside 1 to 5' do
    assert_no_difference('Review.count') do
      post :create,
           params: { review: { appointment_id: appointments(:unreviewed).ciphered_id, comment: 'Hi', score: 2_000_000_000 } }, format: :js
    end
  end
end
