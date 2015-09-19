require 'test_helper'

class PatientMailerTest < ActionMailer::TestCase
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
    assert_match "how was your experience at", mail.body.encoded
  end

end
