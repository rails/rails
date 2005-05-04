#!/usr/local/bin/ruby

def dispatcher_log(level, path,msg)
  Logger.new(path).send(level, msg)
rescue Object => log_error
  STDERR << "Couldn't write to #{path}: #{msg}"
end

def dispatcher_error(path,e,msg="")
  error_message =
    "[#{Time.now}] Dispatcher failed to catch: #{e} (#{e.class})\n  #{e.backtrace.join("\n  ")}\n#{msg}"
  dispatcher_log(:error, path, error_message)
end

last_error_on = nil
begin
  require File.dirname(__FILE__) + "/../config/environment"
  require 'dispatcher'
  require 'fcgi'

  log_file_path = "#{RAILS_ROOT}/log/fastcgi.crash.log"
  dispatcher_log(:info, log_file_path, "fcgi #{$$} starting")

  # Allow graceful exits by sending the process SIGUSR1. If the process is
  # currently handling a request, the request will be allowed to complete and
  # then will terminate itself. If a request is not being handled, the
  # process is terminated immediately (via #exit).

  $please_exit_at_your_earliest_convenience = false
  $i_am_currently_processing_a_request = false
  trap("USR1") do
    if $i_am_currently_processing_a_request
      dispatcher_log(:info, log_file_path, "asking #{$$} to terminate ASAP")
      $please_exit_at_your_earliest_convenience = true
    else
      dispatcher_log(:info, log_file_path, "telling #{$$} to terminate NOW")
      exit
    end
  end

  # Process each request as it comes in, as a pseudo-CGI.

  FCGI.each_cgi do |cgi| 
    begin
      $i_am_currently_processing_a_request = true
      Dispatcher.dispatch(cgi)
    rescue Object => e
      dispatcher_error(log_file_path, e)
    ensure
      $stdout.flush
      $i_am_currently_processing_a_request = false
      break if $please_exit_at_your_earliest_convenience
    end
  end

  dispatcher_log(:info, log_file_path, "fcgi #{$$} terminated gracefully")
rescue SystemExit => exit_error
  dispatcher_log(:info, log_file_path, "fcgi #{$$} terminated by explicit exit")
rescue Object => fcgi_error
  # retry on errors that would otherwise have terminated the FCGI process, but
  # only if they occur more than 10 seconds apart.
  if !(SignalException === fcgi_error) && (last_error_on.nil? || last_error_on - Time.now > 10)
    last_error_on = Time.now
    dispatcher_error(log_file_path, fcgi_error, "FCGI process #{$$} almost killed by this error\n")
    retry
  else
    dispatcher_error(log_file_path, fcgi_error, "FCGI process #{$$} killed by this error\n")
  end
end