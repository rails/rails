#--
# Copyright (c) 2004 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'breakpoint'

class Dispatcher
  class <<self
    def dispatch(cgi = CGI.new, session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS)
      begin
        Breakpoint.activate_drb("druby://localhost:#{BREAKPOINT_SERVER_PORT}", nil, !defined?(FastCGI)) if defined?(BREAKPOINT_SERVER_PORT)

        request  = ActionController::CgiRequest.new(cgi, session_options)
        response = ActionController::CgiResponse.new(cgi)
    
        controller_name, module_name = controller_name(request.parameters), module_name(request.parameters)

        require_or_load("application")
        require_or_load(controller_path(controller_name, module_name))

        controller_class(controller_name).process(request, response).out
      rescue Object => exception
        ActionController::Base.process_with_exception(request, response, exception).out
      ensure
        reset_application if Dependencies.load?
        Breakpoint.deactivate_drb if defined?(BREAKPOINT_SERVER_PORT)
      end
    end
    
    private
      def reset_application
        Dependencies.clear
        Dependencies.remove_subclasses_for(ActiveRecord::Base, ActiveRecord::Observer, ActionController::Base)
      end
    
      def controller_path(controller_name, module_name = nil)
        if module_name
          "#{module_name}/#{controller_name.underscore}_controller"
        else
          "#{controller_name.underscore}_controller"
        end
      end

      def controller_class(controller_name)
        Object.const_get(controller_class_name(controller_name))
      end

      def controller_class_name(controller_name)
        "#{controller_name.camelize}Controller"
      end

      def controller_name(parameters)
        parameters["controller"].downcase.gsub(/[^_a-zA-Z0-9]/, "").untaint
      end

      def module_name(parameters)
        parameters["module"].downcase.gsub(/[^_a-zA-Z0-9]/, "").untaint if parameters["module"]
      end
  end
end