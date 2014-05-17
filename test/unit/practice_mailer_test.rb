# encoding: UTF-8
require 'test_helper'

class PracticeMailerTest < ActionMailer::TestCase

  test "practice welcome email" do
    practice = practices(:complete)
    practice.users << users(:founder)

    # Send the email, then test that it got queued
    email = PracticeMailer.welcome_email(practice).deliver
    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['raulriera@hotmail.com'], email.to
    assert_equal I18n.t("mailers.practice.welcome.subject"), email.subject
    #assert_equal read_fixture('welcome_email').join, email.body.to_s
    assert_match(/Hello and welcome to Odonto.me!/, email.encoded)
  end

  test "practice daily suggest email, patient only" do
    admin = [{
      "locale" => "en",
      "timezone" => "London",
      "email" => "contact@bokanova.mx",
      "currency_unit" => "€"
    }]

    today = Time.zone.now.beginning_of_day

    patients = [{
      "id" => 1,
      "firstname" => "Raul",
      "lastname" => "Riera",
      "email" => "raulriera@hotmail.com"
    }]

    # Send the email, then test that it got queued
    email = PracticeMailer.daily_recap_email(admin, patients, nil, nil, today).deliver

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.to
    assert_equal I18n.t("mailers.practice.daily_recap.subject", :date => I18n.l(today.to_date, :format => :day_and_date)), email.subject
    assert_match /1 patients added/, email.encoded

  end

  test "practice daily suggest email, appointments only" do
    admin = [{
      "locale" => "en",
      "timezone" => "London",
      "email" => "contact@bokanova.mx",
      "currency_unit" => "€"
    }]

    today = Time.zone.now.beginning_of_day

    appointments = [
      {
        "id" => 1,
        "name" => "Cuernavaca",
        "patient_firstname" => "Raul",
        "patient_lastname" => "Riera",
        "doctor_firstname" => "Rebecca",
        "doctor_lastname" => "Riera",
        "starts_at" => today - 2.hours,
        "email" => "raulriera@hotmail.com"
      },
      {
        "id" => 2,
        "name" => "Playa del Carmen",
        "patient_firstname" => "Raul",
        "patient_lastname" => "Riera",
        "doctor_firstname" => "Ruth",
        "doctor_lastname" => "Riera",
        "starts_at" => today - 2.hours,
        "email" => "raulriera@hotmail.com"
      }
    ]

    # Send the email, then test that it got queued
    email = PracticeMailer.daily_recap_email(admin, nil, appointments, nil, today).deliver

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.to
    assert_equal I18n.t("mailers.practice.daily_recap.subject", :date => I18n.l(today.to_date, :format => :day_and_date)), email.subject
    assert_match /2 appointments scheduled/, email.encoded

  end

  test "practice daily suggest email, balance only" do
    admin = [{
      "locale" => "en",
      "timezone" => "Mexico City",
      "email" => "contact@bokanova.mx",
      "currency_unit" => "$"
    }]

    today = Time.zone.now.beginning_of_day

    balance = [{
      "practice_id" => 1,
      "amount" => 1000
    }]

    # Send the email, then test that it got queued
    email = PracticeMailer.daily_recap_email(admin, nil, nil, balance, today).deliver

    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['hello@odonto.me'], email.from
    assert_equal ['contact@bokanova.mx'], email.to
    assert_equal I18n.t("mailers.practice.daily_recap.subject", :date => I18n.l(today.to_date, :format => :day_and_date)), email.subject
    assert_match /\$1,000.00 processed today/, email.encoded

  end

end
