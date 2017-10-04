# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)

