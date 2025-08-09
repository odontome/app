# frozen_string_literal: true

module Analytics
  class AppointmentAnalytics
    HOURS_SQL = 'SUM(EXTRACT(EPOCH FROM (appointments.ends_at - appointments.starts_at)))/3600.0 AS hours'

    def initialize(practice_id)
      @practice_id = practice_id
    end

    # Returns [names[], values[]]
    def top_doctors_by_unique_patients(range, limit: 10)
      scope = Appointment
                .joins(:doctor)
                .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
                .where(doctors: { practice_id: @practice_id })
                .group('doctors.id', 'doctors.firstname', 'doctors.lastname')
                .select('doctors.id, doctors.firstname, doctors.lastname, COUNT(DISTINCT appointments.patient_id) AS patients_count')
                .order('patients_count DESC')
                .limit(limit)
      [scope.map { |d| [d.firstname, d.lastname].join(' ') }, scope.map { |d| d.read_attribute(:patients_count).to_i }]
    end

    # Returns [names[], values[]]
    def hours_worked_by_doctor(range, limit: 10)
      scope = Appointment
                .joins(:doctor)
                .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
                .where(doctors: { practice_id: @practice_id })
                .group('doctors.id', 'doctors.firstname', 'doctors.lastname')
                .select("doctors.id, doctors.firstname, doctors.lastname, #{HOURS_SQL}")
                .order('hours DESC')
                .limit(limit)
      [scope.map { |d| [d.firstname, d.lastname].join(' ') }, scope.map { |d| d.read_attribute(:hours).to_f.round(1) }]
    end

    # Returns [names[], values[]]
    def recurring_patients(range, limit: 10)
      scope = Appointment
                .joins(:patient)
                .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
                .where(patients: { practice_id: @practice_id })
                .group('patients.id', 'patients.firstname', 'patients.lastname')
                .select('patients.id, patients.firstname, patients.lastname, COUNT(*) AS appointments_count')
                .order('appointments_count DESC')
                .limit(limit)
      [scope.map { |p| [p.firstname, p.lastname].join(' ') }, scope.map { |p| p.read_attribute(:appointments_count).to_i }]
    end

    # Returns [names[], values[]]
    def average_gap_minutes_by_doctor(range, limit: 10)
      appts = Appointment
                .joins(:doctor)
                .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
                .where(doctors: { practice_id: @practice_id })
                .select('appointments.id, appointments.starts_at, appointments.ends_at, appointments.doctor_id, doctors.firstname, doctors.lastname')
                .order('appointments.doctor_id ASC, appointments.starts_at ASC')

      gaps_by_doctor = {}
      names_by_doctor = {}
      appts.group_by(&:doctor_id).each do |doctor_id, list|
        prev_end = nil
        gaps = []
        list.each do |a|
          if prev_end
            gap = ((a.starts_at - prev_end) / 60.0).to_f
            gaps << gap if gap.positive?
          end
          prev_end = a.ends_at
        end
        next if gaps.empty?
        gaps_by_doctor[doctor_id] = (gaps.sum / gaps.size).round(1)
        doc = list.first
        names_by_doctor[doctor_id] = [doc.firstname, doc.lastname].join(' ')
      end

      sorted = gaps_by_doctor.sort_by { |_id, avg| avg }.first(limit)
      [sorted.map { |id, _| names_by_doctor[id] }, sorted.map { |_, avg| avg }]
    end

    # Returns [labels[], counts[]]
    def appointments_per_day(range)
      rel = Appointment
              .joins(:patient)
              .where(patients: { practice_id: @practice_id })
              .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
      counts = Analytics::TimeSeries.count_by_day(rel, 'appointments.starts_at')
      [Analytics::TimeSeries.labels_for(range), Analytics::TimeSeries.normalize_daily(range, counts)]
    end

    # Returns [new_count, returning_count]
    def new_vs_returning(range)
      uniq_patients = Appointment
                        .joins(:patient)
                        .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
                        .where(patients: { practice_id: @practice_id })
                        .select('DISTINCT patients.id, patients.created_at')
      new_count = 0
      returning_count = 0
      uniq_patients.each do |p|
        if p.created_at && p.created_at >= range.begin && p.created_at <= range.end
          new_count += 1
        else
          returning_count += 1
        end
      end
      [new_count, returning_count]
    end

    # KPI total count for range
    def count(range)
      Appointment
        .joins(:patient)
        .where(patients: { practice_id: @practice_id })
        .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', range.begin, range.end)
        .count
    end
  end
end
