require 'loggerr/version'
require 'boss-protocol'
require 'hashie'
require 'thread'
require 'httpclient'

module Loggerr
  # Your code goes here...

  def self.packager id, key
    return Packager.new id, key
  end

  def self.configure id, key, opts={}
    @@app_id, @@app_secret, @options = id, key, opts
    @@packager = packager @@app_id, @@app_secret
    @@host = opts[:host] || "http://loggerr.com"
    @@client = HTTPClient.new @@host
  end

  def self.pack data
    @@packager.pack(data)
  end

  def self.clear_context
    ctx = Hashie::Mash.new
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
      report e
      options[:retrhow] and raise
    end
  end

  def self.protect_rethrow component_name=nil, &block
    self.protect component_name, retrhow: true, &block
  end

  def self.report e
    ctx = self.context
    ctx.exception = e.to_s
    ctx.exception_class = e.class.name
    ctx.stack = e.backtrace
    ctx.severity = 100
    ctx.time = Time.now
    post(pack(context))
  end

  def self.post data
    Thread.start {
      @@client.post "report/log", app_id: @@app_id, data: data
    }
  end

end
