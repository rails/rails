# frozen_string_literal: true

module ActionMailer
  module Callbacks
    extend ActiveSupport::Concern

    DEFAULT_INTERNAL_METHODS = [:_run_deliver_callbacks].freeze # :nodoc:

    included do
      include ActiveSupport::Callbacks
      define_callbacks :deliver, skip_after_callbacks_if_terminated: true
    end

    module ClassMethods
      # Defines a callback that will get called right before the
      # message is sent to the delivery method.
      def before_deliver(*filters, &blk)
        _insert_callbacks(filters, blk) do |name, options|
          set_callback(:deliver, :before, name, options, &blk)
        end
      end

      # Defines a callback that will get called right after the
      # message's delivery method is finished.
      def after_deliver(*filters, &blk)
        _insert_callbacks(filters, blk) do |name, options|
          set_callback(:deliver, :after, name, options, &blk)
        end
      end

      # Defines a callback that will get called around the message's deliver method.
      def around_deliver(*filters, &blk)
        _insert_callbacks(filters, blk) do |name, options|
          set_callback(:deliver, :around, name, options, &blk)
        end
      end

      def internal_methods # :nodoc:
        super.concat(DEFAULT_INTERNAL_METHODS)
      end
    end
  end
end
