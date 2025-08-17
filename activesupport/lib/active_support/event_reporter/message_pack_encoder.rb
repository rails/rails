# frozen_string_literal: true

begin
  gem "msgpack", ">= 1.7.0"
  require "msgpack"
rescue LoadError => error
  warn "ActiveSupport::EventReporter::MessagePackEncoder requires the msgpack gem, version 1.7.0 or later. " \
    "Please add it to your Gemfile: `gem \"msgpack\", \">= 1.7.0\"`"
  raise error
end

module ActiveSupport
  class EventReporter
    # EventReporter encoder for serializing events to MessagePack format.
    module MessagePackEncoder
      class << self
        def encode(event)
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
