# frozen_string_literal: true

require "active_support/callbacks"

module ActionCable
  module Channel
    module Callbacks
      extend  ActiveSupport::Concern
      include ActiveSupport::Callbacks

      included do
        define_callbacks :subscribe
        define_callbacks :unsubscribe
      end

      class_methods do
        def before_subscribe(*methods, &block)
          set_callback(:subscribe, :before, *methods, &block)
        end

        def after_subscribe(*methods, &block)
          set_callback(:subscribe, :after, *methods, &block)
        end
        alias_method :on_subscribe, :after_subscribe

        def before_unsubscribe(*methods, &block)
          set_callback(:unsubscribe, :before, *methods, &block)
        end

        def after_unsubscribe(*methods, &block)
          set_callback(:unsubscribe, :after, *methods, &block)
        end
        alias_method :on_unsubscribe, :after_unsubscribe
      end
    end
  end
end
