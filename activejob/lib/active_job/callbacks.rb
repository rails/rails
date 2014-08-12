require 'active_support/callbacks'

module ActiveJob
  module Callbacks
    extend  ActiveSupport::Concern
    include ActiveSupport::Callbacks
    
    included do
      define_callbacks :perform
      define_callbacks :enqueue
    end
    
    module ClassMethods
      def before_perform(*filters, &blk)
        set_callback(:perform, :before, *filters, &blk)
      end

      def after_perform(*filters, &blk)
        set_callback(:perform, :after, *filters, &blk)
      end

      def around_perform(*filters, &blk)
        set_callback(:perform, :around, *filters, &blk)
      end


      def before_enqueue(*filters, &blk)
        set_callback(:enqueue, :before, *filters, &blk)
      end

      def after_enqueue(*filters, &blk)
        set_callback(:enqueue, :after, *filters, &blk)
      end

      def around_enqueue(*filters, &blk)
        set_callback(:enqueue, :around, *filters, &blk)
      end
    end
  end
end