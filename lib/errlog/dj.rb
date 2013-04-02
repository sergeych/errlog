
puts "Installing DJ integration"
begin
  class Delayed::Worker
    def handle_failed_job_with_errlog(job, error)
      puts "habdle failed job #{job} #{error}"
      Errlog.context.component = 'DJ'
      Errlog.exception error
      Errlog.clear_context
      handle_failed_job_without_errlog(job, error)
    end
    alias_method_chain :handle_failed_job, :errlog
  end
rescue => e
  STDERR.puts "Problem starting Exceptional for Delayed-Job. Your app will run as normal\n#{e}"
  Errlog.context.component = 'DJ'
  Errlog.exception e
end

