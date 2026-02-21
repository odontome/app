# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin

  def index
    @filter_params = {
      user_id: params[:user_id]
    }

    # Start with practice-scoped versions using the metadata
    @versions = PaperTrail::Version.where(practice_id: current_user.practice_id)

    # Apply filters
    @versions = @versions.where(whodunnit: @filter_params[:user_id]) if @filter_params[:user_id].present?

    # Pagination setup
    @page = params[:page].to_i
    @page = 0 if @page < 0
    @per_page = 25

    # Get total count for pagination info
    @total_count = @versions.count
    @total_pages = (@total_count.to_f / @per_page).ceil
    @has_next_page = @page < (@total_pages - 1)
    @has_prev_page = @page > 0

    # Apply pagination and ordering
    @versions = @versions.order(created_at: :desc)
                         .limit(@per_page)
                         .offset(@page * @per_page)

    @practice_users = User.with_practice(current_user.practice_id).order('firstname')

    agent_whodunnit_values = PaperTrail::Version.where(practice_id: current_user.practice_id)
                                                 .where("whodunnit LIKE ?", 'agent:%')
                                                 .distinct
                                                 .pluck(:whodunnit)
    @agent_labels = agent_whodunnit_values.map { |value| value.to_s.delete_prefix('agent:') }.sort

    # Create hash for efficient user lookups in the view to avoid N+1 queries
    @users_hash = @practice_users.index_by(&:id)
  end

  def show
    @version = PaperTrail::Version.where(practice_id: current_user.practice_id).find(params[:id])
    @item = @version.item

    # When deleting an appointment, override the patient and doctor information
    if @version.item_type == 'Appointment' && @version.event == 'destroy'
      begin
        object = JSON.parse(@version.object)
        object['doctor_id'] = Doctor.find_by(id: object['doctor_id']).fullname
        object['patient_id'] = Patient.find_by(id: object['patient_id']).fullname

        @version.object = object.to_json
      end
    end

    @whodunnit_user = @version.whodunnit.present? ? User.find_by(id: @version.whodunnit) : nil
    @whodunnit_agent_label = agent_label_from(@version.whodunnit)
  end

  private

  def agent_label_from(whodunnit)
    return if whodunnit.blank?
    return unless whodunnit.to_s.start_with?('agent:')

    whodunnit.to_s.delete_prefix('agent:')
  end
end
