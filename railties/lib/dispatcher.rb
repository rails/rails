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

class Dispatcher
  DEFAULT_SESSION_OPTIONS = { "database_manager" => CGI::Session::PStore, "prefix" => "ruby_sess.", "session_path" => "/" }

  def self.dispatch(cgi = CGI.new, session_options = DEFAULT_SESSION_OPTIONS, error_page = nil)
    begin
      request  = ActionController::CgiRequest.new(cgi, session_options)
      response = ActionController::CgiResponse.new(cgi)

      controller_name = request.parameters["controller"].gsub(/[^_a-zA-Z0-9]/, "").untaint

      if module_name = request.parameters["module"]
        Module.new do
          ActionController::Base.require_or_load "#{module_name}/#{Inflector.underscore(controller_name)}_controller"
          Object.const_get("#{Inflector.camelize(controller_name)}Controller").process(request, response).out
        end
      else
        ActionController::Base.require_or_load "#{Inflector.underscore(controller_name)}_controller"
        Object.const_get("#{Inflector.camelize(controller_name)}Controller").process(request, response).out
      end
    rescue Exception => e
      begin
        ActionController::Base.logger.info "\n\nException throw during dispatch: #{e.message}\n#{e.backtrace.join("\n")}"
      rescue Exception
        # Couldn't log error
      end
      
      if error_page then cgi.out{ IO.readlines(error_page) } else raise e end
    ensure
      ActiveRecord::Base.reset_associations_loaded
    end
  end
end
