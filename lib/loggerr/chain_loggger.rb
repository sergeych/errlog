require 'logger'

module Loggerr

  class ChainLogger < Logger

    attr_reader :buffer, :prev_logger

    def initialize prev
      @buffer      = []
      @prev_logger = prev
      super(nil)
    end

    def level= l
      @prev_logger.level = l
    end

    def level
      @prev_logger.level
    end

    def add severity, message = nil, progname = nil
      message = yield if block_given?
      @prev_logger and @prev_logger.add(severity, message, progname)
      @buffer << [severity, Time.now, message, progname]
    end

  end
end

