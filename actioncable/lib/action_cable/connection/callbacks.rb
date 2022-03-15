# frozen_string_literal: true

require "active_support/callbacks"

module ActionCable
  module Connection
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
