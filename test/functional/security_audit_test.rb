# frozen_string_literal: true

# Security audit proofs. Each test asserts the SECURE behaviour, so a failure
# here demonstrates the finding it is named after.
require 'test_helper'
require 'ostruct'

class SecurityAuditCipherTokenConfusionTest < ActionController::TestCase
  tests DoctorsController

  setup do
    # Victim: a doctor in another practice whose id collides with an
    # appointment id in the attacker's practice. Ids come from one global
    # sequence per table, so low ids collide constantly in production.
    @other_practice = practices(:trialing_practice)
    @other_datebook = Datebook.create!(practice_id: @other_practice.id, name: 'Other clinic', starts_at: 8, ends_at: 20)
    @other_doctor = Doctor.create!(id: 4242, practice_id: @other_practice.id, firstname: 'Secret', lastname: 'Dentist')
    week_start = Date.today.at_beginning_of_week.to_time
    Appointment.create!(datebook_id: @other_datebook.id, doctor_id: @other_doctor.id, patient_id: patients(:three).id,
                        starts_at: week_start + 1.day + 10.hours, ends_at: week_start + 1.day + 11.hours,
                        notes: 'root canal, pays cash')

    # Attacker: a patient of practice 1 who received the review email for
    # appointment 4242. The email carries Cipher.encode('4242', purpose: :review).
    Appointment.create!(id: 4242, datebook_id: datebooks(:playa_del_carmen).id, doctor_id: doctors(:rebecca).id,
                        patient_id: patients(:four).id, starts_at: week_start + 2.days + 9.hours,
                        ends_at: week_start + 2.days + 10.hours)
    @review_token = Appointment.ciphered_review_url_for_id(4242).split('appointment_id=').last
  end

  test 'a review-link token for appointment N must not open the calendar feed of doctor N in another practice' do
    get :appointments, params: { doctor_id: @review_token, format: :ics }

    assert_no_match(/Daniella Sanguino/, response.body, "another practice's patient name leaked")
    assert_no_match(/root canal/, response.body, "another practice's appointment notes leaked")
    assert_response :not_found, 'review token was accepted as a doctor feed token'
  end
end

class SecurityAuditCipherTokenReviewTest < ActionController::TestCase
  tests ReviewsController

  test 'a doctor feed token (shown to every user on the doctor page) must not act as a review token for appointment N of another practice' do
    # doctors(:perishable) has id 2 in practice 1; appointments(:unreviewed) has id 2.
    # Move the appointment to a different practice to make the cross-tenant path explicit.
    other = practices(:trialing_practice)
    datebook = Datebook.create!(practice_id: other.id, name: 'Other clinic', starts_at: 8, ends_at: 20)
    doctor = Doctor.create!(practice_id: other.id, firstname: 'Secret', lastname: 'Dentist')
    appointment = appointments(:unreviewed)
    appointment.update_columns(datebook_id: datebook.id, doctor_id: doctor.id, patient_id: patients(:three).id)

    feed_token = doctors(:perishable).ciphered_feed_url.split('/doctors/').last.delete_suffix('/appointments.ics')

    get :new, params: { appointment_id: feed_token }

    assert_no_match(/#{Regexp.escape(other.name)}/, response.body, "another practice's name was shown on the review form")

    assert_no_difference('Review.count', 'a review was written for another practice using a doctor feed token') do
      post :create, params: { review: { appointment_id: feed_token, score: 1, comment: 'spam' } }, format: :js
    end
  end
end

class SecurityAuditSuperadminTakeoverTest < ActionController::TestCase
  tests UsersController

  test 'a practice admin must not be able to change the password or email of a superadmin living in their practice' do
    @controller.session['user'] = users(:founder) # plain practice admin
    superadmin = users(:superadmin)
    assert_equal users(:founder).practice_id, superadmin.practice_id

    patch :update, params: { id: superadmin.id,
                             user: { email: 'attacker@example.com', password: 'hijacked123', password_confirmation: 'hijacked123' } }

    superadmin.reload
    assert_not superadmin.authenticate('hijacked123'), 'practice admin set the superadmin password'
    assert_equal 'superadmin@odonto.me', superadmin.email, 'practice admin changed the superadmin email'
  end
end

class SecurityAuditPublicPaymentPageTest < ActionController::TestCase
  tests PaymentsController

  setup do
    metadata = OpenStruct.new(practice_id: practices(:complete).id.to_s, patient_name: 'Edwin Brito')
    @intent = OpenStruct.new(id: 'pi_123', client_secret: 'pi_123_secret_real', amount: 5000, currency: 'usd',
                             status: 'requires_payment_method', metadata: metadata, charges: nil)
  end

  test 'the public pay page must not render a payment intent when the client secret in the URL does not match it' do
    Stripe::PaymentIntent.stub(:retrieve, ->(_id) { @intent }) do
      get :pay, params: { client_secret: 'pi_123_secret_WRONG' }
    end

    assert_no_match(/Edwin Brito/, response.body, 'patient name rendered for a guessed client secret')
    assert_no_match(/50\.00/, response.body, 'amount rendered for a guessed client secret')
  end

  test 'the pay page still works with the real client secret' do
    Stripe::PaymentIntent.stub(:retrieve, ->(_id) { @intent }) do
      get :pay, params: { client_secret: 'pi_123_secret_real' }
    end

    assert_response :success
    assert_match(/Edwin Brito/, response.body)
  end

  test 'the success page must not show a receipt for a payment intent id without its client secret' do
    @intent.status = 'succeeded'
    Stripe::PaymentIntent.stub(:retrieve, ->(_id) { @intent }) do
      get :success, params: { payment_intent: 'pi_123' }
    end

    assert_no_match(/50\.00/, response.body, 'amount rendered for a bare payment intent id')

    Stripe::PaymentIntent.stub(:retrieve, ->(_id) { @intent }) do
      get :success, params: { payment_intent: 'pi_123', payment_intent_client_secret: 'pi_123_secret_real' }
    end

    assert_match(/50\.00/, response.body)
  end
end
