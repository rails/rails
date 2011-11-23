module ActionController #:nodoc:
  module Rescue
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    included do
      config_accessor :consider_all_requests_local
      self.consider_all_requests_local = false if consider_all_requests_local.nil?
    end

    def rescue_with_handler(exception)
      if (exception.respond_to?(:original_exception) &&
          (orig_exception = exception.original_exception) &&
          handler_for_rescue(orig_exception))
        exception = orig_exception
      end
      super(exception)
    end

    def show_detailed_exceptions?
      consider_all_requests_local || request.local?
    end

    private
      def process_action(*args)
        super
      rescue Exception => exception
        request.env['action_dispatch.show_detailed_exceptions'] = show_detailed_exceptions?
        rescue_with_handler(exception) || raise(exception)
      end
  end
end
