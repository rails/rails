# Copyright (c) 2005 Zed A. Shaw
# You can redistribute it and/or modify it under the same terms as Ruby.
#
# Additional work donated by contributors.  See http://mongrel.rubyforge.org/attributions.html
# for more information.

require 'mongrel'
require 'cgi'
require 'action_controller/dispatcher'


module Rails
  module MongrelServer
    # Implements a handler that can run Rails and serve files out of the
    # Rails application's public directory.  This lets you run your Rails
    # application with Mongrel during development and testing, then use it
    # also in production behind a server that's better at serving the
    # static files.
    #
    # The RailsHandler takes a mime_map parameter which is a simple suffix=mimetype
    # mapping that it should add to the list of valid mime types.
    #
    # It also supports page caching directly and will try to resolve a request
    # in the following order:
    #
    # * If the requested exact PATH_INFO exists as a file then serve it.
    # * If it exists at PATH_INFO+".html" exists then serve that.
    # * Finally, construct a Mongrel::CGIWrapper and run Dispatcher.dispatch to have Rails go.
    #
    # This means that if you are using page caching it will actually work with Mongrel
    # and you should see a decent speed boost (but not as fast as if you use a static
    # server like Apache or Litespeed).
    class RailsHandler < Mongrel::HttpHandler
      # Construct a Mongrel::CGIWrapper and dispatch.
      def process(request, response)
        return if response.socket.closed?

        cgi = Mongrel::CGIWrapper.new(request, response)
        cgi.handler = self
        # We don't want the output to be really final until we're out of the lock
        cgi.default_really_final = false

        ActionController::Dispatcher.dispatch(cgi, ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, response.body)

        # This finalizes the output using the proper HttpResponse way
        cgi.out("text/html",true) {""}
      rescue Errno::EPIPE
        response.socket.close
      rescue Object => rails_error
        STDERR.puts "#{Time.now.httpdate}: Error dispatching #{rails_error.inspect}"
        STDERR.puts rails_error.backtrace.join("\n")
      end
    end
  end
end
