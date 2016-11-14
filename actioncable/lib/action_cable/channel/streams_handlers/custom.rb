module ActionCable
  module Channel
    module StreamsHandlers
      class NullCoder
        class << self
          def decode(val)
            val
          end

          alias encode decode
        end
      end

      class Custom < Base # :nodoc:
        attr_reader :handler, :coder

        def initialize(channel, handler:, coder:)
          super
          @handler = handler
          @coder = coder || NullCoder
        end

        def call(message)
          handler.(coder.decode(message))
        end
      end
    end
  end
end
