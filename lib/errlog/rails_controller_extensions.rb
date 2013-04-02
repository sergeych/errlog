module Errlog
  module ControllerFilter

    def self.included base
      base.send :prepend_before_filter, :errlog_connect_context
      base.send :rescue_from, Exception, :with => :errlog_report_exceptons
      base.send :helper_method, :errlog_context
      base.send :helper_method, :errlog_not_found
    end


    # Get the context that is linked to the current request and will
    # pass all its data if reporting will be called.
    # Dafault Loggerr.context might not always be connected to the request.
    #
    def errlog_context
      unless @errlog_context
        errlog_connect_context
      end
      @errlog_context
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
      #if text.is_a?(Exception)
      #  errlog_context.exception text, Errlog::WARNING
      #else
        errlog_context.warning text.to_s
      #end
      respond_to do |format|
        format.html {
          render :file => "#{Rails.root}/public/404.html", :status => :not_found
        }
        format.xml { head :not_found }
        format.any { head :not_found }
      end
    end

    private

    def errlog_connect_context
      @errlog_context = Errlog.clear_context
      @errlog_context.before_report {
        errlog_collect_context
      }
      true
    end

    def errlog_report_exceptons e
      errlog_context.exception e
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

    public

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
      if Errlog.application.blank? && request.url =~ %r|^https?://(.+?)[/:]|
        ctx.application = $1
      end
      ctx
    end
  end

end

ActionController::Base.send :include, Errlog::ControllerFilter