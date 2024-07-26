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

require 'active_record'
require 'action_controller'
require 'logger'
require 'yaml'

class Dispatcher
  DEFAULT_APPLICATION_LOG_PATH = "/log/production.log"
  DEFAULT_DATABASE_CONFIG_PATH = "/config/database.yml"
  DEFAULT_TEMPLATE_ROOT        = "/app/views"

  DEFAULT_SESSION_OPTIONS = { "database_manager" => CGI::Session::PStore, "prefix" => "ruby_sess.", "session_path" => "/" }

  def initialize(rails_root, options = {})
    rescue_errors { configure(rails_root, options) }
  end

  def dispatch(cgi = CGI.new)
    rescue_errors do
      request  = ActionController::CgiRequest.new(cgi, session_options)
      response = ActionController::CgiResponse.new(cgi)

      require "#{request.parameters["controller"]}_controller"
      Object.const_get("#{request.parameters["controller"].capitalize}Controller").process(request, response).out
    end
  end

  private
    def rescue_errors
      begin
        yield
      rescue Exception => e
        if ActionController::Base.logger
          ActionController::Base.logger.info "\n\nController Failed to Load: #{e.message}\n#{e.backtrace.join("\n")}"
          raise e
        else
          CGI.new.out { 
            "<html><body>" +
            "<h1>Dispatcher Failed to Configure</h1>" +
            "<p>#{e.message}</p><blockquote>#{e.backtrace.join("\n")}</blockquote>" +
            "</body></html>"
          }
          
          exit
        end
      end
    end
  
    def configure(rails_root, options = {})
      @rails_root, @options = rails_root, options
      
      configure_logging(@options[:application_log_path]  || DEFAULT_APPLICATION_LOG_PATH)
      configure_template_root(@options[:template_root]   || DEFAULT_TEMPLATE_ROOT)
      configure_database(@options[:database_config_path] || DEFAULT_DATABASE_CONFIG_PATH)
    end
    
    def configure_logging(application_log_path)
      application_log = Logger.new "#{@rails_root}/#{application_log_path}"
      ActiveRecord::Base.logger     = application_log
      ActionController::Base.logger = application_log
    end
    
    def configure_template_root(template_root)
      ActionController::Base.template_root = "#{@rails_root}/#{template_root}"
    end
    
    def configure_database(database_config_path)
      db_conf = YAML::load(File.open("#{@rails_root}/#{database_config_path}"))
      ActiveRecord::Base.establish_connection(db_conf["production"])
    end
    
    def session_options
      @options[:session_options].nil? ? DEFAULT_SESSION_OPTIONS : @options[:session_options]
    end
end
