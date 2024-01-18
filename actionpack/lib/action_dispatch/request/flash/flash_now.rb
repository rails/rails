# frozen_string_literal: true

module ActionDispatch
  class Request
    module Flash
      class FlashNow # :nodoc:
        attr_accessor :flash

        def initialize(flash)
          @flash = flash
        end

        def []=(k, v)
          k = k.to_s
          @flash[k] = v
          @flash.discard(k)
          v
        end

        def [](k)
          @flash[k.to_s]
        end

        # Convenience accessor for <tt>flash.now[:alert]=</tt>.
        def alert=(message)
          self[:alert] = message
        end

        # Convenience accessor for <tt>flash.now[:notice]=</tt>.
        def notice=(message)
          self[:notice] = message
        end
      end
    end
  end
end
