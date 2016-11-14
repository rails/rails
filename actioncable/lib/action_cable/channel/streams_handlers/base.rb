module ActionCable
  module Channel
    module StreamsHandlers
      class Base # :nodoc:
        attr_reader :channel, :identifier

        delegate :connection, :identifier, to: :channel

        def initialize(channel, **options)
          @channel = channel
        end

        def call(message)
          # We can skip message decoding and generate payload in a more simple way
          connection.transmit(
            "{\"identifier\":#{identifier.to_json},\"message\":#{message}}",
            true
          )
        end
      end
    end
  end
end
