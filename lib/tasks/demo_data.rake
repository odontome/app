# frozen_string_literal: true

namespace :demo do
  desc 'Seed rich demo data for charts (development only)'
  task seed: :environment do
    if Rails.env.production?
      puts 'Refusing to seed demo data in production.'
      next
    end

    user = User.first
    unless user && user.practice
      puts 'No user or practice found. Create an account first.'
      next
    end

    practice = user.practice
    puts "Seeding demo data for practice ##{practice.id} - #{practice.name}"

    # Create datebook if missing
    datebook = practice.datebooks.first || Datebook.create!(practice: practice, name: 'Main', starts_at: 8.hours, ends_at: 18.hours)

    # Doctors
    fnames = %w[Alex Jamie Taylor Jordan Casey Riley Morgan Cameron Avery Quinn Skyler Drew Peyton]
    lnames = %w[Smith Johnson Williams Brown Jones Miller Davis Garcia Rodriguez Wilson Martinez Anderson]
    colors = %w[#3b82f6 #10b981 #f59e0b #ef4444 #8b5cf6 #06b6d4 #84cc16 #ec4899]

    while practice.doctors.count < 8
      Doctor.create!(
        practice: practice,
        firstname: fnames.sample,
        lastname: lnames.sample,
        email: nil,
        gender: %w[male female].sample,
        is_active: true,
        color: colors.sample
      )
    end

    # Patients
    require 'faker'
    Faker::Config.locale = 'en'
    target_patients = 120
    (target_patients - practice.patients.count).times do
      Patient.create!(
        practice: practice,
        firstname: Faker::Name.first_name,
        lastname: Faker::Name.last_name,
        date_of_birth: Faker::Date.birthday(min_age: 5, max_age: 90)
      )
    end

    # Appointments for last 8 weeks
    doctors = practice.doctors.valid.to_a
    patients = practice.patients.to_a
    now = Time.zone.now
    start_time = (now - 8.weeks).beginning_of_week
    end_time = now.end_of_week

    puts 'Creating appointments...'
    ((start_time.to_date)..(end_time.to_date)).each do |date|
      # heavier load on weekdays
      day_multiplier = date.on_weekend? ? 0.4 : 1.0
      (4 * day_multiplier).round.times do
        doctor = doctors.sample
        patient = patients.sample
        hour = rand(9..16)
        minute = [0, 15, 30, 45].sample
        starts_at = Time.zone.local(date.year, date.month, date.day, hour, minute)
        duration = [30, 45, 60, 90].sample.minutes
        ends_at = starts_at + duration
        Appointment.create!(datebook: datebook, doctor: doctor, patient: patient, starts_at: starts_at, ends_at: ends_at, notes: '')
      end
    end

    # Balances (simulate payments) for last 8 weeks
    puts 'Creating balances...'
    ((start_time.to_date)..(end_time.to_date)).each do |date|
      rand(2..8).times do
        patient = patients.sample
        amount = [50, 75, 100, 125, 150, 200].sample
        Balance.create!(patient: patient, amount: amount, created_at: Time.zone.local(date.year, date.month, date.day, rand(10..17), [0,15,30,45].sample), notes: 'Procedure')
      end
    end

    puts 'Demo data created. Open /practice to view charts.'
  end
end
