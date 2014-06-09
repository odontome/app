class Api::V1::PatientNotificationsController < Api::V1::BaseController

  require 'mandrill'

  def index

  end

  def create
    mandrill = Mandrill::API.new "kajMhDc9RHOo8Auc4Fgzaw" # CHANGE THIS TO ENV_VARIABLES

    patients = Patient.mine.select("firstname, lastname, email").where(:email => "rieraraul@gmail.com")

    if patients.empty?
      render :json => {:error => "Patients could not be found." }, :status => 404

    else
      message = {
        :subject => "Hello from Odonto.me",
        :from_name => "Odonto.me",
        :from_email => "hello@odonto.me",
        :to => to_mandrill_email(patients),
        :html => render_to_string('patient_mailer/practice_notification', :layout => 'email'),
        :merge_vars => to_mandrill_merge_variables(patients),
        :preserve_recipients => false
      }

      render :json => mandrill.messages.send(message)

    end
  end

  private

  def to_mandrill_email(patients)
    patients.map{ |patient| {:email => patient.email} }
  end

  def to_mandrill_merge_variables(patients)
    patients.map { |patient|
      { :rcpt => patient.email,
        :vars => [{:name => 'first_name', :content => patient.firstname}]
      }
    }
  end

end
