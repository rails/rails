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
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Rescuable
    end

    module ClassMethods
      # This can be removed once we can move action(:_rescue_action) into middlewares.rb
      # Currently, it does controller.method(:rescue_action), which is hiding the implementation
      # difference between the old and new base.
      def rescue_action(env)
        action(:_rescue_action).call(env)
      end
    end

    attr_internal :rescued_exception

    private
      def method_for_action(action_name)
        return action_name if self.rescued_exception = request.env.delete("action_dispatch.rescue.exception")
        super
      end

      def _rescue_action
        rescue_with_handler(rescued_exception) || raise(rescued_exception)
      end

      def process_action(*)
        super
      rescue Exception => exception
        self.rescued_exception = exception
        _rescue_action
      end
  end
end
