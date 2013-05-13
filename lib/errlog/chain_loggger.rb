require 'logger'

module Errlog

  # The chain logger is used to collect data for Errlog context (current context is used)
  # and optionally pass through logs to previous logger (that's why chain).
  # Potential problem: you can not bound logger to some context instance so far. Leave
  # issue at the github if you'll need
  class ChainLogger < Logger

    # @return previous logger instance if any
    attr_reader :prev_logger

    # Create instance optionally atop of an existing logger.
    def initialize prev=nil
      @prev_logger = prev
      super(nil)
    end

    # Set log level
    def level= l
      @prev_logger and @prev_logger.level = l
    end

    # @return current log level
    def level
      @prev_logger ? @prev_logger.level : super
    end

    # Standard add log method, see (Logger#add)
    def add severity, message = nil, progname = nil
      message = yield if block_given?
      if Errlog.rails_test?
        Rails.logger.add(severity, message, progname)
      else
        @prev_logger and @prev_logger.add(severity, message, progname)
      end
      # Rails.logger.info "- #{@prev_logger}: #{progname} ="
      #puts message #if Errlog.rails_test?
      Errlog.context.add_log_record [severity, Time.now, message, progname]
    end

  end
end

