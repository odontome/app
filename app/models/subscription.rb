# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :practice

  enum :status, {
    trialing: 'trialing',
    active: 'active',
    past_due: 'past_due',
    canceled: 'canceled',
  }

  ACCESS_GRANTING_STATUSES = ['trialing', 'active', 'past_due']

  scope :active_or_trialing, -> { where(status: ACCESS_GRANTING_STATUSES) }
  scope :recent, -> { order("current_period_end DESC NULLS LAST") }

  def active_or_trialing?
    ACCESS_GRANTING_STATUSES.include?(status)
  end

  def is_trialing?
    status == 'trialing'
  end

  def days_to_next_payment
    days_left_in_subscription = (current_period_end.to_date - Time.now.to_date).to_i
  end

  def is_trial_expiring?
    is_trialing? && days_to_next_payment <= 14
  end

  def is_trial_expired?
    is_trialing? && days_to_next_payment <= 0
  end

  def assign_stripe_attrs(stripe_sub)
    assign_attributes(
      status: stripe_sub.status,
      cancel_at_period_end: stripe_sub.cancel_at_period_end,
      current_period_start: Time.at(stripe_sub.current_period_start),
      current_period_end: Time.at(stripe_sub.current_period_end)
    )
  end
end
