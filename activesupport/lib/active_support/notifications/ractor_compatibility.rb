# frozen_string_literal: true

require "active_support/ractors"

module ActiveSupport
  module Notifications
    module RactorCompatibility # :nodoc:
      extend self

      attr_accessor :subscriptions

      def record_subscriptions(notifier)
        notifier_subscriptions = {
          string_subscribers: Hash[notifier.string_subscribers.keys.zip(notifier.string_subscribers.values)],
          other_subscribers: notifier.other_subscribers,
        }

        self.subscriptions = ActiveSupport::Ractors.try_make_shareable(notifier_subscriptions, copy: true)
      end

      def set_subscriptions(notifier)
        notifier.string_subscribers = self.subscriptions[:string_subscribers]
        notifier.other_subscribers = self.subscriptions[:other_subscribers]
      end
    end
  end
end
