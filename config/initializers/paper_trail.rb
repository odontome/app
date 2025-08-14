# frozen_string_literal: true

PaperTrail.config.enabled = !Rails.env.test?
PaperTrail.config.version_limit = 1
PaperTrail.config.object_changes_adapter = :json
PaperTrail.config.serializer = PaperTrail::Serializers::JSON
PaperTrail.config.has_paper_trail_defaults = {
  on: %i[create update destroy],
  save_changes: true
}
