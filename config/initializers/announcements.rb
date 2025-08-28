# frozen_string_literal: true

# Announcements initializer
# Loads announcements configuration and makes it available throughout the app

module Announcements
  class << self
    def current_announcements
      @announcements ||= load_announcements
    end

    def announcement_for_version(version)
      current_announcements.find { |a| a['version'] == version }
    end

    private

    def load_announcements
      config_file = Rails.root.join('config', 'announcements.yml')
      return [] unless File.exist?(config_file)

      config = YAML.load_file(config_file)
      config['announcements'] || []
    rescue StandardError => e
      Rails.logger.error "Failed to load announcements: #{e.message}"
      []
    end
  end
end
