# frozen_string_literal: true

class AgentOauthAuthorization < ApplicationRecord
  belongs_to :user
  belongs_to :practice
  has_many :access_tokens, class_name: 'AgentOauthAccessToken', dependent: :delete_all

  # Practice is always locked first, including during revocation. This also
  # serializes code redemption and refresh rotation across a token family.
  def approve(approval_token)
    practice.with_lock do
      reload
      next unless practice.agent_access_eligible? && expires_at.future? && approved_at.nil? && consumed_at.nil?
      next unless ActiveSupport::SecurityUtils.secure_compare(self.class.digest(approval_token), approval_token_digest)

      code = SecureRandom.urlsafe_base64(48)
      update!(code_digest: self.class.digest(code), approved_at: Time.current)
      code
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def exchange(client_id:, redirect_uri:, resource:, code_verifier:)
    practice.with_lock do
      reload
      next unless practice.agent_access_eligible? && approved_at? && expires_at.future?
      next unless client_id == self.client_id && redirect_uri == self.redirect_uri && resource == self.resource

      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
      next unless ActiveSupport::SecurityUtils.secure_compare(challenge, code_challenge)

      if consumed_at?
        access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
        next
      end

      update!(consumed_at: Time.current)
      AgentOauthAccessToken.issue!(self)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
end
