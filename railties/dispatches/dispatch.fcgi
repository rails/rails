#!/usr/local/bin/ruby

FASTCGI_CRASH_LOG_PATH = "#{RAILS_ROOT}/log/fastcgi.crash.log"

def dispatcher_error(e, msg = "")
  error_message = "[#{Time.now}] Dispatcher failed to catch: #{e} (#{e.class})\n  #{e.backtrace.join("\n  ")}\n#{msg}"
  Logger.new(FASTCGI_CRASH_LOG_PATH).fatal(error_message)
rescue Object => log_error
  STDERR << "Couldn't write to #{FASTCGI_CRASH_LOG_PATH} (#{e} [#{e.class}])\n" << error_message
end

begin
  require File.dirname(__FILE__) + "/../config/environment"
  require 'dispatcher'
  require 'fcgi'

  FCGI.each_cgi do |cgi| 
    begin
      Dispatcher.dispatch(cgi)
    rescue Object => rails_error
      dispatcher_error(rails_error)
    end
  end
rescue Object => fcgi_error
  dispatcher_error(fcgi_error, "FCGI process #{$$} killed by this error\n")
end