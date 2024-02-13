# frozen_string_literal: true

# :markup: markdown

require "active_support/callbacks"

module ActionCable
  module Channel
    # # Action Cable Channel Callbacks
    #
    # Action Cable Channel provides callback hooks that are invoked during the life
    # cycle of a channel:
    #
    # *   [before_subscribe](rdoc-ref:ClassMethods#before_subscribe)
    # *   [after_subscribe](rdoc-ref:ClassMethods#after_subscribe) (aliased as
    #     [on_subscribe](rdoc-ref:ClassMethods#on_subscribe))
    # *   [before_unsubscribe](rdoc-ref:ClassMethods#before_unsubscribe)
    # *   [after_unsubscribe](rdoc-ref:ClassMethods#after_unsubscribe) (aliased as
    #     [on_unsubscribe](rdoc-ref:ClassMethods#on_unsubscribe))
    #
    #
    # #### Example
    #
    #     class ChatChannel < ApplicationCable::Channel
    #       after_subscribe :send_welcome_message, unless: :subscription_rejected?
    #       after_subscribe :track_subscription
    #
    #       private
    #         def send_welcome_message
    #           broadcast_to(...)
    #         end
    #
    #         def track_subscription
    #           # ...
    #         end
    #     end
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

        # This callback will be triggered after the Base#subscribed method is called,
        # even if the subscription was rejected with the Base#reject method.
        #
        # To trigger the callback only on successful subscriptions, use the
        # Base#subscription_rejected? method:
        #
        #     after_subscribe :my_method, unless: :subscription_rejected?
        #
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
