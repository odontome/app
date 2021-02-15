# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'Odonto.me <hello@odonto.me>'
  layout 'mailer'
end
