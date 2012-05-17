module ActionController #:nodoc:
  # This module is responsible to provide `rescue_from` helpers
  # to controllers and configure when detailed exceptions must be
  # shown.
  module Rescue
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    def rescue_with_handler(exception)
      if (exception.respond_to?(:original_exception) &&
          (orig_exception = exception.original_exception) &&
          handler_for_rescue(orig_exception))
        exception = orig_exception
      end
      super(exception)
    end

    # Override this method if you want to customize when detailed
    # exceptions must be shown. This method is only called when
    # consider_all_requests_local is false. By default, it returns
    # false, but someone may set it to `request.local?` so local
    # requests in production still shows the detailed exception pages.
    def show_detailed_exceptions?
      false
    end

    private
      def process_action(*args)
        super
      rescue Exception => exception
        request.env['action_dispatch.show_detailed_exceptions'] ||= show_detailed_exceptions?
        rescue_with_handler(exception) || raise(exception)
      end
  end
end
