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
    'USR2'    => :restart
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

    @app = Dispatcher.new

    # Start error timestamp at 11 seconds ago.
    @last_error_on = Time.now - 11
  end

  def process!(provider = FCGI)
    mark_features!

    dispatcher_log :info, 'starting'
    process_each_request provider
    dispatcher_log :info, 'stopping gracefully'

  rescue Exception => error
    case error
    when SystemExit
      dispatcher_log :info, 'stopping after explicit exit'
    when SignalException
      dispatcher_error error, 'stopping after unhandled signal'
    else
      # Retry if exceptions occur more than 10 seconds apart.
      if Time.now - @last_error_on > 10
        @last_error_on = Time.now
        dispatcher_error error, 'retrying after unhandled exception'
        retry
      else
        dispatcher_error error, 'stopping after unhandled exception within 10 seconds of the last'
      end
    end
  end

  protected
    def process_each_request(provider)
      request = nil

      catch :exit do
        provider.each do |request|
          process_request(request)

          case when_ready
            when :reload
              reload!
            when :restart
              close_connection(request)
              restart!
            when :exit
              close_connection(request)
              throw :exit
          end
        end
      end
    rescue SignalException => signal
      raise unless signal.message == 'SIGUSR1'
      close_connection(request)
    end

    def process_request(request)
      @processing, @when_ready = true, nil
      gc_countdown

      with_signal_handler 'USR1' do
        begin
          ::Rack::Handler::FastCGI.serve(request, @app)
        rescue SignalException, SystemExit
          raise
        rescue Exception => error
          dispatcher_error error, 'unhandled dispatch error'
        end
      end
    ensure
      @processing = false
    end

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
      if SIGNALS.include?(signal) && self.class.method_defined?(name = "#{SIGNALS[signal]}_handler")
        handler ||= method(name).to_proc

        begin
          trap(signal, handler)
        rescue ArgumentError
          dispatcher_log :warn, "Ignoring unsupported signal #{signal}."
        end
      else
        dispatcher_log :warn, "Ignoring unsupported signal #{signal}."
      end
    end

    def with_signal_handler(signal)
      install_signal_handler(signal)
      yield
    ensure
      install_signal_handler(signal, 'DEFAULT')
    end

    def exit_now_handler(signal)
      dispatcher_log :info, "asked to stop immediately"
      exit
    end

    def exit_handler(signal)
      dispatcher_log :info, "asked to stop ASAP"
      if @processing
        @when_ready = :exit
      else
        throw :exit
      end
    end

    def reload_handler(signal)
      dispatcher_log :info, "asked to reload ASAP"
      if @processing
        @when_ready = :reload
      else
        reload!
      end
    end

    def restart_handler(signal)
      dispatcher_log :info, "asked to restart ASAP"
      if @processing
        @when_ready = :restart
      else
        restart!
      end
    end

    def restart!
      config       = ::Config::CONFIG
      ruby         = File::join(config['bindir'], config['ruby_install_name']) + config['EXEEXT']
      command_line = [ruby, $0, ARGV].flatten.join(' ')

      dispatcher_log :info, "restarted"

      # close resources as they won't be closed by
      # the OS when using exec
      logger.close rescue nil
      Rails.logger.close rescue nil

      exec(command_line)
    end

    def reload!
      run_gc! if gc_request_period
      restore!
      @when_ready = nil
      dispatcher_log :info, "reloaded"
    end

    # Make a note of $" so we can safely reload this instance.
    def mark_features!
      @features = $".clone
    end

    def restore!
      $".replace @features
      Dispatcher.reset_application!
      ActionController::Routing::Routes.reload
    end

    def run_gc!
      @gc_request_countdown = gc_request_period
      GC.enable; GC.start; GC.disable
    end

    def gc_countdown
      if gc_request_period
        @gc_request_countdown ||= gc_request_period
        @gc_request_countdown -= 1
        run_gc! if @gc_request_countdown <= 0
      end
    end

    def close_connection(request)
      request.finish if request
    end
end
