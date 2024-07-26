module ActionController #:nodoc:
  # Actions that fail to perform as expected throw exceptions. These exceptions can either be rescued for the public view 
  # (with a nice user-friendly explanation) or for the developers view (with tons of debugging information). The developers view
  # is already implemented by the Action Controller, but the public view should be tailored to your specific application. So too
  # could the decision on whether something is a public or a developer request.
  #
  # You can tailor the rescuing behavior and appearance by overwriting the following two stub methods.
  module Rescue
    def self.append_features(base) #:nodoc:
      super
      base.class_eval {
        alias_method :perform_action_without_rescue, :perform_action
        alias_method :perform_action, :perform_action_with_rescue
      }
    end

    def perform_action_with_rescue #:nodoc:
      begin
        perform_action_without_rescue
      rescue Exception => exception
        rescue_action(exception)
      ensure
        close_session
      end
    end

    # Exception handler called when the performance of an action raises an exception.
    def rescue_action(exception) #:nodoc:
      local_request? ? rescue_action_locally(exception) : rescue_action_in_public(exception)
    end

    # Overwrite to implement public exception handling (for requests answering false to <tt>local_request?</tt>).
    def rescue_action_in_public(exception)
      render_text "<html><body><h1>Application error</h1></body></html>"
    end

    # Overwrite to expand the meaning of a local request in order to show local rescues on other occurances than
    # the remote IP beging 127.0.0.1. For example, this include the IP of the developer machine when debugging
    # remotely.
    def local_request? #:doc:
      @request.remote_addr == "127.0.0.1"
    end

    # Renders a detailed diagnostics screen on action exceptions. 
    def rescue_action_locally(exception) #:nodoc:
      @exception = exception
      add_variables_to_assigns
      @contents = @template.render_file(template_path_for_local_rescue(exception), false)
      
      render_file(rescues_path("layout"), "500 Internal Error")
    end
    
    private
      def rescues_path(template_name)
        File.dirname(__FILE__) + "/templates/rescues/#{template_name}.rhtml"
      end

      def template_path_for_local_rescue(exception)
        rescues_path(
          case exception
            when MissingTemplate then "missing_template"
            when UnknownAction   then "unknown_action"
            when ActionView::TemplateError then "template_error"
            else "diagnostics"
          end
        )
      end
  end
end