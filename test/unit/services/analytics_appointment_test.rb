# frozen_string_literal: true

require 'test_helper'

class AnalyticsAppointmentTest < ActiveSupport::TestCase
  def setup
    @range = Time.utc(2024, 1, 1)..Time.utc(2024, 1, 7, 23, 59, 59)
    @analytics = Analytics::AppointmentAnalytics.new(practices(:complete).id)

    # Include both endpoints, with a record just outside each end of the week.
    [-1.second, 0, 12.hours, 7.days - 1.second, 7.days].each do |offset|
      create_appointment(@range.begin + offset)
    end

    foreign_practice = practices(:trialing_practice)
    foreign_doctor = Doctor.create!(practice: foreign_practice, firstname: 'Other', lastname: 'Doctor')
    foreign_datebook = Datebook.create!(practice: foreign_practice, name: 'Other calendar')
    create_appointment(@range.begin + 2.days, patient: patients(:three), doctor: foreign_doctor, datebook: foreign_datebook)
  end

  test 'appointments_per_day returns exact labels and practice counts for the week' do
    labels, counts = @analytics.appointments_per_day(@range)

    assert_equal ['Mon 01', 'Tue 02', 'Wed 03', 'Thu 04', 'Fri 05', 'Sat 06', 'Sun 07'], labels
    assert_equal [2, 0, 0, 0, 0, 0, 1], counts
  end

  test 'count includes only this practice and the requested week' do
    assert_equal 3, @analytics.count(@range)
  end

  private

  def create_appointment(starts_at, patient: patients(:one),
                       doctor: doctors(:rebecca), datebook: datebooks(:playa_del_carmen))
    Appointment.create!(patient: patient, doctor: doctor, datebook: datebook,
                        starts_at: starts_at, ends_at: starts_at + 30.minutes)
  end
end
