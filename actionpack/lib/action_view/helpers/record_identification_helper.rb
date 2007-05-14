module ActionView
  module Helpers
    module RecordIdentificationHelper
      # See ActionController::RecordIdentifier.partial_path -- this is just a delegate to that for convenient access in the view.
      def partial_path(*args, &block)
        ActionController::RecordIdentifier.partial_path(*args, &block)
      end

      # See ActionController::RecordIdentifier.dom_class -- this is just a delegate to that for convenient access in the view.
      def dom_class(*args, &block)
        ActionController::RecordIdentifier.dom_class(*args, &block)
      end

      # See ActionController::RecordIdentifier.dom_id -- this is just a delegate to that for convenient access in the view.
      def dom_id(*args, &block)
        ActionController::RecordIdentifier.dom_id(*args, &block)
      end
    end
  end
end