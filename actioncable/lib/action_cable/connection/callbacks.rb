# frozen_string_literal: true

require "active_support/callbacks"

module ActionCable
  module Connection
    # = Action Cable \Connection \Callbacks
    #
    # There are <tt>before_command</tt>, <tt>after_command</tt>, and <tt>around_command</tt> callbacks
    # available to be invoked before, after or around every command received by a client respectively.
    # The term "command" here refers to any interaction received by a client (subscribing, unsubscribing or performing actions):
    #
    #    module ApplicationCable
    #      class Connection < ActionCable::Connection::Base
    #        identified_by :user
    #
    #        around_command :set_current_account
    #
    #        private
    #
    #        def set_current_account
    #          # Now all channels could use Current.account
    #          Current.set(account: user.account) { yield }
    #        end
    #      end
    #    end
    #
    module Callbacks
      extend  ActiveSupport::Concern
      include ActiveSupport::Callbacks

      included do
        define_callbacks :command
      end

      module ClassMethods
        def before_command(*methods, &block)
          set_callback(:command, :before, *methods, &block)
        end

        def after_command(*methods, &block)
          set_callback(:command, :after, *methods, &block)
        end

        def around_command(*methods, &block)
          set_callback(:command, :around, *methods, &block)
        end
      end
    end
  end
end
