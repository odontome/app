# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Odontome::Application.initialize!

# FastGettext stuff
Object.send(:include,FastGettext::Translation)
FastGettext.add_text_domain('app',:path=>'locale', :type=>:po)
AVAILABLE_LOCALES = ['es-ES', 'en-US'] # only allow these locales to be set (optional)
