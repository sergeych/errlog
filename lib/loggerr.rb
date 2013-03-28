require 'loggerr/version'
require 'loggerr/packager'
require 'boss-protocol'
require 'hashie'
require 'thread'
require 'httpclient'
require 'weakref'

module Loggerr

  ERROR   = 100
  WARNING = 50
  TRACE   = 1

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

  def self.pack data
    @@packager.pack(data)
  end

  def self.clear_context
    ctx                              = Hashie::Mash.new
    Thread.current[:loggerr_context] = ctx
    ctx
  end

  def self.context
    Thread.current[:loggerr_context] || clear_context
  end

  def self.protect component_name=nil, options={}
    ctx = clear_context
    component_name and ctx.component_name = component_name
    begin
      yield
    rescue Exception => e
      report_exception e
      options[:retrhow] and raise
    end
  end

  def self.protect_rethrow component_name=nil, &block
    self.protect component_name, retrhow: true, &block
  end

  def self.report_exception e, &block
    self.context.stack = e.backtrace
    report "#{e.class.name}: #{e.to_s}", Loggerr::ERROR
  end

  def self.report text, severity = Loggerr::ERROR, &block
    raise 'Loggerr is not configured. Use Loggerr.config' if !@@app_id || !@@app_secret
    ctx      = self.context
    ctx.text = text
    @@app_name && !ctx.app_name and ctx.app_name = @@app_name
    ctx.time     = Time.now
    ctx.severity = severity
    ctx.platform ||= @@rails ? 'rails' : 'ruby'
    ctx.stack ||= caller
    post(pack(ctx), &block)
    clear_context
  end

  def self.post data
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
