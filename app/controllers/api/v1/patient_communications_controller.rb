class Api::V1::PatientCommunicationsController < Api::V1::BaseController

  require 'mandrill'

  def index

  end

  def create
    mandrill = Mandrill::API.new "CJx4OZ8lZLqJbVO4yzkmHg" # CHANGE THIS TO ENV_VARIABLES

    patients = Patient.mine.select("firstname, lastname, email")

    params[:query].each do |query|
      case query

      when "last_visit"
        patients = patients.where("appointments.ends_at >= ?", query["value"].days.ago)
        .includes(:appointments)

      when "balance_greater_than"
        patients = patients.group("patients.id")
        .having("SUM(balances.amount) >= ?", query["value"])
        .includes(:balances)

      when "balance_lower_than"
        patients = patients.group("patients.id")
        .having("SUM(balances.amount) <= ?", query["value"])
        .includes(:balances)

      end

    end

    if patients.empty?
      render :json => {:error => "Patients could not be found." }, :status => 404

    else

      # REMOVE THIS AFTER TESTING!!!
      # REMEMBER THE LINE BELOW
      patients = Patient.mine.select("firstname, lastname, email").where("email = ?", "rieraraul@gmail.com")

      @message_subject = params[:subject].html_safe
      @message_body = params[:message].html_safe

      message = mandrill.messages.send({
        :subject => @message_subject,
        :from_name => @current_user.user.practice.name,
        :from_email => "hello@odonto.me",
        :headers =>{ "Reply-To"=> @current_user.user.email },
        :to => to_mandrill_email(patients),
        :track_clicks => true,
        :track_opens => true,
        :html => render_to_string('patient_mailer/practice_communication', :layout => 'email'),
        :merge_vars => to_mandrill_merge_variables(patients),
        :preserve_recipients => false
      })

      # make sure that the message was sent without errors
      if (message.is_a?(Array))

        patient_communication = PatientCommunication.new({
          :subject => @message_subject,
          :message => @message_body,
          :number_of_patients => patients.size,
          :user_id => @current_user.user.id
        })

        # were we able to save the record without problems?
        if (patient_communication.save)

          # track the event in mixpanel
          MIXPANEL_CLIENT.track(@current_user.user.email, 'Sent patient communications', {
              'Number of patients' => patients.size,
              'Query' => params[:query]
          })

          render :json => patient_communication
        # otherwise return an error message but make sure they know
        # the communication was sent anyway
        else
          render :json => {:error => "The communication was sent, but with some problems." }, :status => 500
        end

      # otherwise respond with an error message
      else
        render :json => {:error => "There was a problem sending the communication." }, :status => 400
      end
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
