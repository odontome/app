require 'test_helper'

class BalanceTest < ActiveSupport::TestCase
  test 'balance attributes must not be empty' do
    balance = Balance.new

    assert balance.invalid?
    assert balance.errors[:patient_id].any?
    assert balance.errors[:amount].any?
  end

  test 'balance notes should be less than 160 chars' do
    balance = Balance.new(patient_id: 1, amount: 9.99,
                          notes: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor')

    assert !balance.save
    assert_equal I18n.t('errors.messages.too_long', count: 160), balance.errors[:notes].join('; ')
  end
end
