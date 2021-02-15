# frozen_string_literal: true

require 'premailer/rails'

Premailer::Rails.config.merge!(preserve_styles: true, remove_ids: true)
