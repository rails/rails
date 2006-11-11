require 'fcgi'
require 'logger'
require 'dispatcher'
require 'rbconfig'

class RailsFCGIHandler
  SIGNALS = {
    'HUP'     => :reload,
    'INT'     => :exit_now,
    'TERM'    => :exit_now,
    'USR1'    => :exit,
    'USR2'    => :restart,
    'SIGTRAP' => :breakpoint
  }
  GLOBAL_SIGNALS = SIGNALS.keys - %w(USR1)

  attr_reader :when_ready

  attr_accessor :log_file_path
  attr_accessor :gc_request_period


  # Initialize and run the FastCGI instance, passing arguments through to new.
  def self.process!(*args, &block)
    new(*args, &block).process!
  end

  # Initialize the FastCGI instance with the path to a crash log
  # detailing unhandled exceptions (default RAILS_ROOT/log/fastcgi.crash.log)
  # and the number of requests to process between garbage collection runs
  # (default nil for normal GC behavior.)  Optionally, pass a block which
  # takes this instance as an argument for further configuration.
  def initialize(log_file_path = nil, gc_request_period = nil)
    self.log_file_path = log_file_path || "#{RAILS_ROOT}/log/fastcgi.crash.log"
    self.gc_request_period = gc_request_period

    # Yield for additional configuration.
    yield self if block_given?

    # Safely install signal handlers.
    install_signal_handlers

    # Start error timestamp at 11 seconds ago.
    @last_error_on = Time.now - 11

    dispatcher_log :info, "starting"
  end

  def process!(provider = FCGI)
    # Make a note of $" so we can safely reload this instance.
    mark!

    run_gc! if gc_request_period

    process_each_request!(provider)

    GC.enable
    dispatcher_log :info, "terminated gracefully"

  rescue SystemExit => exit_error
    dispatcher_log :info, "terminated by explicit exit"

  rescue Exception => fcgi_error  # FCGI errors
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


  protected
    def logger
      @logger ||= Logger.new(@log_file_path)
    end

    def dispatcher_log(level, msg)
      time_str = Time.now.strftime("%d/%b/%Y:%H:%M:%S")
      logger.send(level, "[#{time_str} :: #{$$}] #{msg}")
    rescue Exception => log_error  # Logger errors
      STDERR << "Couldn't write to #{@log_file_path.inspect}: #{msg}\n"
      STDERR << "  #{log_error.class}: #{log_error.message}\n"
    end

    def dispatcher_error(e, msg = "")
      error_message =
        "Dispatcher failed to catch: #{e} (#{e.class})\n" +
        "  #{e.backtrace.join("\n  ")}\n#{msg}"
      dispatcher_log(:error, error_message)
    end

    def install_signal_handlers
      GLOBAL_SIGNALS.each { |signal| install_signal_handler(signal) }
    end

    def install_signal_handler(signal, handler = nil)
      handler ||= method("#{SIGNALS[signal]}_handler").to_proc
      trap(signal, handler)
    rescue ArgumentError
      dispatcher_log :warn, "Ignoring unsupported signal #{signal}."
    end

    def with_signal_handler(signal)
      install_signal_handler(signal)
      yield
    ensure
      install_signal_handler(signal, 'DEFAULT')
    end

    def exit_now_handler(signal)
      dispatcher_log :info, "asked to terminate immediately"
      exit
    end

    def exit_handler(signal)
      dispatcher_log :info, "asked to terminate ASAP"
      @when_ready = :exit
    end

    def reload_handler(signal)
      dispatcher_log :info, "asked to reload ASAP"
      @when_ready = :reload
    end

    def restart_handler(signal)
      dispatcher_log :info, "asked to restart ASAP"
      @when_ready = :restart
    end

    def breakpoint_handler(signal)
      dispatcher_log :info, "asked to breakpoint ASAP"
      @when_ready = :breakpoint
    end

    def process_each_request!(provider)
      cgi = nil
      provider.each_cgi do |cgi|
        with_signal_handler 'USR1' do
          process_request(cgi)
        end

        case when_ready
          when :reload
            reload!
          when :restart
            close_connection(cgi)
            restart!
          when :exit
            close_connection(cgi)
            break
          when :breakpoint
            close_connection(cgi)
            breakpoint!
        end

        gc_countdown
      end
    rescue SignalException => signal
      raise unless signal.message == 'SIGUSR1'
      close_connection(cgi) if cgi
    end

    def process_request(cgi)
      Dispatcher.dispatch(cgi)
    rescue Exception => e  # errors from CGI dispatch
      raise if SignalException === e
      dispatcher_error(e)
    end

    def restart!
      config       = ::Config::CONFIG
      ruby         = File::join(config['bindir'], config['ruby_install_name']) + config['EXEEXT']
      command_line = [ruby, $0, ARGV].flatten.join(' ')

      dispatcher_log :info, "restarted"

      exec(command_line)
    end

    def reload!
      run_gc! if gc_request_period
      restore!
      @when_ready = nil
      dispatcher_log :info, "reloaded"
    end

    def mark!
      @features = $".clone
    end

    def restore!
      $".replace @features
      Dispatcher.reset_application!
      ActionController::Routing::Routes.reload
    end

    def breakpoint!
      require 'breakpoint'
      port = defined?(BREAKPOINT_SERVER_PORT) ? BREAKPOINT_SERVER_PORT : 42531
      Breakpoint.activate_drb("druby://localhost:#{port}", nil, !defined?(FastCGI))
      dispatcher_log :info, "breakpointing"
      breakpoint
      @when_ready = nil
    end

    def run_gc!
      @gc_request_countdown = gc_request_period
      GC.enable; GC.start; GC.disable
    end

    def gc_countdown
      if gc_request_period
        @gc_request_countdown -= 1
        run_gc! if @gc_request_countdown <= 0
      end
    end

    def close_connection(cgi)
      cgi.instance_variable_get("@request").finish
    end
end
