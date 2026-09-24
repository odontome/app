# frozen_string_literal: true

require 'test_helper'

class BirthdayWishesTaskTest < RakeTaskTestCase
  rake_task 'odontome:send_birthday_wishes_to_patients'

  test 'birthday notifications exclude missing birthdays and other dates' do
    travel_to Time.utc(2026, 1, 15, 15) do
      practices(:trialing_practice).update!(timezone: 'America/Mexico_City')
      birthday_patient = patients(:one)
      birthday_patient.update_columns(date_of_birth: Date.new(1985, 1, 15), email: 'birthday@example.test')
      unknown_birthday = patients(:two)
      unknown_birthday.update_columns(date_of_birth: nil, email: 'unknown@example.test')
      another_birthday = patients(:four)
      another_birthday.update_columns(date_of_birth: Date.new(1985, 1, 16), email: 'tomorrow@example.test')
      ActionMailer::Base.deliveries.clear

      assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
        @task.invoke
      end

      assert_equal ['birthday@example.test'], ActionMailer::Base.deliveries.last.to
      assert_nil unknown_birthday.reload.date_of_birth
    end
  end
end
