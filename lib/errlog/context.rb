require 'hashie'

module Errlog
  # Context is a central object in Errlog reporting. It is used to collect and
  # report necessary data about trace, warning and exception. It also carries
  # arbitrary extra data you might want to see in the errlog report, you just
  # assign it to the Context object much like with OpenStruct:
  #
  #   context = Errlog::clear_context
  #   context.instance_name = 'www143'
  #   # ...
  #   context.trace "Something just happened"
  class Context < Hashie::Mash

    # Perform a given block rescuing and reporting any uncaught exception.
    # Exception will not be thrown out of the block:
    #
    # @param component_name [String] optional name of the component to report exceptions from
    # @yieldparam ctx the context itself
    def protect component_name=nil, options={}
      component_name and self.component_name = component_name
      begin
        yield self
      rescue Exception => e
        exception e
        options[:retrhow] and raise
      end
    end

    # Perform a given block reporting and rethrowing any uncaught exception (see #protect)
    def protect_rethrow component_name=nil, &block
      self.protect component_name, retrhow: true, &block
    end

    # Report exception.
    #
    # @param [Exception] e exception to report
    # @param [Integer] severity severity to report, some exceptions mught be useful to report as warnings or
    #                  even traces.
    # @yieldparam context the context itself, you can set more fields in a block
    # @note that exception reports its class and backtrace, so there is no need to provide details
    def exception e, severity=Errlog::ERROR, &block
      self.stack           = e.backtrace
      self.exception_class = e.class.name
      report e.to_s, severity
    end

    # Report trace. There is a syntax sugar to provide extra information in the block where the context
    # is passed as the parameter:
    #
    #      everything_is_ok or context.trace "Not all is ok" do |ctx|
    #          ctx.valuable_data = some_value
    #      end
    #
    # Reporting methods except #exception uses the caller's stack in the report.
    def trace text, details=nil, severity=Errlog::TRACE, &block
      details and self.details = details
      report text, severity
    end

    # Report a warning, see {#trace}
    def warning text, details=nil, severity=Errlog::WARNING, &block
      details and self.details = details
      report text, severity
    end

    # Report an error, see {#trace}
    def error text, details=nil, severity=Errlog::ERROR, &block
      details and self.details = details
      report text, severity, &block
    end

    # Add a handler that will be called with a context as the sole parameter before reporting.
    # If the context will not be user for reporting, the handler will not be called. Use it
    # to collect additional information that won't be needed otherwise, especially if collecting takes
    # significant resources.
    def before_report &block
      (@before_handlers ||= []) << block
    end

    # Report test with e given severity. See #{trace} for optional block usage.
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

    # @private
    MAX_LOG_LINES = 100

    # @private
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