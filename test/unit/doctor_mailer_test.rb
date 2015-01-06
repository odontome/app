# encoding: UTF-8
require 'test_helper'

class DoctorMailerTest < ActionMailer::TestCase

  test "doctors appointments for today" do
    admin = [{
      "locale" => "en",
      "timezone" => "London",
      "email" => "contact@bokanova.mx",
      "currency_unit" => "€"
    }]

    appointments = [
      {
        "practice_id" => 1,
        "datebook" => "Cuernavaca",
        "patient_firstname" => "Raul",
        "patient_lastname" => "Riera",
        "doctor_firstname" => "Rebecca",
        "doctor_lastname" => "Riera",
        "doctor_email" => "rebeccariera@hotmail.com",
        "starts_at" => Time.zone.now,
        "ends_at" => Time.zone.now + 2.hours,
        "email" => "raulriera@hotmail.com",
        "notes" => "This is his first visit"
      },
      {
        "practice_id" => 1,
        "name" => "Playa del Carmen",
        "patient_firstname" => "Ruth",
        "patient_lastname" => "Riera",
        "doctor_firstname" => "Rebecca",
        "doctor_lastname" => "Riera",
        "doctor_email" => "rebeccariera@hotmail.com",
        "starts_at" => Time.zone.now + 3.hours,
        "ends_at" => Time.zone.now + 4.hours,
        "email" => "raulriera@hotmail.com",
        "notes" => "She is visiting from Barcelona"
      }
    ]

    # Send the email, then test that it got queued
    email = DoctorMailer.today_agenda(appointments).deliver

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal I18n.t("mailers.doctor.today_agenda.subject"), email.subject
    assert_match /Hello Rebecca,/, email.encoded

  end

end
