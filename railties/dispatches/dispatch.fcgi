#!/usr/local/bin/ruby

# to allow unit testing
if !defined?(RAILS_ROOT)
  require File.dirname(__FILE__) + "/../config/environment"
end

require 'dispatcher'
require 'fcgi'
require 'logger'

class RailsFCGIHandler
  attr_reader :please_exit_at_your_earliest_convenience
  attr_reader :i_am_currently_processing_a_request

  def initialize(log_file_path = "#{RAILS_ROOT}/log/fastcgi.crash.log")
    @please_exit_at_your_earliest_convenience = false
    @i_am_currently_processing_a_request = false

    trap_handler = method(:trap_handler).to_proc
    trap("HUP",  trap_handler)
    trap("USR1", trap_handler)

    # initialize to 11 seconds from now to minimize special cases
    @last_error_on = Time.now + 11

    @log_file_path = log_file_path
    dispatcher_log(:info, "fcgi #{$$} starting")
  end

  def process!
    FCGI.each_cgi do |cgi| 
      process_request(cgi)
      break if please_exit_at_your_earliest_convenience
    end

    dispatcher_log(:info, "fcgi #{$$} terminated gracefully")

  rescue SystemExit => exit_error
    dispatcher_log(:info, "fcgi #{$$} terminated by explicit exit")

  rescue Object => fcgi_error
    # retry on errors that would otherwise have terminated the FCGI process,
    # but only if they occur more than 10 seconds apart.
    if !(SignalException === fcgi_error) && @last_error_on - Time.now > 10
      @last_error_on = Time.now
      dispatcher_error(fcgi_error,
        "FCGI process #{$$} almost killed by this error\n")
      retry
    else
      dispatcher_error(fcgi_error, "FCGI process #{$$} killed by this error\n")
    end
  end

  private
    def logger
      @logger ||= Logger.new(@log_file_path)
    end

    def dispatcher_log(level, msg)
      logger.send(level, msg)
    rescue Object => log_error
      STDERR << "Couldn't write to #{@log_file_path.inspect}: #{msg}\n"
      STDERR << "  #{log_error.class}: #{log_error.message}\n"
    end

    def dispatcher_error(e,msg="")
      error_message =
        "[#{Time.now}] Dispatcher failed to catch: #{e} (#{e.class})\n" +
        "  #{e.backtrace.join("\n  ")}\n#{msg}"
      dispatcher_log(:error, error_message)
    end

    def trap_handler(signal)
      if i_am_currently_processing_a_request
        dispatcher_log(:info, "asking #{$$} to terminate ASAP")
        @please_exit_at_your_earliest_convenience = true
      else
        dispatcher_log(:info, "telling #{$$} to terminate NOW")
        exit
      end
    end

    def process_request(cgi)
      @i_am_currently_processing_a_request = true
      Dispatcher.dispatch(cgi)
    rescue Object => e
      raise if SignalException === e
      dispatcher_error(e)
    ensure
      $stdout.flush
      @i_am_currently_processing_a_request = false
    end
end

if __FILE__ == $0
  handler = RailsFCGIHandler.new
  handler.process!
end
