require "active_support/callbacks"

module ActionMailroom
  class Mailbox
    module Callbacks
      extend  ActiveSupport::Concern
      include ActiveSupport::Callbacks

      included do
        define_callbacks :process
      end

      module ClassMethods
        def before_processing(*methods, &block)
          set_callback(:process, :before, *methods, &block)
        end

        def after_processing(*methods, &block)
          set_callback(:process, :after, *methods, &block)
        end

        def around_processing(*methods, &block)
          set_callback(:process, :around, *methods, &block)
        end
      end
    end
  end
end
