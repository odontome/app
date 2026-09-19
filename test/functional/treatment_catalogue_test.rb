# frozen_string_literal: true
require 'test_helper'

class TreatmentCatalogueTest < ActionController::TestCase
  tests TreatmentsController

  setup do
    @controller.session['user'] = users(:founder)
    practices(:complete).update!(odontogram_enabled: true)
  end

  test 'prices can be absent or explicitly zero' do
    post :create, params: { treatment: { name: 'Unpriced', price: '' } }
    assert_redirected_to treatments_url
    assert_nil Treatment.find_by!(name: 'Unpriced').price
    post :create, params: { treatment: { name: 'Free', price: '0' } }
    assert_redirected_to treatments_url
    assert_equal 0, Treatment.find_by!(name: 'Free').price
  end

  test 'builtins appear without writes and only their price can change' do
    assert_no_difference 'Treatment.count' do
      get :index
      assert_response :success
    end
    assert_equal OdontogramEntry::TREATMENT_CATEGORIES.sort, assigns(:treatments).select(&:builtin?).map(&:builtin_category).sort
    put :update, params: { id: 'builtin-crown', treatment: { name: 'Changed', odontogram_category: 'implant', price: '123.45' } }
    assert_redirected_to treatments_url
    crown = practices(:complete).treatments.find_by!(builtin_category: 'crown')
    assert_equal 'crown', crown.odontogram_category
    assert_equal 'Crown', crown.display_name
    assert_equal 123.45, crown.price
    assert_no_difference 'Treatment.count' do
      delete :destroy, params: { id: crown.to_param }
    end
    assert_response :forbidden
    assert_no_difference 'Treatment.count' do
      delete :destroy, params: { id: crown.id }
    end
    assert_response :forbidden
  end

  test 'builtins are scoped to the practice and flag' do
    put :update, params: { id: 'builtin-crown', treatment: { price: 100 } }
    assert_nil practices(:complete_another_language).treatments.find_by(builtin_category: 'crown')
    practices(:complete).update!(odontogram_enabled: false)
    put :update, params: { id: 'builtin-crown', treatment: { price: 200 } }
    assert_response :forbidden
    assert_equal 100, practices(:complete).treatments.find_by!(builtin_category: 'crown').price
  end

  test 'builtins are translated and remain optional while custom treatment names are preserved' do
    %w[en es pt].each do |locale|
      practices(:complete).update!(locale: locale)
      get :edit, params: { id: 'builtin-crown' }
      assert_response :success
      assert_select 'input[name="treatment[name]"][disabled]', count: 1
      assert_select 'input[name="treatment[price]"][required]', count: 0
      assert_select 'select[name="treatment[odontogram_category]"]', count: 0
      assert_no_match(/translation_missing|Translation missing/, response.body)
    end
    custom_name = treatments(:complete).name
    get :index
    assert_equal custom_name, treatments(:complete).reload.name
  end

  test 'invalid prices do not create a builtin override and zero can be cleared' do
    assert_no_difference 'Treatment.count' do
      put :update, params: { id: 'builtin-crown', treatment: { price: '-1' } }
    end
    assert_response :success
    assert assigns(:treatment).errors[:price].any?
    put :update, params: { id: 'builtin-crown', treatment: { price: '0' } }
    assert_redirected_to treatments_url
    put :update, params: { id: 'builtin-crown', treatment: { price: '' } }
    assert_redirected_to treatments_url
    assert_nil practices(:complete).treatments.find_by!(builtin_category: 'crown').price
  end
end
