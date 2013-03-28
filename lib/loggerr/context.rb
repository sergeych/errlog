require 'hashie'

module Loggerr
  class Context < Hashie::Mash

    def protect component_name=nil, options={}
      component_name and self.component_name = component_name
      begin
        yield self
      rescue Exception => e
        report_exception e
        options[:retrhow] and raise
      end
    end

    def protect_rethrow component_name=nil, &block
      self.protect component_name, retrhow: true, &block
    end

    def report_exception e, &block
      self.stack = e.backtrace
      report "#{e.class.name}: #{e.to_s}", Loggerr::ERROR
    end

    def report text, severity = Loggerr::ERROR, &block
      raise 'Loggerr is not configured. Use Loggerr.config' unless Loggerr.configured?
      self.text = text
      !self.app_name and self.app_name = Loggerr.app_name
      self.time     = Time.now
      self.severity = severity
      self.platform ||= Loggerr.default_platform
      self.stack    ||= caller
      @loggers.length > 0 and self.log = @loggers.reduce([]){ |all,x| all + x.buffer }.sort { |x,y| x[1] <=> y[1] }
      Loggerr.post(self.to_hash, &block)
    end

    def create_logger with_logger=nil
      l = Loggerr::ChainLogger.new(with_logger)
      (@loggers ||= []) << l
      l
    end
  end
end