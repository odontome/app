# frozen_string_literal: true

require 'test_helper'

class TreatmentsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
    @treatment = { name: 'Cleaning', price: 19.99 }
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:treatments)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create treatment' do
    assert_difference('Treatment.count') do
      post :create, params: { treatment: @treatment }
    end
    assert_redirected_to treatments_url
  end

  test 'should get edit' do
    get :edit, params: { id: treatments(:incomplete).to_param }
    assert_response :success
  end

  test 'should update treatment' do
    put :update, params: { id: treatments(:complete).to_param, treatment: @treatment }
    assert_redirected_to treatments_url
  end

  test 'should destroy treatment' do
    assert_difference('Treatment.count', -1) do
      delete :destroy, params: { id: treatments(:complete).to_param }
    end

    assert_redirected_to treatments_url
  end

  test 'chart configuration is optional and appears without activation in every locale' do
    %w[en es pt].each do |locale|
      practices(:complete).update!(locale: locale)
      get :new
      assert_select 'select[name="treatment[odontogram_category]"] option', count: OdontogramEntry::CATEGORIES.length + 1
      assert_select '[data-odontogram-treatment-hint]', count: 1
    end
  end

  test 'existing treatments default to no chart marking and keep their price when configured' do
    treatment = treatments(:complete)
    assert_nil treatment.odontogram_category
    put :update, params: { id: treatment.id, treatment: { odontogram_category: 'filling' } }
    assert_redirected_to treatments_url
    assert_equal 'filling', treatment.reload.odontogram_category
    assert_equal 5000, treatment.price
    assert_equal 'Tooth pull (expensive)', treatment.name
    put :update, params: { id: treatment.id, treatment: { odontogram_category: '' } }
    assert_nil treatment.reload.odontogram_category
  end

  test 'practices can configure chart markings and keep editing names and prices without activation' do
    treatment = treatments(:complete)
    treatment.update!(odontogram_category: 'filling')
    put :update, params: { id: treatment.id, treatment: { odontogram_category: 'crown', name: 'Custom crown' } }
    assert_redirected_to treatments_url
    assert_equal 'crown', treatment.reload.odontogram_category
    assert_equal 'Custom crown', treatment.name
    put :update, params: { id: treatment.id, treatment: { name: 'Updated', price: 100 } }
    assert_redirected_to treatments_url
    assert_equal 'crown', treatment.reload.odontogram_category
    assert_equal 'Updated', treatment.name
    assert_equal 100, treatment.price
    assert_difference 'Treatment.count', 1 do
      post :create, params: { treatment: @treatment.merge(odontogram_category: 'filling') }
    end
    assert_redirected_to treatments_url
    assert_equal 'filling', Treatment.order(:id).last.odontogram_category
  end

  test 'unsupported marking family cannot be saved and does not change the price' do
    put :update, params: { id: treatments(:complete).id, treatment: { odontogram_category: 'unknown', price: 1 } }
    assert_response :success
    assert assigns(:treatment).errors[:odontogram_category].any?
    assert_equal 5000, treatments(:complete).reload.price
  end
end
