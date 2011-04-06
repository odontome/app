# Ruby lib for working with the Prefinery API's XML interface.
#
# You should have something like this in config/initializers/prefinery.rb.
# 
#   Prefinery.configure do |config|
#     config.subdomain = 'compulsivo'
#     config.secure = false
#     config.api_key = 8cc4aae2a2fc0e1278a2079ea95b219e26f6beba
#   end
#
#
# Read the docs at:
# http://app.prefinery.com/api
#

#require 'rubygems'
#require 'activesupport'
#require 'activeresource'

module Prefinery

  class << self
    attr_accessor :subdomain, :host, :port, :secure, :api_key, :host_format

    def configure
      yield self
      resources.each do |klass|
        klass.site = klass.site_format % (host_format % [protocol, host, port])
        klass.user = api_key
        klass.password = "X"
      end
    end
    
    def subdomain
      @subdomain
    end
    
    def host
      @host ||= "#{subdomain}.prefinery.com"
    end
    
    def port
      @port || (secure ? 443 : 80)
    end

    def api_key
      @api_key
    end
    
    def protocol
      secure ? "https" : "http"
    end

    def url
      URI.parse("#{protocol}://#{host}:#{port}")
    end
    
    def resources
      @resources ||= []
    end
    
  end
  self.host_format   = '%s://%s:%s/api/v1'
  
  class Base < ActiveResource::Base
    def self.inherited(base)
      Prefinery.resources << base
      class << base
        attr_accessor :site_format
      end
      base.site_format = '%s'
      super
    end
  end
  
  # List betas
  #
  #  Prefinery::Beta.find(:all)
  #
  # Show a single beta
  #
  #  beta = Prefinery::Beta.find(1)
  #
  # List testers
  #
  #  beta.testers
  #
  # Find a tester by email
  #
  #  beta.testers(:email => 'justin@prefinery.com')
  #
  class Beta < Base
    def testers(options = {})
      Tester.find(:all, :params => options.update(:beta_id => id))
    end
  end
  
  # List testers
  #
  #  Prefinery::Tester.find(:all, :params => { :beta_id => 74 })
  #  Prefinery::Tester.find(:all, :params => { :beta_id => 74, :email => "justin@prefinery.com" })
  #
  # Show a single tester
  #
  #  tester = Prefinery::Tester.find(1259, :params => { :beta_id => 74 })
  #
  # Creating a tester
  #
  #  tester = Prefinery::Tester.new(:beta_id => 74)
  #  tester.email = 'justin@prefinery.com'
  #  tester.status = 'active'
  #  tester.invitation_code = 'TECHCRUNCH'
  #  tester.profile = {:first_name => 'Justin', :last_name => 'Britten'}
  #  tester.save
  #
  # Updating a tester
  #
  #  tester = Prefinery::Tester.find(1259, :params => { :beta_id => 74 })
  #  tester.profile = {:city => 'Austin', :state => 'TX'}
  #  tester.save
  #
  # Deleting a tester
  #
  #  tester = Prefinery::Tester.find(1259, :params => { :beta_id => 74 })
  #  tester.destroy
  #
  # Check-in a tester
  #
  #  tester = Prefinery::Tester.find(1259, :params => { :beta_id => 74 })
  #  tester.checkin
  class Tester < Base
    site_format << '/betas/:beta_id'
    
    def profile=(profile_attributes)
      attributes['profile'] = profile_attributes
    end
    
    def verified?(invitation_code)
      begin
        get(:verify, :invitation_code => invitation_code)
        true
      rescue
        false
      end
    end
    
    def checkin
      begin
        post(:checkin)
        true
      rescue
        false
      end
    end
    
  end
  
  # Check-in a tester by email address
  #
  #  Prefinery::Checkin.create(:beta_id => 74, :email => 'justin@prefinery.com')
  class Checkin < Base
    site_format << '/betas/:beta_id'
  end
  
end