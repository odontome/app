# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

# YAML config files
TREATMENTS = YAML.load_file(File.join(Rails.root, "config", "treatments.yml"))

# Don't include the root object in the JSON
ActiveRecord::Base.include_root_in_json = false

# Appointment notifications configuration
$appointment_notificacion_hours = 48 # if the appointment is in the next {hours} it will send a notification
$appointment_notificacion_time = 3 # UTC hours. Example: "3" for 3am-UTC

LAST_VISITED_DATEBOOK = :last_visited_datebook

# Config authlogic
Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)

# Require the view extensions
require 'extensions/view_extensions'

# Require the model extensions
require 'extensions/model_extensions'

# Require the cipher module
require 'cipher'
