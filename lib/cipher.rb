# frozen_string_literal: true

# Tokens in public links (review requests, calendar feeds). Every token carries
# the purpose it was made for, so a token minted for one link can never be
# replayed on another: encryption proves the app made it, the purpose proves
# what for.
class Cipher
  KEY = Gibberish::AES.new(Rails.application.secret_key_base)

  def self.decode(string, purpose:)
    decrypted = KEY.decrypt(Base64.strict_decode64(string))
    found_purpose, value = decrypted.split(':', 2)
    raise ArgumentError, 'token was made for another purpose' unless found_purpose == purpose.to_s && value.present?

    value
  end

  def self.encode(string, purpose:)
    encrypted = KEY.encrypt("#{purpose}:#{string}")
    Base64.strict_encode64(encrypted)
  end
end
