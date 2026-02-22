# frozen_string_literal: true

require 'test_helper'

class UserConsentTest < ActiveSupport::TestCase
  test 'validates presence of consent_type' do
    consent = UserConsent.new(user: users(:founder), practice: practices(:complete), policy_version: '1.0', accepted_at: Time.current)
    assert_not consent.valid?
    assert consent.errors[:consent_type].any?
  end

  test 'validates presence of policy_version' do
    consent = UserConsent.new(user: users(:founder), practice: practices(:complete), consent_type: 'terms', accepted_at: Time.current)
    assert_not consent.valid?
    assert consent.errors[:policy_version].any?
  end

  test 'validates presence of accepted_at' do
    consent = UserConsent.new(user: users(:founder), practice: practices(:complete), consent_type: 'terms', policy_version: '1.0')
    assert_not consent.valid?
    assert consent.errors[:accepted_at].any?
  end

  test 'validates consent_type inclusion' do
    consent = UserConsent.new(user: users(:founder), practice: practices(:complete), consent_type: 'invalid', policy_version: '1.0', accepted_at: Time.current)
    assert_not consent.valid?
    assert consent.errors[:consent_type].any?
  end

  test 'validates uniqueness of user, consent_type, and policy_version' do
    consent = UserConsent.new(
      user: users(:founder),
      practice: practices(:complete),
      consent_type: 'terms',
      policy_version: '1.1',
      accepted_at: Time.current
    )
    assert_not consent.valid?
    assert consent.errors[:user_id].any?
  end

  test 'allows same user different consent types' do
    consent = UserConsent.new(
      user: users(:founder),
      practice: practices(:complete),
      consent_type: 'ai_data_processing',
      policy_version: '1.0',
      accepted_at: Time.current
    )
    assert consent.valid?
  end

  test 'allows same user same consent type different policy_version' do
    consent = UserConsent.new(
      user: users(:founder),
      practice: practices(:complete),
      consent_type: 'terms',
      policy_version: '2.0',
      accepted_at: Time.current
    )
    assert consent.valid?
  end

  test 'accepted? returns true when user has current version' do
    assert UserConsent.accepted?(users(:founder), 'terms')
    assert UserConsent.accepted?(users(:founder), 'privacy')
  end

  test 'accepted? returns false when user lacks consent' do
    assert_not UserConsent.accepted?(users(:founder), 'ai_data_processing')
  end

  test 'current_terms scope returns matching records' do
    terms = UserConsent.current_terms.where(user: users(:founder))
    assert_equal 1, terms.count
    assert_equal 'terms', terms.first.consent_type
  end

  test 'current_privacy scope returns matching records' do
    privacy = UserConsent.current_privacy.where(user: users(:founder))
    assert_equal 1, privacy.count
    assert_equal 'privacy', privacy.first.consent_type
  end

  test 'user helper methods work' do
    assert users(:founder).accepted_current_terms?
    assert users(:founder).accepted_current_privacy?
  end
end
