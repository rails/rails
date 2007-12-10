module ActionController #:nodoc:
  # Actions that fail to perform as expected throw exceptions. These exceptions can either be rescued for the public view
  # (with a nice user-friendly explanation) or for the developers view (with tons of debugging information). The developers view
  # is already implemented by the Action Controller, but the public view should be tailored to your specific application. 
  # 
  # The default behavior for public exceptions is to render a static html file with the name of the error code thrown.  If no such 
  # file exists, an empty response is sent with the correct status code.
  #
  # You can override what constitutes a local request by overriding the <tt>local_request?</tt> method in your own controller.
  # Custom rescue behavior is achieved by overriding the <tt>rescue_action_in_public</tt> and <tt>rescue_action_locally</tt> methods.
  module Rescue
    LOCALHOST = '127.0.0.1'.freeze

    DEFAULT_RESCUE_RESPONSE = :internal_server_error
    DEFAULT_RESCUE_RESPONSES = {
      'ActionController::RoutingError'             => :not_found,
      'ActionController::UnknownAction'            => :not_found,
      'ActiveRecord::RecordNotFound'               => :not_found,
      'ActiveRecord::StaleObjectError'             => :conflict,
      'ActiveRecord::RecordInvalid'                => :unprocessable_entity,
      'ActiveRecord::RecordNotSaved'               => :unprocessable_entity,
      'ActionController::MethodNotAllowed'         => :method_not_allowed,
      'ActionController::NotImplemented'           => :not_implemented,
      'ActionController::InvalidAuthenticityToken' => :unprocessable_entity
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

      base.class_inheritable_array :rescue_handlers
      base.rescue_handlers = []

      base.extend(ClassMethods)
      base.class_eval do
        alias_method_chain :perform_action, :rescue
      end
    end

    module ClassMethods
      def process_with_exception(request, response, exception) #:nodoc:
        new.process(request, response, :rescue_action, exception)
      end

      # Rescue exceptions raised in controller actions.
      #
      # <tt>rescue_from</tt> receives a series of exception classes or class
      # names, and a trailing :with option with the name of a method or a Proc
      # object to be called to handle them. Alternatively a block can be given.
      #
      # Handlers that take one argument will be called with the exception, so
      # that the exception can be inspected when dealing with it.
      #
      # Handlers are inherited. They are searched from right to left, from
      # bottom to top, and up the hierarchy. The handler of the first class for
      # which exception.is_a?(klass) holds true is the one invoked, if any.
      #
      # class ApplicationController < ActionController::Base
      #   rescue_from User::NotAuthorized, :with => :deny_access # self defined exception
      #   rescue_from ActiveRecord::RecordInvalid, :with => :show_errors
      #
      #   rescue_from 'MyAppError::Base' do |exception|
      #     render :xml => exception, :status => 500
      #   end
      #
      #   protected
      #     def deny_access
      #       ...
      #     end
      #
      #     def show_errors(exception)
      #       exception.record.new_record? ? ...
      #     end
      # end
      def rescue_from(*klasses, &block)
        options = klasses.extract_options!
        unless options.has_key?(:with)
          block_given? ? options[:with] = block : raise(ArgumentError, "Need a handler. Supply an options hash that has a :with key as the last argument.")
        end

        klasses.each do |klass|
          key = if klass.is_a?(Class) && klass <= Exception
            klass.name
          elsif klass.is_a?(String)
            klass
          else
            raise(ArgumentError, "#{klass} is neither an Exception nor a String")
          end

          # Order is important, we put the pair at the end. When dealing with an
          # exception we will follow the documented order going from right to left.
          rescue_handlers << [key, options[:with]]
        end
      end
    end

    protected
      # Exception handler called when the performance of an action raises an exception.
      def rescue_action(exception)
        log_error(exception) if logger
        erase_results if performed?

        # Let the exception alter the response if it wants.
        # For example, MethodNotAllowed sets the Allow header.
        if exception.respond_to?(:handle_response!)
          exception.handle_response!(response)
        end

        if consider_all_requests_local || local_request?
          rescue_action_locally(exception)
        else
          rescue_action_in_public(exception)
        end
      end

      # Overwrite to implement custom logging of errors. By default logs as fatal.
      def log_error(exception) #:doc:
        ActiveSupport::Deprecation.silence do
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
      end

      # Overwrite to implement public exception handling (for requests answering false to <tt>local_request?</tt>).  By
      # default will call render_optional_error_file.  Override this method to provide more user friendly error messages.s
      def rescue_action_in_public(exception) #:doc:
        render_optional_error_file response_code_for_rescue(exception)
      end
      
      # Attempts to render a static error page based on the <tt>status_code</tt> thrown,
      # or just return headers if no such file exists. For example, if a 500 error is 
      # being handled Rails will first attempt to render the file at <tt>public/500.html</tt>. 
      # If the file doesn't exist, the body of the response will be left empty.
      def render_optional_error_file(status_code)
        status = interpret_status(status_code)
        path = "#{RAILS_ROOT}/public/#{status[0,3]}.html"
        if File.exist?(path)
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
        @template.send!(:assign_variables_from_controller)

        @template.instance_variable_set("@contents", @template.render_file(template_path_for_local_rescue(exception), false))

        response.content_type = Mime::HTML
        render_for_file(rescues_path("layout"), response_code_for_rescue(exception))
      end

      # Tries to rescue the exception by looking up and calling a registered handler.
      def rescue_action_with_handler(exception)
        if handler = handler_for_rescue(exception)
          if handler.arity != 0
            handler.call(exception)
          else
            handler.call
          end
          true # don't rely on the return value of the handler
        end
      end

    private
      def perform_action_with_rescue #:nodoc:
        perform_action_without_rescue
      rescue Exception => exception  # errors from action performed
        return if rescue_action_with_handler(exception)
        
        rescue_action(exception)
      end

      def rescues_path(template_name)
        "#{File.dirname(__FILE__)}/templates/rescues/#{template_name}.erb"
      end

      def template_path_for_local_rescue(exception)
        rescues_path(rescue_templates[exception.class.name])
      end

      def response_code_for_rescue(exception)
        rescue_responses[exception.class.name]
      end

      def handler_for_rescue(exception)
        # We go from right to left because pairs are pushed onto rescue_handlers
        # as rescue_from declarations are found.
        _, handler = *rescue_handlers.reverse.detect do |klass_name, handler|
          # The purpose of allowing strings in rescue_from is to support the
          # declaration of handler associations for exception classes whose
          # definition is yet unknown.
          #
          # Since this loop needs the constants it would be inconsistent to
          # assume they should exist at this point. An early raised exception
          # could trigger some other handler and the array could include
          # precisely a string whose corresponding constant has not yet been
          # seen. This is why we are tolerant to unknown constants.
          #
          # Note that this tolerance only matters if the exception was given as
          # a string, otherwise a NameError will be raised by the interpreter
          # itself when rescue_from CONSTANT is executed.
          klass = self.class.const_get(klass_name) rescue nil
          klass ||= klass_name.constantize rescue nil
          exception.is_a?(klass) if klass
        end

        case handler
        when Symbol
          method(handler)
        when Proc
          handler.bind(self)
        end
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
