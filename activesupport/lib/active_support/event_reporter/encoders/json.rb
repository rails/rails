# typed: true
# frozen_string_literal: true

module ActiveSupport
  class EventReporter
    module Encoders
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
    end
  end
end
