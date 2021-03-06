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

=begin
  The reporting module for errlog service, see http://errorlog.com for details.

  The usage is quite simple:

  Errlog.configure(
      account_id, account_secret,
      :application => 'MyGreatApplication')

  And use any of {Errlog.context} and {Errlog::Context} methods to report exceptions,
  collect logs, traces and so on.

  See http://errorlog.co/help for more.
=end

module Errlog

  include Errlog::Constants
  extend Errlog::Constants

  # @return [Errlog::Packager] packager instance for configured credentials, see {Errorlog.configure}
  def self.packager id, key
    return Packager.new id, key
  end

  @@configured = false
  @@send_error = false

  # Configure your instance. Sbhould be called before any other methods. Follow http://errorlog.co/help/rails
  # to get your credentials
  #
  # @param [string] id account id
  def self.configure id, key, opts={}
    @@configured                     = true
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
      if Rails.env != 'test'
        @@logger                      = Rails.logger = ChainLogger.new Rails.logger
        ActionController::Base.logger = ChainLogger.new ActionController::Base.logger
        if defined?(ActiveRecord)
          ActiveRecord::Base.logger = ChainLogger.new ActiveRecord::Base.logger
        end
      end
      @@loggers_ready = true

      # Delayed job
      if defined?(Delayed)
        require 'errlog/dj'
      end
    end
  end

  # Create logger that will report its content on {Errlog.error}, {Errlog.trace} and {Errlog.warning}
  # and {ErrlogContext} reporting funtions. It can user existing logger to pass through, ot will create
  # {Logger} with STDOUT
  #
  # @param logger existing logger to pass log to, If nil, STDOUT Logger will be created
  # @return [ChainLogger] new instance.
  def self.logger logger = nil
    logger ||= Logger.new(STDOUT)
    @@logger ||= ChainLogger.new logger
  end

  def self.use_logging?
    !@@opts[:no_logs]
  end

  def self.application
    @@application #rescue nil
  end

  def self.configured?
    if @@configured
      (@@rails && Rails.env == 'test') || defined?(@@app_id) && @@app_id && @@app_secret
    else
      false
    end
  end

  def self.default_platform
    @@rails ? 'rails' : 'ruby'
  end

  def self.rails?
    @@rails
  end

  def self.rails_test?
    @rails_test == nil and @rails_test = @@rails && Rails.env == 'test'
  end

  def self.pack data
    @@packager.pack(data)
  end

  def self.default_packager
    @@packager
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

  def self.wait
    @@send_threads.each { |t| t.weakref_alive? and t.join }
    @@send_threads == []
    @@send_error
  end

  private

  def self.post src
    if @@rails && Rails.env == 'test'
      Rails.logger.info "Errlog: #{severity_name(src[:severity])}: #{src['text']}"
      stack=src['stack'] and Rails.logger.info "    #{stack.join("\n    ")}"
      return
    end
    data           = pack(src)
    @@send_threads ||= []

    t = Thread.start {
      error = nil
      begin
        fio = HTTPClient::UploadIO.new(StringIO.new(data), "data.bin")
        res = @@client.post "#{@@host}/reports/log", app_id: @@app_id, :file => fio
        error = "report refused: #{res.status}" if res.status != 200
      rescue Exception => e
        error = e
        @@send_error = error
      end
      STDERR.puts "Error sending errlog: #{error}" if error
      yield error if block_given?
    }
    @@send_threads << WeakRef.new(t)
  end

end

if defined?(Rails) && Rails.env == 'test'
  Errlog.configure 'test id', 'test key', application: 'test app'
end
