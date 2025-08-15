# frozen_string_literal: true

class BalancesController < ApplicationController
  before_action :require_user

  def index
    @patient = Patient.with_practice(current_user.practice_id).find(params[:patient_id])
    @balances = Balance.where('patient_id = ?', @patient.id)
    @total = Balance.where('patient_id = ?', params[:patient_id]).sum(:amount)
    @treatments = Treatment.with_practice(current_user.practice_id).order('name')
    @practice = @patient.practice

    respond_to do |format|
      format.html
      format.csv do
        headers['Content-Type'] = 'text/csv'
        headers['Content-disposition'] = "attachment; filename=#{@patient.fullname}.csv"
      end
    end
  end

  def create
    @balance = Balance.new(balance_params)
    patient = Patient.with_practice(current_user.practice_id).find(params[:patient_id])
    @balance.patient_id = patient.id

    respond_to do |format|
      if @balance.save
        @total = Balance.where('patient_id = ?', params[:patient_id]).sum(:amount)

        format.js {} # create.js.erb
      else
        format.js do
          render_ujs_error(@balance, I18n.t(:balance_created_error_message))
        end
      end
    end
  end

  private

  def balance_params
    params.require(:balance).permit(:patient_id, :amount, :notes, :currency)
  end
end
