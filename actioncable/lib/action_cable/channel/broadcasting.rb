# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/to_param"

module ActionCable
  module Channel
    module Broadcasting
      extend ActiveSupport::Concern

      module ClassMethods
        # Broadcast a hash to a unique broadcasting for this array of `broadcastables` in this channel.
        def broadcast_to(broadcastables, message)
          ActionCable.server.broadcast(broadcasting_for(broadcastables), message)
        end

        # Returns a unique broadcasting identifier for this `model` in this channel:
        #
        #     CommentsChannel.broadcasting_for("all") # => "comments:all"
        #
        # You can pass an array of objects as a target (e.g. Active Record model), and it would
        # be serialized into a string under the hood.
        def broadcasting_for(broadcastables)
          serialize_broadcasting([ channel_name ] + Array(broadcastables))
        end

        private
          def serialize_broadcasting(object) # :nodoc:
            case
            when object.is_a?(Array)
              object.map { |m| serialize_broadcasting(m) }.join(":")
            when object.respond_to?(:to_gid_param)
              object.to_gid_param
            else
              object.to_param
            end
          end
      end

      def broadcasting_for(model)
        self.class.broadcasting_for(model)
      end

      def broadcast_to(model, message)
        self.class.broadcast_to(model, message)
      end
    end
  end
end
