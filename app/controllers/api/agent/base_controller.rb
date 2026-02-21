# frozen_string_literal: true

module Api
  module Agent
    class BaseController < ActionController::Base
      protect_from_forgery with: :null_session

      before_action :authenticate_agent!
      before_action :set_paper_trail_whodunnit

      private

      def authenticate_agent!
        raw_key = request.headers['X-Agent-Key'].presence ||
                  request.headers['HTTP_X_AGENT_KEY'].presence ||
                  extract_bearer_token
        raw_key = raw_key.to_s
        if raw_key.blank?
          render json: { error: I18n.t('agents.errors.unauthorized') }, status: :unauthorized
          return
        end

        digest = Practice.agent_api_key_digest(raw_key)
        @practice = Practice.find_by(agent_api_key_digest: digest)

        unless @practice&.agent_access_enabled? && @practice&.agent_api_key_valid?(raw_key)
          render json: { error: I18n.t('agents.errors.unauthorized') }, status: :unauthorized
          return
        end
      end

      def extract_bearer_token
        header = request.headers['Authorization'].to_s
        header.start_with?('Bearer ') ? header.delete_prefix('Bearer ') : nil
      end

      def set_paper_trail_whodunnit
        label = @practice&.agent_label.presence || I18n.t('agents.default_label')
        PaperTrail.request.whodunnit = "agent:#{label}"
      end
    end
  end
end
