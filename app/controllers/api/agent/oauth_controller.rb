# frozen_string_literal: true

module Api
  module Agent
    class OauthController < ActionController::Base
      protect_from_forgery with: :null_session

      ALLOWED_ORIGINS = %w[
        https://claude.ai
        https://claude.com
      ].freeze

      after_action :set_cors_headers

      AUTH_CODE_STORE_MUTEX = Mutex.new
      AUTH_CODE_STORE = {}

      def openai_apps_challenge
        token = ENV["OPENAI_APPS_CHALLENGE_TOKEN"].to_s
        render plain: token, content_type: "text/plain"
      end

      def protected_resource_metadata
        render json: {
          resource: "#{request.base_url}/api/agent/mcp",
          authorization_servers: [request.base_url.to_s],
          scopes_supported: []
        }
      end

      def authorization_server_metadata
        base = request.base_url.to_s

        render json: {
          issuer: base,
          authorization_endpoint: "#{base}/api/agent/oauth/authorize",
          token_endpoint: "#{base}/api/agent/oauth/token",
          response_types_supported: ["code"],
          grant_types_supported: %w[authorization_code client_credentials],
          code_challenge_methods_supported: ["S256"],
          token_endpoint_auth_methods_supported: %w[client_secret_post]
        }
      end

      ALLOWED_REDIRECT_PATTERNS = [
        # Claude Desktop & Claude Code (local)
        %r{\Ahttp://localhost:6274/oauth/callback(/debug)?\z},
        # Claude.ai and claude.com (web)
        %r{\Ahttps://claude\.(ai|com)/api/mcp/auth_callback\z},
        # ChatGPT (web)
        %r{\Ahttps://chatgpt\.com/(oauth/callback|connector_platform_oauth_redirect)\z},
        %r{\Ahttps://chat\.openai\.com/oauth/callback\z},
        # OpenAI Platform (review flow)
        %r{\Ahttps://platform\.openai\.com/apps-manage/oauth\z}
      ].freeze

      def authorize
        unless params[:redirect_uri].present? && valid_redirect_uri?(params[:redirect_uri])
          render json: { error: "invalid_redirect_uri" }, status: :bad_request
          return
        end

        code = SecureRandom.hex(32)

        AUTH_CODE_STORE_MUTEX.synchronize do
          cleanup_expired_codes
          AUTH_CODE_STORE[code] = {
            code_challenge: params[:code_challenge],
            client_id: params[:client_id],
            redirect_uri: params[:redirect_uri],
            expires_at: 5.minutes.from_now
          }
        end

        redirect_uri = URI.parse(params[:redirect_uri])
        query = URI.decode_www_form(redirect_uri.query || "")
        query << ["code", code]
        query << ["state", params[:state]] if params[:state].present?
        redirect_uri.query = URI.encode_www_form(query)

        redirect_to redirect_uri.to_s, allow_other_host: true
      end

      def token
        case params[:grant_type]
        when "client_credentials"
          handle_client_credentials
        when "authorization_code"
          handle_authorization_code
        else
          render json: { error: "unsupported_grant_type" }, status: :bad_request
        end
      end

      private

      def handle_client_credentials
        practice = validate_client_secret
        return unless practice

        render json: {
          access_token: params[:client_secret],
          token_type: "Bearer",
          expires_in: 3600
        }
      end

      def handle_authorization_code
        code = params[:code].to_s
        code_verifier = params[:code_verifier].to_s

        stored = AUTH_CODE_STORE_MUTEX.synchronize { AUTH_CODE_STORE.delete(code) }

        unless stored && stored[:expires_at] > Time.current
          render json: { error: "invalid_grant" }, status: :bad_request
          return
        end

        if stored[:code_challenge].present?
          expected = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
          unless ActiveSupport::SecurityUtils.secure_compare(expected, stored[:code_challenge])
            render json: { error: "invalid_grant" }, status: :bad_request
            return
          end
        end

        practice = validate_client_secret
        return unless practice

        render json: {
          access_token: params[:client_secret],
          token_type: "Bearer",
          expires_in: 3600
        }
      end

      def validate_client_secret
        client_secret = params[:client_secret].to_s

        if client_secret.blank?
          render json: { error: "invalid_client" }, status: :unauthorized
          return nil
        end

        digest = Practice.agent_api_key_digest(client_secret)
        practice = Practice.find_by(agent_api_key_digest: digest)

        unless practice&.agent_access_enabled? && practice&.agent_api_key_valid?(client_secret)
          render json: { error: "invalid_client" }, status: :unauthorized
          return nil
        end

        practice
      end

      def valid_redirect_uri?(uri)
        ALLOWED_REDIRECT_PATTERNS.any? { |pattern| uri.match?(pattern) }
      end

      def set_cors_headers
        origin = request.headers["Origin"].to_s
        return unless ALLOWED_ORIGINS.include?(origin)

        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      def cleanup_expired_codes
        AUTH_CODE_STORE.delete_if { |_, v| v[:expires_at] < Time.current }
      end
    end
  end
end
