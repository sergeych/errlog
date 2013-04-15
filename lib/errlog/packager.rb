require 'base64'
require 'openssl'
require 'digest/md5'
require 'boss-protocol'

module Errlog

  # Packager does (un)packing data to effectively and (where possible) safely
  # transfer the report over the network. Normally you don't use it directly.
  class Packager

    def initialize app_id, app_key
      @appid = app_id
      @key = app_key.length == 16 ? app_key : Base64.decode64(app_key)
    end

    # AES-128 encrypt the block
    def encrypt data
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = @key
      iv + cipher.update(data) + cipher.update(Digest::MD5.digest(data)) + cipher.final
    end

    # AES-128 decrypt the block
    def decrypt ciphertext
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.decrypt
      cipher.iv = ciphertext[0..15]
      cipher.key = @key
      data = cipher.update(ciphertext[16..-1]) + cipher.final
      data, digest = data[0...-16], data[-16..-1]
      digest == Digest::MD5.digest(data) ? data : nil
    end

    # @return [binary] packed payload using the default block format
    def pack payload
      "\x00#{encrypt(Boss.dump @appid, payload)}"
    end

    # @return [Hash] unpacked payload or nil if block fromat is unknown or block seems
    # to be broken (e.g. wrong credentials)
    def unpack block
      block[0].to_i == 0 or return nil
      id, payload = Boss.load_all(decrypt(block[1..-1]))
      id == @appid ? payload : nil
    rescue
      nil
    end

  end

end