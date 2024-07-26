require 'active_record'
require 'action_controller'
require 'logger'
require 'yaml'

class Dispatcher
  DEFAULT_APPLICATION_LOG_PATH = "/log/production.log"
  DEFAULT_DATABASE_CONFIG_PATH = "/config/database.yml"
  DEFAULT_TEMPLATE_ROOT        = "/app/views"

  DEFAULT_SESSION_OPTIONS = { "database_manager" => CGI::Session::PStore, "prefix" => "ruby_sess.", "session_path" => "/" }

  def initialize(rails_root, application_log_path = nil, template_root = nil, database_config_path = nil)
    rescue_errors { configure(rails_root, application_log_path, template_root, database_config_path) }
  end

  def dispatch(cgi = CGI.new)
    rescue_errors do
      request  = ActionController::CgiRequest.new(cgi, DEFAULT_SESSION_OPTIONS)
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
        ActionController::Base.logger.info "\n\nController Failed to Load: #{e.message}\n#{e.backtrace.join("\n")}"
        raise e
      end
    end
  
    def configure(rails_root, application_log_path = nil, template_root = nil, database_config_path = nil)
      @rails_root = rails_root
      configure_logging(application_log_path  || DEFAULT_APPLICATION_LOG_PATH)
      configure_template_root(template_root   || DEFAULT_TEMPLATE_ROOT)
      configure_database(database_config_path || DEFAULT_DATABASE_CONFIG_PATH)
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
end
