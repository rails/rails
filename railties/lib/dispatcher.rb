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
  DEFAULT_SESSION_OPTIONS = { :database_manager => CGI::Session::PStore, :prefix => "ruby_sess.", :session_path => "/" }

  def self.dispatch(cgi = CGI.new, session_options = DEFAULT_SESSION_OPTIONS)
    Breakpoint.activate_drb("druby://localhost:#{BREAKPOINT_SERVER_PORT}", nil, !defined?(FastCGI)) if defined?(BREAKPOINT_SERVER_PORT)

    begin
      request  = ActionController::CgiRequest.new(cgi, session_options)
      response = ActionController::CgiResponse.new(cgi)
      
      controller_name, module_name = controller_name(request.parameters), module_name(request.parameters)

      require_dependency("abstract_application")
      require_dependency(controller_path(controller_name, module_name))

      controller_class(controller_name).process(request, response).out
    rescue Object => exception
      ActionController::Base.process_with_exception(request, response, exception).out
    ensure
      if ActionController::Base.reload_dependencies
        Object.send(:remove_const, "AbstractApplicationController") if Object.const_defined?(:AbstractApplicationController)
        Object.send(:remove_const, controller_class_name(controller_name)) if Object.const_defined?(controller_class_name(controller_name))
        ActiveRecord::Base.reset_associations_loaded
        ActiveRecord::Base.reset_column_information_and_inheritable_attributes_for_all_subclasses
      end
      
      Breakpoint.deactivate_drb if defined?(BREAKPOINT_SERVER_PORT)
    end
  end
  
  def self.controller_path(controller_name, module_name = nil)
    if module_name
      "#{module_name}/#{Inflector.underscore(controller_name)}_controller"
    else
      "#{Inflector.underscore(controller_name)}_controller"
    end
  end
  
  def self.controller_class(controller_name)
    Object.const_get(controller_class_name(controller_name))
  end
  
  def self.controller_class_name(controller_name)
    "#{Inflector.camelize(controller_name)}Controller"
  end
  
  def self.controller_name(parameters)
    parameters["controller"].gsub(/[^_a-zA-Z0-9]/, "").untaint
  end
  
  def self.module_name(parameters)
    parameters["module"].gsub(/[^_a-zA-Z0-9]/, "").untaint if parameters["module"]
  end
end