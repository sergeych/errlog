require 'loggerr/boss'
require 'base64'
require 'openssl'

module Loggerr

  class Packager

    def initialize app_id, app_key
      @appid = app_id
      @key = app_key.length == 16 ? app_key : Base64.decode64(app_key)
    end

    def encrypt data
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = @key
      iv + cipher.update(data) + cipher.final
    end

    def decrypt ciphertext
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.decrypt
      cipher.iv = ciphertext[0..15]
      cipher.key = @key
      cipher.update(ciphertext[16..-1]) + cipher.final
    end

  end

end