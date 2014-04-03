require 'test_helper'
 
class PatientMailerTest < ActionMailer::TestCase

  test "patient appointment reminder" do
    practice = practices(:complete)
    appointment = appointments(:first_visit)
    doctor = doctors(:rebecca)
    patient = patients(:four)

    # Send the email, then test that it got queued
    email = PatientMailer.appointment_soon_email(patient.email, patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, doctor, users(:perishable).email).deliver

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
    email = PatientMailer.appointment_soon_email(patient.email, patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, doctor, practice_email).deliver

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_match(/Comienza a las: <strong>08:00<\/strong>/, email.encoded)
    assert_match(/y termina a las: <strong>09:00<\/strong>/, email.encoded)
    assert_match(/Dra. Rebecca Riera/, email.encoded)
  end

  test "patient scheduled appointment notifier" do
    practice = practices(:complete)
    appointment = appointments(:first_visit)
    doctor = doctors(:rebecca)
    patient = patients(:four)

    passbook_url = appointment.ciphered_url

    # Send the email, then test that it got queued
    email = PatientMailer.appointment_scheduled_email(patient.email, patient.fullname, appointment.starts_at, appointment.ends_at, practice.name, practice.locale, practice.timezone, doctor, users(:perishable).email, passbook_url).deliver

    assert !ActionMailer::Base.deliveries.empty?
    
    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.reply_to
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t("mailers.patient.appointment_scheduled_email.subject", practice_name: practice.name), email.subject
    assert_match(/Are you an iOS or Android user\? You can get a Passbook of this appointment here/, email.encoded)
  end
end