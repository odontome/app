# frozen_string_literal: true

class AgentOauthAuthorization < ApplicationRecord
  belongs_to :user
  belongs_to :practice

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
end
