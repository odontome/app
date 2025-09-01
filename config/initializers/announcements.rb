# frozen_string_literal: true

module Announcements
  class << self
    def current_announcements
      @announcements ||= load_announcements
    end

    def announcement_for_version(version)
      current_announcements.find { |a| a['version'] == version }
    end

    # Force reload from disk (useful in tests & development)
    def reload!
      @announcements = load_announcements
    end

    private

    def load_announcements
      config_file = Rails.root.join('config', 'announcements.yml')
      return [] unless File.exist?(config_file)

      raw = ERB.new(File.read(config_file)).result

      # Use safe_load to avoid deserializing arbitrary Ruby objects.
      permitted_classes = [Date, Time]
      # Use keyword args for compatibility with different Psych versions.
      parsed = YAML.safe_load(raw, permitted_classes: permitted_classes, aliases: true)

      parsed && parsed['announcements'] ? parsed['announcements'] : []
    rescue StandardError => e
      Rails.logger.error "Failed to load announcements: #{e.message}"
      []
    end
  end
end
