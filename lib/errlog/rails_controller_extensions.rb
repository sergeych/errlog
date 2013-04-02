module Errlog
  module ControllerFilter

    def self.included base
      base.send :prepend_around_filter, :errlog_exceptions_trap
      base.send :helper_method, :errlog_context
      base.send :helper_method, :errlog_report
      base.send :helper_method, :errlog_collect_context
      base.send :helper_method, :errlog_exception
      base.send :helper_method, :errlog_not_found
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
      if Errlog.configured?
        errlog_collect_context ctx
        errlog_exception e, ctx
      else
        rl.prev_logger.error 'Errlog is not configured, can not report an exception'
      end
      raise

    ensure
      Rails.logger                  = rl.prev_logger
      ActionController::Base.logger = acl.prev_logger
      arl and ActiveRecord::Base.logger = arl.prev_logger
      true
    end

    # Helper for 404's or like. Can be used as the trap.
    #
    # The argument may be either an Exception object or a text message.
    # Can be used as the rescue_from catcher:
    #
    #    rescue_from :ActiveRecord::NotFound, :with => :errlog_not_found
    #
    # or manually:
    #
    #    def load_item
    #      item = Item.find_by_id(params[:id]) or errlog_not_found
    #
    def errlog_not_found text = 'Resource not found'
      errlog_context.not_found = true
      if text.is_a?(Exception)
        errlog_exception text, nil, Errlog::WARNING
      else
        errlog_report text, Errlog::WARNING
      end
      respond_to do |format|
        format.html {
          render :file => "#{Rails.root}/public/404.html", :status => :not_found
        }
        format.xml { head :not_found }
        format.any { head :not_found }
      end
    end

    def errlog_exception e, context = nil, severity = Errlog::ERROR
      errlog_collect_context(context).report_exception e, severity
    end

    def errlog_report text, severity = Errlog::ERROR, context=nil
      errlog_collect_context(context).report text, severity
    end

    def parametrize obj
      case obj
        when String
          obj
        when Array
          obj.map { |x| parametrize(x) }
        when ActionDispatch::Http::UploadedFile
          obj.inspect
        when Hash
          obj.inject({}) { |all, kv| all[kv[0].to_s] = parametrize(kv[1]); all }
        else
          obj.to_s
      end
    end

    @@headers_exclusion_keys = %w|async. action_dispatch. cookie rack. rack-cache. warden action_controller.|

    def errlog_collect_context ctx=nil
      ctx ||= errlog_context
      ctx.component = "#{self.class.name}##{params[:action]}"
      ctx.params    = parametrize(params)
      headers       = {}
      request.headers.to_hash.each { |k, v|
        next if @@headers_exclusion_keys.any? { |s| k.starts_with?(s) }
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
      headers.each { |k,v| puts "--H--> #{k} -> #{v}" }
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
      ctx
    end

  end
end

ActionController::Base.send :include, Errlog::ControllerFilter