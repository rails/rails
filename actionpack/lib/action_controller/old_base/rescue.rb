module ActionController #:nodoc:
  # Actions that fail to perform as expected throw exceptions. These
  # exceptions can either be rescued for the public view (with a nice
  # user-friendly explanation) or for the developers view (with tons of
  # debugging information). The developers view is already implemented by
  # the Action Controller, but the public view should be tailored to your
  # specific application.
  #
  # The default behavior for public exceptions is to render a static html
  # file with the name of the error code thrown.  If no such file exists, an
  # empty response is sent with the correct status code.
  #
  # You can override what constitutes a local request by overriding the
  # <tt>local_request?</tt> method in your own controller. Custom rescue
  # behavior is achieved by overriding the <tt>rescue_action_in_public</tt>
  # and <tt>rescue_action_locally</tt> methods.
  module Rescue
    def self.included(base) #:nodoc:
      base.send :include, ActiveSupport::Rescuable
      base.extend(ClassMethods)

      base.class_eval do
        alias_method_chain :perform_action, :rescue
      end
    end

    module ClassMethods
      def rescue_action(env)
        exception = env.delete('action_dispatch.rescue.exception')
        request   = ActionDispatch::Request.new(env)
        response  = ActionDispatch::Response.new
        new.process(request, response, :rescue_action, exception).to_a
      end
    end

    protected
      # Exception handler called when the performance of an action raises
      # an exception.
      def rescue_action(exception)
        rescue_with_handler(exception) || raise(exception)
      end

    private
      def perform_action_with_rescue
        perform_action_without_rescue
      rescue Exception => exception
        rescue_action(exception)
      end
  end
end
