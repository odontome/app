# frozen_string_literal: true

module Api
  module Agent
    module Mcp
      module Instructions
        def self.for(practice)
          <<~TEXT.strip
            This practice's timezone is #{practice.timezone}. All times in tool responses are in this timezone. When the user says a time like '3pm', interpret it as #{practice.timezone}. Always send times as ISO 8601 strings with the correct offset for this timezone.

            The system does not prevent double-booking. Before creating an appointment, use list_appointments to check for conflicts in the same time slot.

            If ends_at is omitted when creating an appointment, it defaults to 60 minutes after starts_at.
          TEXT
        end
      end
    end
  end
end
