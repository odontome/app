# frozen_string_literal: true

require 'test_helper'

class AuditsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    get :index
    assert_response :success
  end

  test 'show renders a destroyed appointment whose doctor and patient are gone' do
    version = PaperTrail::Version.create!(
      item_type: 'Appointment',
      item_id: 987_654,
      event: 'destroy',
      whodunnit: users(:founder).id.to_s,
      practice_id: users(:founder).practice_id,
      object: appointments(:first_visit).attributes.merge('doctor_id' => 999_999, 'patient_id' => 999_999).to_json
    )

    get :show, params: { id: version.id }

    assert_response :success
  end

  test 'show does not leak debug output when object changes cannot be parsed' do
    version = PaperTrail::Version.create!(
      item_type: 'Patient',
      item_id: patients(:one).id,
      event: 'update',
      whodunnit: users(:founder).id.to_s,
      practice_id: users(:founder).practice_id,
      object_changes: '"corrupted"'
    )

    get :show, params: { id: version.id }

    assert_response :success
    assert_not_includes response.body, 'Debug:'
  end
end
