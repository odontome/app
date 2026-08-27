# frozen_string_literal: true

module Api
  module Agent
    class BaseController < ActionController::Base
      protect_from_forgery with: :null_session

      before_action :authenticate_agent!
      before_action :set_paper_trail_whodunnit

      private

      def authenticate_agent!
        raw_token = extract_bearer_token.to_s
        return render_unauthorized if raw_token.blank?

        access_token = AgentOauthAccessToken.active.find_by(
          token_digest: AgentOauthAccessToken.digest(raw_token),
          resource: resource_url
        )
        @practice = access_token&.practice

        render_unauthorized unless @practice&.agent_access_eligible?
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

      def set_paper_trail_whodunnit
        label = @practice&.agent_label.presence || I18n.t('agents.default_label')
        PaperTrail.request.whodunnit = "agent:#{label}"
      end
    end
  end
end
