# frozen_string_literal: true

class AgentOauthAccessToken < ApplicationRecord
  belongs_to :user
  belongs_to :practice

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
end
