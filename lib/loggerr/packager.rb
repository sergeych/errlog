require 'loggerr/boss'
require 'base64'
require 'openssl'
require 'digest/md5'

module Loggerr

  class Packager

    class InvalidPackage < Exception; end

    def initialize app_id, app_key
      @appid = app_id
      @key = app_key.length == 16 ? app_key : Base64.decode64(app_key)
    end

    def encrypt data
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = @key
      'LR' + iv + cipher.update(data) + cipher.update(Digest::MD5.digest(data)) + cipher.final
    end

    def decrypt ciphertext
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.decrypt
      version = ciphertext[0..1]
      version == 'LR' or raise InvalidPackage
      cipher.iv = ciphertext[2..17]
      cipher.key = @key
      data = cipher.update(ciphertext[18..-1]) + cipher.final
      data, digest = data[0...-16], data[-16..-1]
      digest == Digest::MD5.digest(data) or raise InvalidPackage
      data
    end

    def pack payload
      encrypt(Boss.dump @appid, payload)
    end

    def unpack block
      id, payload = Boss.load_all(decrypt(block))
      id == @appid or raise InvalidPackage
      payload
    rescue
      raise InvalidPackage
    end

  end

end