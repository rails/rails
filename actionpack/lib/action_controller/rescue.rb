module ActionController #:nodoc:
  # Actions that fail to perform as expected throw exceptions. These exceptions can either be rescued for the public view
  # (with a nice user-friendly explanation) or for the developers view (with tons of debugging information). The developers view
  # is already implemented by the Action Controller, but the public view should be tailored to your specific application. So too
  # could the decision on whether something is a public or a developer request.
  #
  # You can tailor the rescuing behavior and appearance by overwriting the following two stub methods.
  module Rescue
    LOCALHOST = '127.0.0.1'.freeze

    DEFAULT_RESCUE_RESPONSE = :internal_server_error
    DEFAULT_RESCUE_RESPONSES = {
      'ActionController::RoutingError'    => :not_found,
      'ActionController::UnknownAction'   => :not_found
    }

    DEFAULT_RESCUE_TEMPLATE = 'diagnostics'
    DEFAULT_RESCUE_TEMPLATES = {
      'ActionController::MissingTemplate' => 'missing_template',
      'ActionController::RoutingError'    => 'routing_error',
      'ActionController::UnknownAction'   => 'unknown_action',
      'ActionView::TemplateError'         => 'template_error'
    }

    def self.included(base) #:nodoc:
      base.cattr_accessor :rescue_responses
      base.rescue_responses = Hash.new(DEFAULT_RESCUE_RESPONSE)
      base.rescue_responses.update DEFAULT_RESCUE_RESPONSES

      base.cattr_accessor :rescue_templates
      base.rescue_templates = Hash.new(DEFAULT_RESCUE_TEMPLATE)
      base.rescue_templates.update DEFAULT_RESCUE_TEMPLATES

      base.extend(ClassMethods)
      base.class_eval do
        alias_method_chain :perform_action, :rescue
      end
    end

    module ClassMethods #:nodoc:
      def process_with_exception(request, response, exception)
        new.process(request, response, :rescue_action, exception)
      end
    end

    protected
      # Exception handler called when the performance of an action raises an exception.
      def rescue_action(exception)
        log_error(exception) if logger
        erase_results if performed?

        if consider_all_requests_local || local_request?
          rescue_action_locally(exception)
        else
          rescue_action_in_public(exception)
        end
      end

      # Overwrite to implement custom logging of errors. By default logs as fatal.
      def log_error(exception) #:doc:
        if ActionView::TemplateError === exception
          logger.fatal(exception.to_s)
        else
          logger.fatal(
            "\n\n#{exception.class} (#{exception.message}):\n    " +
            clean_backtrace(exception).join("\n    ") +
            "\n\n"
          )
        end
      end


      # Overwrite to implement public exception handling (for requests answering false to <tt>local_request?</tt>).
      def rescue_action_in_public(exception) #:doc:
        render_optional_error_file response_code_for_rescue(exception)
      end

      def render_optional_error_file(status_code) #:nodoc:
        status = interpret_status(status_code)
        path = "#{RAILS_ROOT}/public/#{status[0,3]}.html"
        if File.exists?(path)
          render :file => path, :status => status
        else
          head status
        end
      end

      # True if the request came from localhost, 127.0.0.1. Override this
      # method if you wish to redefine the meaning of a local request to
      # include remote IP addresses or other criteria.
      def local_request? #:doc:
        request.remote_addr == LOCALHOST and request.remote_ip == LOCALHOST
      end

      # Render detailed diagnostics for unhandled exceptions rescued from
      # a controller action.
      def rescue_action_locally(exception)
        add_variables_to_assigns
        @template.instance_variable_set("@exception", exception)
        @template.instance_variable_set("@rescues_path", File.dirname(rescues_path("stub")))
        @template.send(:assign_variables_from_controller)

        @template.instance_variable_set("@contents", @template.render_file(template_path_for_local_rescue(exception), false))

        response.content_type = Mime::HTML
        render_file(rescues_path("layout"), response_code_for_rescue(exception))
      end

    private
      def perform_action_with_rescue #:nodoc:
        perform_action_without_rescue
      rescue Exception => exception  # errors from action performed
        if defined?(Breakpoint) && params["BP-RETRY"]
          msg = exception.backtrace.first
          if md = /^(.+?):(\d+)(?::in `(.+)')?$/.match(msg) then
            origin_file, origin_line = md[1], md[2].to_i

            set_trace_func(lambda do |type, file, line, method, context, klass|
              if file == origin_file and line == origin_line then
                set_trace_func(nil)
                params["BP-RETRY"] = false

                callstack = caller
                callstack.slice!(0) if callstack.first["rescue.rb"]
                file, line, method = *callstack.first.match(/^(.+?):(\d+)(?::in `(.*?)')?/).captures

                message = "Exception at #{file}:#{line}#{" in `#{method}'" if method}." # `´ ( for ruby-mode)

                Breakpoint.handle_breakpoint(context, message, file, line)
              end
            end)

            retry
          end
        end

        rescue_action(exception)
      end

      def rescues_path(template_name)
        "#{File.dirname(__FILE__)}/templates/rescues/#{template_name}.rhtml"
      end

      def template_path_for_local_rescue(exception)
        rescues_path(rescue_templates[exception.class.name])
      end

      def response_code_for_rescue(exception)
        rescue_responses[exception.class.name]
      end

      def clean_backtrace(exception)
        if backtrace = exception.backtrace
          if defined?(RAILS_ROOT)
            backtrace.map { |line| line.sub RAILS_ROOT, '' }
          else
            backtrace
          end
        end
      end
  end
end
