# frozen_string_literal: true

PaperTrail.config.enabled = true
PaperTrail.config.version_limit = 100 # Keep only the last 100 versions per record

# Only track changes for logged-in users
PaperTrail.config.track_associations = false