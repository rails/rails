# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/to_param"

module ActionCable
  module Channel
    module Broadcasting
      extend ActiveSupport::Concern

      delegate :broadcasting_for_list, :broadcasting_for, :broadcast_to_list, :broadcast_to, to: :class

      module ClassMethods
        # Broadcast a hash to a unique broadcasting for this `model` in this channel.
        def broadcast_to(model, message)
          ActionCable.server.broadcast(broadcasting_for(model), message)
        end

        # Broadcast a hash to multiple broadcasting for this `model` in this channel.
        def broadcast_to_list(model, message)
          ActionCable.server.broadcast_list(broadcasting_for(model), message)
        end

        def broadcasting_for(model)
          serialize_broadcasting([ channel_name, model ])
        end

        # Returns a unique broadcasting identifier for this `list` in this channel.
        # If any of the elements in the list contains a "-" character,
        # it raises an ArgumentError as it violates the nomenclature.
        def broadcasting_for_list(list)
          serialized_list = list.map { |broadcasting| serialize_broadcasting(broadcasting) }
          if serialized_list.any? { |broadcasting| broadcasting.include?("-") }
            raise ArgumentError, "Serialized broadcasting contains a '-' character"
          end
          broadcasting_for(serialized_list.join("-"))
        end

        private
          # Returns a unique broadcasting identifier for this `model` in this channel:
          #
          #    CommentsChannel.broadcasting_for("all") # => "comments:all"
          #
          # You can pass any object as a target (e.g. Active Record model), and it would
          # be serialized into a string under the hood.

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
    end
  end
end
