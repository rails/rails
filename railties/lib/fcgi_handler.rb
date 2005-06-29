require 'fcgi'
require 'logger'
require 'dispatcher'

class RailsFCGIHandler
  attr_reader :when_ready
  attr_reader :processing

  def self.process!
    new.process!
  end

  def initialize(log_file_path = "#{RAILS_ROOT}/log/fastcgi.crash.log")
    @when_ready = nil
    @processing = false

    trap("HUP",  method(:restart_handler).to_proc)
    trap("USR1", method(:trap_handler).to_proc)

    # initialize to 11 seconds ago to minimize special cases
    @last_error_on = Time.now - 11

    @log_file_path = log_file_path
    dispatcher_log(:info, "starting")
  end

  def process!
    mark!

    FCGI.each_cgi do |cgi| 
      if when_ready == :restart
        restore!
        @when_ready = nil
        dispatcher_log(:info, "restarted")
      end

      process_request(cgi)
      break if when_ready == :exit
    end

    dispatcher_log(:info, "terminated gracefully")

  rescue SystemExit => exit_error
    dispatcher_log(:info, "terminated by explicit exit")

  rescue Object => fcgi_error
    # retry on errors that would otherwise have terminated the FCGI process,
    # but only if they occur more than 10 seconds apart.
    if !(SignalException === fcgi_error) && Time.now - @last_error_on > 10
      @last_error_on = Time.now
      dispatcher_error(fcgi_error, "almost killed by this error")
      retry
    else
      dispatcher_error(fcgi_error, "killed by this error")
    end
  end

  private
    def logger
      @logger ||= Logger.new(@log_file_path)
    end

    def dispatcher_log(level, msg)
      time_str = Time.now.strftime("%d/%b/%Y:%H:%M:%S")
      logger.send(level, "[#{time_str} :: #{$$}] #{msg}")
    rescue Object => log_error
      STDERR << "Couldn't write to #{@log_file_path.inspect}: #{msg}\n"
      STDERR << "  #{log_error.class}: #{log_error.message}\n"
    end

    def dispatcher_error(e,msg="")
      error_message =
        "Dispatcher failed to catch: #{e} (#{e.class})\n" +
        "  #{e.backtrace.join("\n  ")}\n#{msg}"
      dispatcher_log(:error, error_message)
    end

    def trap_handler(signal)
      if processing
        dispatcher_log :info, "asked to terminate ASAP"
        @when_ready = :exit
      else
        dispatcher_log :info, "told to terminate NOW"
        exit
      end
    end

    def restart_handler(signal)
      @when_ready = :restart
      dispatcher_log :info, "asked to restart ASAP"
    end

    def process_request(cgi)
      @processing = true
      Dispatcher.dispatch(cgi)
    rescue Object => e
      raise if SignalException === e
      dispatcher_error(e)
    ensure
      @processing = false
    end

    def mark!
      @features = $".clone
    end

    def restore!
      $".replace @features
      Dispatcher.reset_application!
      ActionController::Routing::Routes.reload
    end
end
