module Errlog
  module ControllerFilter

    def self.included base
      base.send :prepend_around_filter, :errlog_exceptions_trap
      base.send :helper_method, :errlog_context
      true
    end

    def errlog_context
      @errlog_context || Errlog.clear_context
    end

    def errlog_exceptions_trap
      ctx = @errlog_context = Errlog.clear_context

      rl  = Rails.logger = ctx.create_logger Rails.logger
      acl = ActionController::Base.logger = ctx.create_logger ActionController::Base.logger
      arl = nil
      if defined?(ActiveRecord)
        arl = ActiveRecord::Base.logger = ctx.create_logger ActiveRecord::Base.logger
      end

      yield

    rescue Exception => e
      ctx.component = request.path
      ctx.params    = params
      headers       = {}
      request.headers.to_hash.each { |k, v|
        next if k =~ /cookie/i || v.class.name =~ /cookie/i
        res = nil
        case v
          when Hash
            res = {}
            v.each { |k, v| res[k] = v.to_s }
          when Array;
            res = v.map &:to_s
          #when StringIO, IO
          #  next
          else
            res = v.to_s
        end
        headers[k.to_s] = res
      }
      ctx.headers = headers
      if respond_to?(:current_user)
        ctx.current_user = if current_user
                             res = [current_user.id]
                             res << current_user.email if current_user.respond_to? :email
                             res << current_user.full_name if current_user.respond_to? :full_name
                             res
                           else
                             "not logged in"
                           end
      end
      ctx.url = request.url
      ctx.remote_ip = request.remote_ip
      if request.url =~ %r|^https?://(.+?)[/:]|
        ctx.application = $1
      end

      @errlog_context.report_exception e
      raise

    ensure
      Rails.logger                  = rl.prev_logger
      ActionController::Base.logger = acl.prev_logger
      arl and ActiveRecord::Base.logger = arl.prev_logger
      true
    end

  end
end

ActionController::Base.send :include, Errlog::ControllerFilter