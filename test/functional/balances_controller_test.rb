# frozen_string_literal: true

require 'test_helper'

class BalancesControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    get :index, params: { patient_id: 1 }
    assert_response :success
    assert_not_nil assigns(:treatments)
    assert_select 'svg.icon-tabler-stethoscope[aria-hidden="true"]', count: 1
  end

  test 'should create an income entry' do
    entry = {
      amount: 9.99,
      currency: 'usd',
      notes: 'Can of soda'
    }

    assert_difference 'Balance.count' do
      post :create, params: { balance: entry, patient_id: 1, format: :js }
    end
  end

  test 'patient without a birthday can open balances and record an entry without an assumed age' do
    patient = patients(:one)
    patient.update_column(:date_of_birth, nil)

    get :index, params: { patient_id: patient.id }
    assert_response :success
    assert_select '.page-header', text: /#{Regexp.escape(I18n.t(:years_old).downcase)}/, count: 0

    assert_difference 'Balance.count', 1 do
      post :create, params: { patient_id: patient.id,
        balance: { amount: 25, currency: 'usd', notes: 'Consultation' }, format: :js }
    end
    assert_response :success
    assert_nil patient.reload.date_of_birth
  end

  test 'configured odontogram treatments keep balance quick entry without creating chart records' do
    treatment = treatments(:complete)
    treatment.update!(odontogram_category: 'crown')
    get :index, params: { patient_id: patients(:one).id }
    assert_response :success
    assert_includes assigns(:treatments), treatment
    assert_equal 5000, assigns(:treatments).find { |item| item.id == treatment.id }.price
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      assert_difference 'Balance.count' do
        post :create, params: { patient_id: patients(:one).id,
          balance: { amount: treatment.price, currency: 'usd', notes: treatment.name }, format: :js }
      end
    end
    assert_response :success
  end

  test 'should create an expense entry' do
    entry = {
      amount: -9.99,
      currency: 'usd',
      notes: 'Returned the can of soda'
    }

    assert_difference 'Balance.count' do
      post :create, params: { balance: entry, patient_id: 1, format: :js }
    end
  end
end
