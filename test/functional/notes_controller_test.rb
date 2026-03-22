# frozen_string_literal: true

require 'test_helper'

class NotesControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should create a note for a patient' do
    assert_difference 'Note.count' do
      post :create, params: { patient_id: patients(:one).id, note: { notes: 'Patient looks healthy' }, format: :js }
    end

    note = Note.last
    assert_equal 'Patient looks healthy', note.notes
    assert_equal users(:founder).id, note.user_id
    assert_equal patients(:one).id, note.noteable_id
    assert_equal 'Patient', note.noteable_type
  end

  test 'should not create a note with invalid content' do
    assert_no_difference 'Note.count' do
      post :create, params: { patient_id: patients(:one).id, note: { notes: '' }, format: :js }
    end
  end

  test 'should destroy a note' do
    note = Note.create!(notes: 'Temporary note', user: users(:founder), noteable: patients(:one))

    assert_difference 'Note.count', -1 do
      delete :destroy, params: { patient_id: patients(:one).id, id: note.id, format: :js }
    end
  end

  test 'requires authentication' do
    @controller.session['user'] = nil

    post :create, params: { patient_id: patients(:one).id, note: { notes: 'Should not work' }, format: :js }

    assert_response :redirect
  end
end
