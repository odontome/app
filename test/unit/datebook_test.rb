require 'test_helper'

class DatebookTest < ActiveSupport::TestCase
  setup do
    users(:founder).authenticate('1234567890')
  end

  test 'datebook attributes must not be empty' do
    datebook = Datebook.new

    assert datebook.invalid?
    assert datebook.errors[:practice_id].any?
    # assert datebook.errors[:name].any?
  end

  test 'datebook should save using a valid hours range' do
    datebook = Datebook.new(name: 'Valid datebook', starts_at: 9, ends_at: 19, practice_id: 1)
    assert datebook.save
    assert_equal datebook.starts_at, 9
    assert_equal datebook.ends_at, 19
  end

  test 'datebook starts at hours should be less than ends at' do
    datebook = Datebook.new(name: 'Invalid datebook', starts_at: 9, ends_at: 2)

    assert !datebook.save
    assert_equal I18n.t('errors.messages.greater_than', count: 9), datebook.errors[:ends_at].join('; ')
  end

  test 'datebook starts at hours should be more than or equal to zero' do
    datebook = Datebook.new(name: 'Invalid datebook', starts_at: -1, ends_at: 23)

    assert !datebook.save
    assert_equal I18n.t('errors.messages.greater_than', count: 0), datebook.errors[:starts_at].join('; ')
  end

  test 'datebook ends at hours should be more than or equal to twenty three' do
    datebook = Datebook.new(name: 'Invalid datebook', starts_at: 0, ends_at: 24)

    assert !datebook.save
    assert_equal I18n.t('errors.messages.less_than_or_equal_to', count: 23), datebook.errors[:ends_at].join('; ')
  end

  test 'datebook name should be less than 100 chars' do
    datebook = Datebook.new(name: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor.')

    assert !datebook.save
    assert_equal I18n.t('errors.messages.too_long', count: 100), datebook.errors[:name].join('; ')
  end
end
