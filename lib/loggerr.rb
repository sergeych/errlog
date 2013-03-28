require 'loggerr/version'
require 'loggerr/packager'
require 'loggerr/constants'
require 'loggerr/chain_loggger'
require 'boss-protocol'
require 'loggerr/context'
require 'hashie'
require 'thread'
require 'httpclient'
require 'weakref'

module Loggerr

  include Loggerr::Constants

  def self.severity_name code
    case code
      when TRACE...WARNING;
        'trace'
      when WARNING...ERROR;
        'warning'
      else
        ; 'error'
    end
  end

  def self.packager id, key
    return Packager.new id, key
  end

  def self.configure id, key, opts={}
    @@app_id, @@app_secret, @options = id, key, opts
    @@app_name                       = opts[:app_name]
    @@packager                       = packager @@app_id, @@app_secret
    @@host                           = opts[:host] || "http://loggerr.com"
    @@client                         = HTTPClient.new
    begin
      Rails.env
      @@rails = true
    rescue
      @@rails = false
    end
  end

  def self.app_name
    @@app_name #rescue nil
  end

  def self.configured?
    @@app_id && @@app_secret
  end

  def self.default_platform
    @@rails ? 'rails' : 'ruby'
  end

  def self.pack data
    @@packager.pack(data)
  end

  def self.create_logger with_logger=nil
    self.context.create_logger with_logger
  end

  def self.protect component_name=nil, options={}, &block
     context.protect component_name, options, &block
  end

  def self.protect_rethrow component_name=nil, &block
    context.protect_rethrow component_name, &block
  end

  def self.report_exception e, &block
    self.context.report_exception e, &block
  end

  def self.report text, severity = Loggerr::ERROR, &block
    self.context.report text, severity, &block
  end

  def self.clear_context
    ctx                              = Loggerr::Context.new
    Thread.current[:loggerr_context] = ctx
    ctx
  end

  def self.context
    Thread.current[:loggerr_context] || clear_context
  end

  private

  def self.post src
    data = pack(src)
    @@send_threads ||= []

    t = Thread.start {
      #puts "sending to #{@@host}"
      error = nil
      begin
        res = @@client.post "#{@@host}/reports/log", app_id: @@app_id, data: Base64::encode64(data)
        error = "report refused: #{res.status}" if res.status != 200
      rescue Exception => e
        error = e
      end
      yield error if block_given?
    }
    @@send_threads << WeakRef.new(t)
  end

  def self.wait
    @@send_threads.each { |t| t.weakref_alive? and t.join }
    @@send_threads == []
  end

end
