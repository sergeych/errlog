require 'hashie'

module Errlog
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
      report "#{e.class.name}: #{e.to_s}", Errlog::ERROR
    end

    def report text, severity = Errlog::ERROR, &block
      raise 'Errlog is not configured. Use Errlog.config' unless Errlog.configured?
      !self.app_name and self.app_name = Errlog.app_name
      self.time     = Time.now
      self.severity = severity
      self.platform ||= Errlog.default_platform
      self.stack    ||= caller
      self.text = text
      @loggers and self.log = @loggers.reduce([]){ |all,x| all + x.buffer }.sort { |x,y| x[1] <=> y[1] }
      Errlog.rails? and self.rails_root = Rails.root.to_s
      Errlog.post(self.to_hash, &block)
    end

    def create_logger with_logger=nil
      l = Errlog::ChainLogger.new(with_logger)
      (@loggers ||= []) << l
      l
    end
  end
end