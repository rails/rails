module ActionController #:nodoc:
  module Rescue
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    private
      def process_action(*args)
        super
      rescue Exception => exception
        rescue_with_handler(exception) || raise(exception)
      end
  end
end
