module ActionController #:nodoc:
  # This module is responsible for providing `rescue_from` helpers
  # to controllers and configuring when detailed exceptions must be
  # shown.
  module Rescue
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    # Override this method if you want to customize when detailed
    # exceptions must be shown. This method is only called when
    # consider_all_requests_local is false. By default, it returns
    # false, but someone may set it to `request.local?` so local
    # requests in production still show the detailed exception pages.
    def show_detailed_exceptions?
      false
    end

    private
      def process_action(*args)
        super
      rescue Exception => exception
        request.env["action_dispatch.show_detailed_exceptions"] ||= show_detailed_exceptions?
        rescue_with_handler(exception) || raise
      end
  end
end
