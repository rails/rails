# typed: true
# frozen_string_literal: true

begin
  gem "msgpack"
  require "msgpack"
rescue LoadError => error
  warn <<~MSG
    ActiveSupport::ErrorReporter::Encoders::MessagePack requires the msgpack gem.
    Please add it to your Gemfile: `gem "msgpack"`
  MSG
  raise error
end

module ActiveSupport
  class EventReporter
    module Encoders
      # EventReporter encoder for serializing events to MessagePack format.
      class MessagePack < Base
        def self.encode(event)
          event[:payload] = event[:payload].to_h
          event[:tags] = event[:tags].transform_values do |value|
            value.respond_to?(:to_h) ? value.to_h : value
          end
          ::MessagePack.pack(event)
        end
      end
    end
  end
end
