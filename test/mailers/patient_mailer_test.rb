require 'test_helper'

class PatientMailerTest < ActionMailer::TestCase

  test "patient appointment reminder" do
    practice = practices(:complete)
    appointment = appointments(:first_visit)
    doctor = doctors(:rebecca)
    patient = patients(:four)

    # Send the email, then test that it got queued
    email = PatientMailer.appointment_soon_email(patient.email, patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, doctor, users(:perishable).email).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.reply_to
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t("mailers.patient.appointment_soon_email.subject", practice_name: practice.name), email.subject
    #assert_equal read_fixture('welcome_email').join, email.body.to_s
    assert_match(/Your appointment with Odonto.me demo practice is soon/, email.encoded)
    assert_match(/D.D.S. Rebecca Riera/, email.encoded)
  end

  test "patient localised appointment reminder" do
    practice = practices(:complete_another_language)
    practice_email = users(:perishable).email
    appointment = appointments(:first_visit)
    doctor = doctors(:rebecca)
    patient = patients(:four)

    # Send the email, then test that it got queued
    email = PatientMailer.appointment_soon_email(patient.email, patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, doctor, practice_email).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_match(/Comienza a las: (.*)08:00/, email.encoded)
    assert_match(/y termina a las: (.*)09:00/, email.encoded)
    assert_match(/Dra. Rebecca Riera/, email.encoded)
  end

  test "patient scheduled appointment notifier" do
    practice = practices(:complete)
    appointment = appointments(:first_visit)
    doctor = doctors(:rebecca)
    patient = patients(:four)

    passbook_url = appointment.ciphered_url

    # Send the email, then test that it got queued
    email = PatientMailer.appointment_scheduled_email(patient.email, patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, doctor, users(:perishable).email, passbook_url).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.reply_to
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t("mailers.patient.appointment_scheduled_email.subject", practice_name: practice.name), email.subject
    assert_match(/Are you an iOS or Android user\? You can get a Passbook of this appointment here/, email.encoded)
  end

  test "patient birthday wishes notifier" do

    admin = {
      "email" => "contact@bokanova.mx"
    }

    patient = {
      "locale" => "en",
      "practice_name" => "Odonto.me",
      "email" => "raulriera@hotmail.com"
    }

    # Send the email, then test that it got queued
    email = PatientMailer.birthday_wishes(admin, patient).deliver_now

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.reply_to
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t("mailers.patient.birthday.subject"), email.subject
    assert_match /We would like to wish you the best birthday ever. We \"made\" you this sugary treat for you. Don't forget to visit us if you eat all that sugar/, email.encoded
  end

  test "review_recent_appointment" do
    appointment = {
      "appointment_id" => 1,
      "patient_email" => "raulriera@hotmail.com",
      "practice" => "Bokanova Riviera Maya",
      "patient_name" => "Raul"
    }

    mail = PatientMailer.review_recent_appointment(appointment)
    assert_equal I18n.t("mailers.patient.review.subject", practice_name: appointment["practice"]), mail.subject
    assert_equal appointment["patient_email"], mail.to.first
    assert_equal ["hello@odonto.me"], mail.from
    assert_match "how was your experience with us at", mail.body.encoded
  end

end
