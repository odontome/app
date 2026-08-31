# frozen_string_literal: true

module Api
  module Agent
    class OauthController < ApplicationController
      layout "simple", only: :authorize

      skip_before_action :check_account_status, :check_subscription_status, :check_consent_status,
                         :find_datebooks, :prevent_impersonation_mutations, :set_paper_trail_whodunnit
      skip_forgery_protection only: :token

      CODE_LIFETIME = 5.minutes

      rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip },
                 with: -> { oauth_error('slow_down', :too_many_requests) }, only: :authorize, name: 'oauth_authorize'
      rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip },
                 with: -> { oauth_error('slow_down', :too_many_requests) }, only: [:approve, :token], name: 'oauth_credentials'
      prepend_before_action :prevent_token_caching, only: :token

      def openai_apps_challenge
        render plain: ENV.fetch("OPENAI_APPS_CHALLENGE_TOKEN", ""), content_type: "text/plain"
      end

      def protected_resource_metadata
        render json: { resource: resource_url, authorization_servers: [request.base_url], scopes_supported: ["offline_access"] }
      end

      def authorization_server_metadata
        base = request.base_url
        render json: { issuer: base, authorization_endpoint: "#{base}/api/agent/oauth/authorize",
                       token_endpoint: "#{base}/api/agent/oauth/token", response_types_supported: ["code"],
                       grant_types_supported: ["authorization_code", "refresh_token"], scopes_supported: ["offline_access"],
                       code_challenge_methods_supported: ["S256"],
                       token_endpoint_auth_methods_supported: ["none"], client_id_metadata_document_supported: true,
                       authorization_response_iss_parameter_supported: true }
      end

      def authorize
        @client = oauth_client(params[:client_id])
        return render(:unknown_client, status: :bad_request) unless @client
        return oauth_error("invalid_request") unless @client.redirect_uri_allowed?(params[:redirect_uri])
        return authorization_error("invalid_request") unless valid_authorization_request?
        return authorization_error("invalid_scope") unless valid_scope?(@client.refresh_tokens?)
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
        current_user.practice.with_lock do
          next unless current_user.practice.agent_access_eligible?

          @authorization = AgentOauthAuthorization.create!(user: current_user, practice: current_user.practice,
            approval_token_digest: AgentOauthAuthorization.digest(@approval_token), client_id: @client.client_id,
            redirect_uri: params[:redirect_uri], code_challenge: params[:code_challenge], resource: resource_url,
            state: params[:state], refresh_allowed: @client.refresh_tokens?, expires_at: CODE_LIFETIME.from_now)
        end
        return authorization_error("access_denied") unless @authorization
        render :authorize
      end

      def approve
        authorization = current_user && AgentOauthAuthorization.find_by(id: params[:authorization_id], user: current_user, consumed_at: nil)
        return oauth_error("invalid_request") unless authorization

        raw_code = authorization.approve(params[:approval_token].to_s)
        return redirect_authorization_error(authorization, "access_denied") unless raw_code

        redirect_authorization(authorization, code: raw_code)
      end

      def token
        if request.authorization.present? || params.key?(:client_secret) || params.key?(:client_assertion) || params.key?(:client_assertion_type)
          return oauth_error("invalid_client")
        end

        result = case params[:grant_type]
                 when "authorization_code" then exchange_code
                 when "refresh_token"
                   return oauth_error("invalid_scope") unless valid_scope?(true)
                   refresh_token
                 else return oauth_error("unsupported_grant_type")
                 end
        return oauth_error("invalid_grant") unless result

        render json: result
      end

      private

      def resource_url
        "#{request.base_url}/api/agent/mcp"
      end

      def prevent_token_caching
        response.headers['Cache-Control'] = 'no-store'
        response.headers['Pragma'] = 'no-cache'
      end

      def oauth_client(client_id)
        AgentOauthClient.find(client_id)
      end

      def valid_authorization_request?
        params[:response_type] == "code" && params[:code_challenge_method] == "S256" &&
          params[:code_challenge].is_a?(String) && params[:code_challenge].match?(/\A[A-Za-z0-9_-]{43}\z/) &&
          (params[:state].nil? || params[:state].is_a?(String)) && normalized_resource(params[:resource]) == resource_url
      end

      def exchange_code
        verifier = params[:code_verifier]
        return unless verifier.is_a?(String) && verifier.match?(/\A[A-Za-z0-9._~-]{43,128}\z/)
        return unless params[:code].is_a?(String)

        authorization = AgentOauthAuthorization.find_by(code_digest: AgentOauthAuthorization.digest(params[:code]))
        authorization&.exchange(client_id: params[:client_id], redirect_uri: params[:redirect_uri],
          resource: normalized_resource(params[:resource]), code_verifier: verifier)
      end

      def refresh_token
        return unless params[:refresh_token].is_a?(String)
        return unless params[:client_id].nil? || params[:client_id].is_a?(String)

        token = AgentOauthAccessToken.find_by(refresh_token_digest: AgentOauthAccessToken.digest(params[:refresh_token]))
        token&.refresh(client_id: params[:client_id],
          resource: params.key?(:resource) ? normalized_resource(params[:resource]) : resource_url)
      end

      def normalized_resource(value)
        uri = AgentOauthClient.parse_uri(value)
        return unless uri && uri.userinfo.nil? && uri.fragment.nil?

        uri.scheme = uri.scheme.downcase
        uri.host = uri.host.downcase
        uri.to_s
      end

      def valid_scope?(refresh_allowed)
        return true unless params.key?(:scope)

        params[:scope].is_a?(String) && (params[:scope].split - (refresh_allowed ? ['offline_access'] : [])).empty?
      end

      def authorization_error(error)
        # Only called after the metadata and exact callback have been validated.
        redirect_authorization_response(params[:redirect_uri], error: error,
          state: params[:state].is_a?(String) ? params[:state] : nil)
      end

      def redirect_authorization_error(authorization, error)
        redirect_authorization_response(authorization.redirect_uri, error: error, state: authorization.state)
      end

      def redirect_authorization(authorization, code:)
        redirect_authorization_response(authorization.redirect_uri, code: code, state: authorization.state)
      end

      def redirect_authorization_response(redirect_uri, code: nil, error: nil, state: nil)
        uri = URI.parse(redirect_uri)
        query = []
        query << ["code", code] if code
        query << ["error", error] if error
        query << ["state", state] unless state.nil?
        query << ["iss", request.base_url]
        uri.query = [uri.query, URI.encode_www_form(query)].compact.join('&')
        redirect_to uri.to_s, allow_other_host: true
      end

      def oauth_error(error, status = :bad_request)
        render json: { error: error }, status: status
      end
    end
  end
end
