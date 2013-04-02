require 'errlog/version'
require 'errlog/packager'
require 'errlog/constants'
require 'errlog/chain_loggger'
require 'boss-protocol'
require 'errlog/context'
require 'hashie'
require 'thread'
require 'httpclient'
require 'weakref'
require 'stringio'
require 'httpclient/uploadio'

if defined?(Rails)
  require 'errlog/rails_controller_extensions'
end

module Errlog

  include Errlog::Constants

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
    @@application                    = opts[:application] || ''
    @@packager                       = packager @@app_id, @@app_secret
    @@host                           = opts[:host] || "http://errorlog.co"
    @@client                         = HTTPClient.new
    @@opts                           = opts
    @@rails                          = defined?(Rails)
    @@loggers_ready                  = false
    @@component                      = nil

    if @@rails && !opts[:no_catch_logs]
      @@logger                      = Rails.logger = ChainLogger.new Rails.logger
      ActionController::Base.logger = ChainLogger.new ActionController::Base.logger
      if defined?(ActiveRecord)
        ActiveRecord::Base.logger = ChainLogger.new ActiveRecord::Base.logger
      end
      @@loggers_ready = true

      # Delayed job
      if defined?(Delayed)
        require 'errlog/dj'
      end
    end
  end

  def self.logger
    @@logger ||= ChainLogger.new
  end

  def self.use_logging?
    !@@opts[:no_logs]
  end

  def self.application
    @@application #rescue nil
  end

  def self.configured?
    defined?(@@app_id) && @@app_id && @@app_secret
  end

  def self.default_platform
    @@rails ? 'rails' : 'ruby'
  end

  def self.rails?
    @@rails
  end

  def self.pack data
    @@packager.pack(data)
  end

  def self.protect component_name=nil, options={}, &block
    context.protect component_name, options, &block
  end

  def self.protect_rethrow component_name=nil, &block
    context.protect_rethrow component_name, &block
  end

  def self.exception e, &block
    self.context.exception e, &block
  end

  def self.trace text, details=nil, severity=Errlog::TRACE, &block
    self.context.trace text, details, severity, &block
  end

  def self.error text, details=nil, severity=Errlog::TRACE, &block
    self.context.error text, details, severity, &block
  end

  def self.warning text, details=nil, severity=Errlog::TRACE, &block
    self.context.warning text, details, severity, &block
  end

  def self.report text, severity = Errlog::ERROR, &block
    self.context.report text, severity, &block
  end

  def self.clear_context
    ctx                             = Errlog::Context.new
    Thread.current[:errlog_context] = ctx
    ctx
  end

  def self.context
    Thread.current[:errlog_context] || clear_context
  end

  private

  def self.post src
    data           = pack(src)
    @@send_threads ||= []

    t = Thread.start {
      puts "sending to #{@@host}"

      error = nil
      begin
        sio = StringIO.new(data)
        puts sio.respond_to? :read
        puts sio.pos
        puts sio.respond_to? :pos=

        res = @@client.post "#{@@host}/reports/log", app_id: @@app_id, :file => HTTPClient::UploadIO.new(StringIO.new(data), "data.0")

        error = "report refused: #{res.status}" if res.status != 200
      rescue Exception => e
        error = e
      end
      STDERR.puts "Error sending errlog: #{error}" if error
      #puts "sent" unless error
      yield error if block_given?
    }
    @@send_threads << WeakRef.new(t)
  end

  def self.wait
    @@send_threads.each { |t| t.weakref_alive? and t.join }
    @@send_threads == []
  end

end
