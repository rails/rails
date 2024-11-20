# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Suppressor
  #
  # ActiveRecord::Suppressor prevents the receiver from being saved during
  # a given block.
  #
  # For example, here's a pattern of creating notifications when new comments
  # are posted. (The notification may in turn trigger an email, a push
  # notification, or just appear in the UI somewhere):
  #
  #   class Comment < ActiveRecord::Base
  #     belongs_to :commentable, polymorphic: true
  #     after_create -> { Notification.create! comment: self,
  #       recipients: commentable.recipients }
  #   end
  #
  # That's what you want the bulk of the time. New comment creates a new
  # Notification. But there may well be off cases, like copying a commentable
  # and its comments, where you don't want that. So you'd have a concern
  # something like this:
  #
  #   module Copyable
  #     def copy_to(destination)
  #       Notification.suppress do
  #         # Copy logic that creates new comments that we do not want
  #         # triggering notifications.
  #       end
  #     end
  #   end
  module Suppressor
    extend ActiveSupport::Concern

    class << self
      def registry # :nodoc:
        ActiveSupport::IsolatedExecutionState[:active_record_suppressor_registry] ||= {}
      end
    end

    module ClassMethods
      def suppress(&block)
        previous_state = Suppressor.registry[name]
        Suppressor.registry[name] = true
        yield
      ensure
        Suppressor.registry[name] = previous_state
      end
    end

    def save(**) # :nodoc:
      Suppressor.registry[self.class.name] ? true : super
    end

    def save!(**) # :nodoc:
      Suppressor.registry[self.class.name] ? true : super
    end
  end
end
