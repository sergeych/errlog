
begin
  class Delayed::Worker
    def handle_failed_job_with_errlog(job, error)
      Errlog.context.component = 'DJ'
      Errlog.exception error
      Errlog.clear_context
      handle_failed_job_without_errlog(job, error)
    end
    alias_method_chain :handle_failed_job, :errlog

    def run_with_errlog job
      Errlog.clear_context
      run_without_errlog job
    end
    alias_method_chain :run, :errlog
  end
rescue => e
  STDERR.puts "Problem starting Exceptional for Delayed-Job. Your app will run as normal\n#{e}"
  Errlog.context.component = 'DJ'
  Errlog.exception e
end
