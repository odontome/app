# frozen_string_literal: true

class Cipher
  def self.decode(string)
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    encrypted = Base64.strict_decode64(string)
    cipher.decrypt(encrypted)
  end

  def self.encode(string)
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    encrypted = cipher.encrypt(string)
    Base64.strict_encode64(encrypted)
  end
end
