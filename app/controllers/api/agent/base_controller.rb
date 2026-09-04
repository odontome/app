# frozen_string_literal: true

module Api
  module Agent
    class BaseController < ActionController::Base
      protect_from_forgery with: :null_session

      before_action :authenticate_agent!
      around_action :attribute_ai_activity

      private

      def authenticate_agent!
        raw_token = extract_bearer_token.to_s
        return render_unauthorized if raw_token.blank?

        access_token = AgentOauthAccessToken.active.find_by(
          token_digest: AgentOauthAccessToken.digest(raw_token),
          resource: resource_url
        )
        @practice = access_token&.practice
        @agent_user = access_token&.user

        render_unauthorized unless @practice&.agent_access_eligible? && @agent_user&.practice_id == @practice.id
      end

      def extract_bearer_token
        header = request.headers['Authorization'].to_s
        header.start_with?('Bearer ') ? header.delete_prefix('Bearer ') : nil
      end

      def resource_url
        "#{request.base_url}/api/agent/mcp"
      end

      def render_unauthorized
        response.headers['WWW-Authenticate'] = %(Bearer resource_metadata="#{request.base_url}/.well-known/oauth-protected-resource", error="invalid_token", error_description="A valid Odonto.me access token is required")
        render json: { error: I18n.t('agents.errors.unauthorized') }, status: :unauthorized
      end

      def attribute_ai_activity(&action)
        return yield unless @agent_user

        PaperTrail.request(whodunnit: @agent_user.id, controller_info: { activity_source: 'ai' }, &action)
      end
    end
  end
end
