# frozen_string_literal: true

class AgentOauthAccessToken < ApplicationRecord
  belongs_to :user
  belongs_to :practice
  belongs_to :agent_oauth_authorization, optional: true # Legacy tokens have no refresh grant.

  ACCESS_LIFETIME = 1.hour
  REFRESH_LIFETIME = 90.days

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # Called only while holding the authorization's practice lock.
  def self.issue!(authorization)
    access_token = "odonto_mcp_#{SecureRandom.urlsafe_base64(48)}"
    attributes = { user: authorization.user, practice: authorization.practice, agent_oauth_authorization: authorization,
                   resource: authorization.resource, token_digest: digest(access_token), expires_at: ACCESS_LIFETIME.from_now }
    response = { access_token: access_token, token_type: 'Bearer', expires_in: ACCESS_LIFETIME.to_i, scope: '' }
    if authorization.refresh_allowed?
      refresh_token = "odonto_mcr_#{SecureRandom.urlsafe_base64(48)}"
      attributes.merge!(refresh_token_digest: digest(refresh_token), refresh_expires_at: REFRESH_LIFETIME.from_now)
      response.merge!(refresh_token: refresh_token, scope: 'offline_access')
    end
    create!(attributes)
    response
  end

  def refresh(client_id:, resource:)
    practice.with_lock do
      reload
      next unless practice.agent_access_eligible? && revoked_at.nil? && refresh_expires_at&.future?
      next unless resource == self.resource && (client_id.nil? || client_id == agent_oauth_authorization.client_id)

      if refresh_consumed_at?
        agent_oauth_authorization.access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
        next
      end

      # In-flight calls may use old access tokens until expiry. Reuse or
      # disconnection revokes this family's access AND refresh credentials.
      update!(refresh_consumed_at: Time.current)
      self.class.issue!(agent_oauth_authorization)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
end
