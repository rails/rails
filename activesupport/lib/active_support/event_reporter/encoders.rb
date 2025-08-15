# typed: true
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

      extend ActiveSupport::Autoload
      autoload :JSON
      autoload :MessagePack
    end
  end
end
