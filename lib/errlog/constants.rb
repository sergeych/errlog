module Errlog
  # This module could be extended for easy access to constants and severity test
  # helpers
  module Constants

    # @!group severity constants

    ERROR     = 100
    WARNING   = 50
    NOT_FOUND = 49
    TRACE     = 1

    # @!endgroup

    def is_error?(code)
      code >= ERROR
    end

    def is_warning? code
      code >= WARNING && code < ERROR
    end

    def is_trace? code
      code >= TRACE && code < WARNING
    end
  end
end
