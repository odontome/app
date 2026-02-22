# frozen_string_literal: true

class UserConsent < ApplicationRecord
  CURRENT_TERMS_VERSION = "1.1"
  CURRENT_PRIVACY_VERSION = "1.1"
  CURRENT_AI_VERSION = "1.0"

  belongs_to :user
  belongs_to :practice

  validates :consent_type, presence: true, inclusion: { in: %w[terms privacy ai_data_processing] }
  validates :policy_version, presence: true
  validates :accepted_at, presence: true
  validates :user_id, uniqueness: { scope: [:consent_type, :policy_version] }

  scope :current_terms, -> { where(consent_type: "terms", policy_version: CURRENT_TERMS_VERSION) }
  scope :current_privacy, -> { where(consent_type: "privacy", policy_version: CURRENT_PRIVACY_VERSION) }
  scope :current_ai, -> { where(consent_type: "ai_data_processing", policy_version: CURRENT_AI_VERSION) }

  def self.accepted?(user, consent_type)
    current_version = case consent_type
                      when "terms" then CURRENT_TERMS_VERSION
                      when "privacy" then CURRENT_PRIVACY_VERSION
                      when "ai_data_processing" then CURRENT_AI_VERSION
                      end

    where(user: user, consent_type: consent_type, policy_version: current_version).exists?
  end
end
