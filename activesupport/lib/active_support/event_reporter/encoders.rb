# frozen_string_literal: true

module ActiveSupport
  class EventReporter
    # = Event Encoders
    #
    # Default encoders for serializing structured events. These encoders can be used
    # by subscribers to convert event data into various formats.
    #
    # Example usage in a subscriber:
    #
    #   class LogSubscriber
    #     def emit(event)
    #       encoded_data = ActiveSupport::EventReporter::Encoders::JSON.encode(event)
    #       Rails.logger.info(encoded_data)
    #     end
    #   end
    #
    #   Rails.event.subscribe(LogSubscriber)
    module Encoders
      # Base encoder class that other encoders can inherit from.
      class Base
        # Encodes an event hash into a serialized format.
        #
        # @param event [Hash] The event hash containing name, payload, tags, context, timestamp, and source_location
        # @return [String] The encoded event data
        def self.encode(event)
          raise NotImplementedError, "Subclasses must implement #encode"
        end
      end

      # JSON encoder for serializing events to JSON format.
      #
      #   event = { name: "user_created", payload: { id: 123 }, tags: { api: true } }
      #   ActiveSupport::EventReporter::Encoders::JSON.encode(event)
      #   # => {
      #   #      "name": "user_created",
      #   #      "payload": {
      #   #        "id": 123
      #   #      },
      #   #      "tags": {
      #   #        "api": true
      #   #      },
      #   #      "context": {}
      #   #    }
      #
      # Schematized events and tags MUST respond to #to_h to be serialized.
      #
      #   event = { name: "UserCreatedEvent", payload: #<UserCreatedEvent:0x111>, tags: { "GraphqlTag": #<GraphqlTag:0x111> } }
      #   ActiveSupport::EventReporter::Encoders::JSON.encode(event)
      #   # => {
      #   #      "name": "UserCreatedEvent",
      #   #      "payload": {
      #   #        "id": 123
      #   #      },
      #   #      "tags": {
      #   #        "GraphqlTag": {
      #   #          "operation_name": "user_created",
      #   #          "operation_type": "mutation"
      #   #        }
      #   #      },
      #   #      "context": {}
      #   #    }
      class JSON < Base
        def self.encode(event)
          event[:payload] = event[:payload].to_h
          event[:tags] = event[:tags].transform_values do |value|
            value.respond_to?(:to_h) ? value.to_h : value
          end
          ::JSON.dump(event)
        end
      end

      # EventReporter encoder for serializing events to MessagePack format.
      class MessagePack < Base
        def self.encode(event)
          require "msgpack"
          event[:payload] = event[:payload].to_h
          event[:tags] = event[:tags].transform_values do |value|
            value.respond_to?(:to_h) ? value.to_h : value
          end
          ::MessagePack.pack(event)
        rescue LoadError
          raise LoadError, "msgpack gem is required for MessagePack encoding. Add 'gem \"msgpack\"' to your Gemfile."
        end
      end
    end
  end
end
