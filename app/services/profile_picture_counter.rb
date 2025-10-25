# frozen_string_literal: true

class ProfilePictureCounter
  TRACKED_MODELS = [Doctor, Patient, User].freeze

  class << self
    def counts_for_practices(practices)
      practice_ids = Array(practices).map { |practice| practice.respond_to?(:id) ? practice.id : practice }
      practice_ids = practice_ids.compact.uniq
      return Hash.new(0) if practice_ids.empty?

      counts = Hash.new(0)

      TRACKED_MODELS.each do |model|
        next unless model.column_names.include?('practice_id')

        model.joins(:profile_picture_attachment)
             .where(practice_id: practice_ids)
             .group(:practice_id)
             .count
             .each do |practice_id, total|
               counts[practice_id] += total
             end
      end

      counts
    end
  end

  def initialize(practice:)
    @practice = practice
  end

  def count
    return 0 if practice.nil?

    self.class.counts_for_practices(practice).fetch(practice.id, 0)
  end

  private

  attr_reader :practice
end
