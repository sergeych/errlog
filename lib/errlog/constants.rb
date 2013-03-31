module Errlog
  module Constants

    ERROR     = 100
    WARNING   = 50
    NOT_FOUND = 50
    TRACE     = 1

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
