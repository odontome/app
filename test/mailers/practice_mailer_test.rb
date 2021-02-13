
require 'test_helper'

class PracticeMailerTest < ActionMailer::TestCase
  setup :yesterday_date

  def yesterday_date
    @today = Time.zone.now.beginning_of_day
    @yesterday = @today - 1.day
  end

  test 'practice welcome email' do
    practice = practices(:complete)
    practice.users << users(:founder)

    # Send the email, then test that it got queued
    email = PracticeMailer.welcome_email(practice).deliver_now
    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t('mailers.practice.welcome.subject'), email.subject
    assert_match(/Welcome to Odonto.me/, email.encoded)
  end

  test 'practice daily suggest email, patient only' do
    admin = [{
      'locale' => 'en',
      'timezone' => 'London',
      'email' => 'contact@bokanova.mx',
      'currency_unit' => '€'
    }]

    patients = [{
      'id' => 1,
      'firstname' => 'Raul',
      'lastname' => 'Riera',
      'email' => 'raulriera@hotmail.com'
    }]

    # Send the email, then test that it got queued
    email = PracticeMailer.daily_recap_email(admin, patients, nil, nil, @yesterday).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    expected_date = I18n.l(@yesterday.in_time_zone(admin.first['timezone']).to_date, format: :day_and_date)
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.to
    assert_equal I18n.t('mailers.practice.daily_recap.subject', date: expected_date), email.subject
    assert_match(/1 patients added/, email.encoded)
  end

  test 'practice daily suggest email, appointments only' do
    admin = [{
      'locale' => 'en',
      'timezone' => 'London',
      'email' => 'contact@bokanova.mx',
      'currency_unit' => '€'
    }]

    appointments = [
      {
        'id' => 1,
        'name' => 'Cuernavaca',
        'patient_firstname' => 'Raul',
        'patient_lastname' => 'Riera',
        'doctor_firstname' => 'Rebecca',
        'doctor_lastname' => 'Riera',
        'starts_at' => @yesterday - 2.hours,
        'email' => 'raulriera@hotmail.com'
      },
      {
        'id' => 2,
        'name' => 'Playa del Carmen',
        'patient_firstname' => 'Raul',
        'patient_lastname' => 'Riera',
        'doctor_firstname' => 'Ruth',
        'doctor_lastname' => 'Riera',
        'starts_at' => @yesterday - 2.hours,
        'email' => 'raulriera@hotmail.com'
      }
    ]

    # Send the email, then test that it got queued
    email = PracticeMailer.daily_recap_email(admin, nil, appointments, nil, @yesterday).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    expected_date = I18n.l(@yesterday.in_time_zone(admin.first['timezone']).to_date, format: :day_and_date)
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.to
    assert_equal I18n.t('mailers.practice.daily_recap.subject', date: expected_date), email.subject
    assert_match(/2 appointments scheduled/, email.encoded)
  end

  test 'practice daily suggest email, balance only' do
    admin = [{
      'locale' => 'en',
      'timezone' => 'Mexico City',
      'email' => 'contact@bokanova.mx',
      'currency_unit' => '$'
    }]

    balance = [{
      'practice_id' => 1,
      'amount' => 1000
    }]

    # Send the email, then test that it got queued
    email = PracticeMailer.daily_recap_email(admin, nil, nil, balance, @yesterday).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    expected_date = I18n.l(@yesterday.in_time_zone(admin.first['timezone']).to_date, format: :day_and_date)

    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.to
    assert_equal I18n.t('mailers.practice.daily_recap.subject', date: expected_date), email.subject
    assert_match(/\$1,000.00 processed yesterday/, email.encoded)
  end

  test 'new_review_notification' do
    review = reviews(:valid)
    practice = review.appointment.datebook.practice
    admin_user = practice.users.first

    mail = PracticeMailer.new_review_notification(review)
    assert_equal I18n.t('mailers.practice.new_review_notification.subject'), mail.subject
    assert_equal admin_user.email, mail.to.first
    assert_equal ['hello@odonto.me'], mail.from
    assert_match 'View more at', mail.body.encoded
  end
end
