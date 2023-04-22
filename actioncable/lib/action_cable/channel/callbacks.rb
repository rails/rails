# frozen_string_literal: true

require "active_support/callbacks"

module ActionCable
  module Channel
    # = Action Cable \Channel \Callbacks
    #
    # Action Cable Channel provides hooks during the life cycle of a channel subscription.
    # Callbacks allow triggering logic during this cycle. Available callbacks are:
    #
    # * <tt>before_subscribe</tt>
    # * <tt>after_subscribe</tt> (also aliased as: <tt>on_subscribe</tt>)
    # * <tt>before_unsubscribe</tt>
    # * <tt>after_unsubscribe</tt> (also aliased as: <tt>on_unsubscribe</tt>)
    #
    # NOTE: the <tt>after_subscribe</tt> callback is triggered whenever
    # the <tt>subscribed</tt> method is called, even if subscription was rejected
    # with the <tt>reject</tt> method.
    # To trigger <tt>after_subscribe</tt> only on successful subscriptions,
    # use <tt>after_subscribe :my_method_name, unless: :subscription_rejected?</tt>
    #
    module Callbacks
      extend  ActiveSupport::Concern
      include ActiveSupport::Callbacks

      included do
        define_callbacks :subscribe
        define_callbacks :unsubscribe
      end

      module ClassMethods
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
