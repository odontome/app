# frozen_string_literal: true

module Api
  module Agent
    class OauthController < ApplicationController
      skip_before_action :check_account_status, :check_subscription_status, :check_consent_status,
                         :find_datebooks, :prevent_impersonation_mutations, :set_paper_trail_whodunnit
      skip_forgery_protection only: :token

      CHATGPT_CLIENT_ID = "https://chatgpt.com/oauth/client.json"
      CHATGPT_REDIRECT_URI = "https://chatgpt.com/connector_platform_oauth_redirect"
      CODE_LIFETIME = 5.minutes
      TOKEN_LIFETIME = 1.hour

      def openai_apps_challenge
        render plain: ENV.fetch("OPENAI_APPS_CHALLENGE_TOKEN", ""), content_type: "text/plain"
      end

      def protected_resource_metadata
        render json: { resource: resource_url, authorization_servers: [request.base_url], scopes_supported: [] }
      end

      def authorization_server_metadata
        base = request.base_url
        render json: { issuer: base, authorization_endpoint: "#{base}/api/agent/oauth/authorize",
                       token_endpoint: "#{base}/api/agent/oauth/token", response_types_supported: ["code"],
                       grant_types_supported: ["authorization_code"], code_challenge_methods_supported: ["S256"],
                       token_endpoint_auth_methods_supported: ["none"], client_id_metadata_document_supported: true,
                       authorization_response_iss_parameter_supported: true }
      end

      def authorize
        return authorization_error("invalid_request") unless valid_authorization_request?
        unless current_user
          session[:return_to] = request.fullpath
          redirect_to signin_path and return
        end
        return authorization_error("access_denied") unless current_user.practice.agent_access_eligible?
        unless current_user.accepted_current_terms? && current_user.accepted_current_privacy?
          session[:return_to] = request.fullpath
          redirect_to consent_review_path and return
        end

        @approval_token = SecureRandom.urlsafe_base64(48)
        @authorization = AgentOauthAuthorization.create!(user: current_user, practice: current_user.practice,
          approval_token_digest: AgentOauthAuthorization.digest(@approval_token), client_id: params[:client_id],
          redirect_uri: params[:redirect_uri], code_challenge: params[:code_challenge], resource: params[:resource],
          state: params[:state], expires_at: CODE_LIFETIME.from_now)
        render :authorize, layout: false
      end

      def approve
        authorization = current_user && AgentOauthAuthorization.find_by(id: params[:authorization_id], user: current_user, consumed_at: nil)
        return oauth_error("invalid_request") unless authorization

        raw_code = SecureRandom.urlsafe_base64(48)
        approved = false
        authorization.with_lock do
          next unless authorization.expires_at.future? && authorization.approved_at.nil? &&
                      secure_match?(params[:approval_token], authorization.approval_token_digest) &&
                      authorization.practice.agent_access_eligible?

          authorization.update!(code_digest: AgentOauthAuthorization.digest(raw_code), approved_at: Time.current)
          approved = true
        end
        return redirect_authorization_error(authorization, "access_denied") unless approved

        redirect_authorization(authorization, code: raw_code)
      end

      def token
        return oauth_error("unsupported_grant_type") unless params[:grant_type] == "authorization_code"
        raw_token = nil

        AgentOauthAuthorization.transaction do
          authorization = AgentOauthAuthorization.lock.find_by(code_digest: AgentOauthAuthorization.digest(params[:code].to_s))
          next unless valid_token_exchange?(authorization)

          authorization.update!(consumed_at: Time.current)
          raw_token = "odonto_mcp_#{SecureRandom.urlsafe_base64(48)}"
          AgentOauthAccessToken.create!(user: authorization.user, practice: authorization.practice,
            token_digest: AgentOauthAccessToken.digest(raw_token), resource: authorization.resource, expires_at: TOKEN_LIFETIME.from_now)
        end

        return oauth_error("invalid_grant") unless raw_token

        response.headers["Cache-Control"] = "no-store"
        response.headers["Pragma"] = "no-cache"
        render json: { access_token: raw_token, token_type: "Bearer", expires_in: TOKEN_LIFETIME.to_i }
      end

      private

      def resource_url
        "#{request.base_url}/api/agent/mcp"
      end

      def valid_authorization_request?
        params[:response_type] == "code" && params[:client_id] == CHATGPT_CLIENT_ID && params[:redirect_uri] == CHATGPT_REDIRECT_URI &&
          params[:code_challenge_method] == "S256" && params[:code_challenge].present? && params[:resource] == resource_url
      end

      def valid_token_exchange?(authorization)
        return false unless authorization&.approved_at? && authorization.consumed_at.nil? && authorization.expires_at.future?
        return false unless authorization.practice.agent_access_eligible?
        return false unless params[:client_id] == authorization.client_id && params[:redirect_uri] == authorization.redirect_uri && params[:resource] == authorization.resource

        expected = Base64.urlsafe_encode64(Digest::SHA256.digest(params[:code_verifier].to_s), padding: false)
        ActiveSupport::SecurityUtils.secure_compare(expected, authorization.code_challenge)
      end

      def secure_match?(value, digest)
        ActiveSupport::SecurityUtils.secure_compare(AgentOauthAuthorization.digest(value.to_s), digest)
      end

      def authorization_error(error)
        if params[:client_id] == CHATGPT_CLIENT_ID && params[:redirect_uri] == CHATGPT_REDIRECT_URI
          redirect_authorization_response(CHATGPT_REDIRECT_URI, error: error, state: params[:state])
        else
          oauth_error(error)
        end
      end

      def redirect_authorization_error(authorization, error)
        redirect_authorization_response(authorization.redirect_uri, error: error, state: authorization.state)
      end

      def redirect_authorization(authorization, code:)
        redirect_authorization_response(authorization.redirect_uri, code: code, state: authorization.state)
      end

      def redirect_authorization_response(redirect_uri, code: nil, error: nil, state: nil)
        uri = URI.parse(redirect_uri)
        query = URI.decode_www_form(uri.query.to_s)
        query << ["code", code] if code
        query << ["error", error] if error
        query << ["state", state] if state.present?
        query << ["iss", request.base_url]
        uri.query = URI.encode_www_form(query)
        redirect_to uri.to_s, allow_other_host: true
      end

      def oauth_error(error, status = :bad_request)
        render json: { error: error }, status: status
      end
    end
  end
end
