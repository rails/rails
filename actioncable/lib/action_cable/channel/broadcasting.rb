# frozen_string_literal: true

require "active_support/core_ext/object/to_param"

module ActionCable
  module Channel
    module Broadcasting
      extend ActiveSupport::Concern

      delegate :broadcasting_for, to: :class

      module ClassMethods
        # Broadcast a hash to a unique broadcasting for this <tt>model</tt> in this channel.
        def broadcast_to(model, message)
          ActionCable.server.broadcast(broadcasting_for(model), message)
        end

        # Returns a unique broadcasting identifier for this <tt>model</tt> in this channel.
        def broadcasting_for(model)
          serialize_broadcasting([ channel_name, model ])
        end

        def serialize_broadcasting(object) #:nodoc:
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
