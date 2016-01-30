require 'active_support/core_ext/object/to_param'

module ActionCable
  module Channel
    module Broadcasting
      extend ActiveSupport::Concern

      delegate :broadcasting_for, :broadcast_to, to: :class

      class_methods do
        # Broadcast a hash to a unique broadcasting for this <tt>model</tt> in this channel.
        def broadcast_to(model, message = nil)
          return EventProxy.new(self, model) if message.nil? # If invoked with single argument
          ActionCable.server.broadcast(broadcasting_for([ channel_name, model ]), message)
        end

        def broadcasting_for(model) #:nodoc:
          case
          when model.is_a?(Array)
            model.map { |m| broadcasting_for(m) }.join(':')
          when model.respond_to?(:to_gid_param)
            model.to_gid_param
          else
            model.to_param
          end
        end
      end

      # This class is used internally to provide a method proxy for evented client side channels
      class EventProxy
        def initialize(channel, model)
          @channel, @model = channel, model
        end

        # Allow triggering of any named event, useful to be explicit or to trigger events having
        # a name not valid as ruby method name
        def trigger(event_name, *args)
          message = {event_name: event_name}
          message[:args] = args if args.any?
          @channel.broadcast_to(@model, message)
        end

        # Broadcast any method called as event named like the invoked method
        def method_missing(meth, *args)
          trigger meth, *args
        end
      end
    end
  end
end
