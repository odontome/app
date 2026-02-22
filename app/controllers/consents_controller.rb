# frozen_string_literal: true

class ConsentsController < ApplicationController
  layout 'user_sessions'

  before_action :require_user
  skip_before_action :check_consent_status
  skip_before_action :check_subscription_status

  def review
    @needs_terms = !current_user.accepted_current_terms?
    @needs_privacy = !current_user.accepted_current_privacy?

    redirect_to root_path if !@needs_terms && !@needs_privacy
  end

  def accept
    now = Time.current

    if !current_user.accepted_current_terms? && params[:consent_terms] == "1"
      UserConsent.create!(
        user: current_user,
        practice: current_user.practice,
        consent_type: "terms",
        policy_version: UserConsent::CURRENT_TERMS_VERSION,
        accepted_at: now,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    if !current_user.accepted_current_privacy? && params[:consent_privacy] == "1"
      UserConsent.create!(
        user: current_user,
        practice: current_user.practice,
        consent_type: "privacy",
        policy_version: UserConsent::CURRENT_PRIVACY_VERSION,
        accepted_at: now,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    if current_user.accepted_current_terms? && current_user.accepted_current_privacy?
      redirect_to root_path, notice: I18n.t(:consent_accepted)
    else
      redirect_to consent_review_path, alert: I18n.t(:consent_required)
    end
  end
end
