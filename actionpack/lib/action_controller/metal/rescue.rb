module ActionController #:nodoc:
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

    private
      def process_action(*args)
        super
      rescue Exception => exception
        rescue_with_handler(exception) || raise(exception)
      end
  end
end
