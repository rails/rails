#!/usr/local/bin/ruby

def dispatcher_error(path,e,msg="")
  error_message =
    "[#{Time.now}] Dispatcher failed to catch: #{e} (#{e.class})\n  #{e.backtrace.join("\n  ")}\n#{msg}"
  Logger.new(path).fatal(error_message)
rescue Object => log_error
  STDERR << "Couldn't write to #{path} (#{e} [#{e.class}])\n" << error_message
end

begin
  require File.dirname(__FILE__) + "/../config/environment"
  require 'dispatcher'
  require 'fcgi'

  log_file_path = "#{RAILS_ROOT}/log/fastcgi.crash.log"

  FCGI.each_cgi do |cgi| 
    begin
      Dispatcher.dispatch(cgi)
    rescue Object => rails_error
      dispatcher_error(log_file_path, rails_error)
    end
  end
rescue Object => fcgi_error
  dispatcher_error(log_file_path, fcgi_error, "FCGI process #{$$} killed by this error\n")
end