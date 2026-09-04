# frozen_string_literal: true

class AiController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, only: :update
  skip_before_action :check_subscription_status, :check_consent_status

  def show
    @practice = current_user.practice
  end

  def update
    @practice = current_user.practice
    needs_ai_consent = agent_settings_params[:agent_access_enabled] == "1" && !UserConsent.accepted?(current_user, "ai_data_processing")

    if needs_ai_consent && params[:consent_ai] != "1"
      @practice.errors.add(:base, I18n.t(:consent_ai_required))
      render :show
      return
    end

    if @practice.update(agent_settings_params)
      if params[:consent_ai] == "1" && !UserConsent.accepted?(current_user, "ai_data_processing")
        UserConsent.create!(
          user: current_user,
          practice: @practice,
          consent_type: "ai_data_processing",
          policy_version: UserConsent::CURRENT_AI_VERSION,
          accepted_at: Time.current,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
      end

      app = params[:app] if %w[claude chatgpt].include?(params[:app])
      redirect_to ai_url(app: app), notice: t(:agent_settings_updated)
    else
      render :show
    end
  end

  private

  def agent_settings_params
    params.require(:practice).permit(:agent_access_enabled)
  end
end
