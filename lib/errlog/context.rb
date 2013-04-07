require 'hashie'

module Errlog
  class Context < Hashie::Mash

    def protect component_name=nil, options={}
      component_name and self.component_name = component_name
      begin
        yield self
      rescue Exception => e
        exception e
        options[:retrhow] and raise
      end
    end

    def protect_rethrow component_name=nil, &block
      self.protect component_name, retrhow: true, &block
    end

    def exception e, severity=Errlog::ERROR, &block
      self.stack           = e.backtrace
      self.exception_class = e.class.name
      report e.to_s, severity
    end

    def trace text, details=nil, severity=Errlog::TRACE, &block
      details and self.details = details
      report text, severity
    end

    def warning text, details=nil, severity=Errlog::WARNING, &block
      details and self.details = details
      report text, severity
    end

    def error text, details=nil, severity=Errlog::ERROR, &block
      details and self.details = details
      report text, severity, &block
    end

    def before_report &block
      (@before_handlers ||= []) << block
    end

    def report text, severity = Errlog::ERROR
      yield self if block_given?

      unless Errlog.configured?
        STDERR.puts 'Errlog is not configured. Use Errlog.config'
      else
        self.application ||= Errlog.application
        self.time        = Time.now
        self.severity    = severity
        self.platform    ||= Errlog.default_platform
        self.stack       ||= caller
        self.text        = text

        if @before_handlers
          @before_handlers.each { |h|
            h.call self
          }
        end

        @log_records and self.log = @log_records.inject([]) { |all, x| all << x; all }.sort { |x, y| x[1] <=> y[1] }
        Errlog.rails? and self.rails_root = Rails.root.to_s
        Errlog.post self.to_hash
      end
    end

    MAX_LOG_LINES = 100

    def add_log_record record
      @log_records ||= []
      @log_records << record
      if @log_records.length > MAX_LOG_LINES
        @log_records.delete_at(0)
        self.log_truncated = true
      end
    end

  end
end