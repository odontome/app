require 'rails_helper'

RSpec.describe AppointmentsController, type: :controller do
  let(:practice) { create(:practice) }
  let(:user) { create(:user, practice: practice) }
  let(:datebook) { create(:datebook, practice: practice) }
  let(:doctor) { create(:doctor, practice: practice) }
  let(:patient) { create(:patient, practice: practice) }
  let!(:appointment) { create(:appointment, datebook: datebook, doctor: doctor, patient: patient) }

  before do
    # Simulate user sign-in. Replace with your actual sign-in mechanism.
    # For example, if using Devise: sign_in user
    # Or a custom helper: allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:require_user).and_return(true) # Assuming require_user is a before_action
  end

  describe "PUT #update" do
    context "when datebook does not exist" do
      it "returns http status not_found and alerts 'Datebook not found.'" do
        put :update, params: { datebook_id: 'invalid_datebook_id', id: appointment.id, appointment: { notes: "New notes" }, format: :js }
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("alert('Datebook not found.')")
      end
    end

    context "when appointment does not exist but datebook exists" do
      it "returns http status not_found and alerts 'Appointment not found.'" do
        put :update, params: { datebook_id: datebook.id, id: 'non_existent_id', appointment: { notes: "New notes" }, format: :js }
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("alert('Appointment not found.')")
      end
    end

    context "when update is successful" do
      it "updates the appointment and returns http status ok" do
        new_notes = "Updated appointment notes"
        put :update, params: { datebook_id: datebook.id, id: appointment.id, appointment: { notes: new_notes }, format: :js }
        expect(response).to have_http_status(:ok)
        appointment.reload
        expect(appointment.notes).to eq(new_notes)
      end
    end

    context "when update fails due to validation errors" do
      it "renders a UJS error with the error message" do
        # Assuming notes cannot be blank for this test.
        # You might need to adjust your Appointment model validations for this test to be meaningful.
        # Or, if you have a specific validation that can be triggered, use that.
        # For example, if starts_at is required and you pass it as nil.
        allow_any_instance_of(Appointment).to receive(:update).and_return(false) # Force update to fail
        # Mock errors on the appointment object if necessary for render_ujs_error to work as expected
        # allow_any_instance_of(Appointment).to receive_message_chain(:errors, :full_messages).and_return(["Error message"])


        put :update, params: { datebook_id: datebook.id, id: appointment.id, appointment: { notes: nil }, format: :js } # Assuming notes: nil makes it invalid
        
        # The expected behavior for render_ujs_error might vary.
        # It might render a specific template, or directly render JS.
        # This assertion checks if the response body includes the I18n message for update error.
        # You might need to adjust I18n.t(:appointment_updated_error_message) if it's namespaced.
        expect(response.body).to include(I18n.t(:appointment_updated_error_message, default: "There was a problem updating the appointment"))
        # Also, check for an appropriate HTTP status if render_ujs_error sets one (e.g., :unprocessable_entity)
        # expect(response).to have_http_status(:unprocessable_entity) # or whatever status your render_ujs_error sets
      end
    end
  end
end
