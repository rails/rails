# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/parameter_filter"

module ActionCable
  module Connection
    # # Action Cable Connection Subscriptions
    #
    # Collection class for all the channel subscriptions established on a given
    # connection. Responsible for routing incoming commands that arrive on the
    # connection to the proper channel.
    class Subscriptions # :nodoc:
      class Error < StandardError; end

      class AlreadySubscribedError < Error
        def initialize(identifier)
          super "Already subscribed to #{identifier}"
        end
      end

      class ChannelNotFound < Error
        def initialize(channel_id)
          super "Channel not found: #{channel_id}"
        end
      end

      class MalformedCommandError < Error
        def initialize(data)
          super "Malformed command: #{data.inspect}"
        end
      end

      class UnknownCommandError < Error
        def initialize(command)
          super "Received unrecognized command: #{command}"
        end
      end

      class UnknownSubscription < Error
        def initialize(identifier)
          super "Unable to find subscription with identifier: #{identifier}"
        end
      end

      class MissingIdentifier < Error
        def initialize
          super "Identifier is required"
        end
      end

      def initialize(connection)
        @connection = connection
        @subscriptions = {}
      end

      def execute_command(data)
        case data["command"]
        when "subscribe"   then add data
        when "unsubscribe" then remove data
        when "message"     then perform_action data
        else
          raise UnknownCommandError, data["command"]
        end
      end

      def add(data)
        id_key = data["identifier"]

        raise MalformedCommandError, filtered_command(data) unless id_key.present?

        raise AlreadySubscribedError, filtered_identifier(id_key) if subscriptions.key?(id_key)

        subscription = subscription_from_identifier(id_key)

        if subscription
          subscriptions[id_key] = subscription
          subscription.subscribe_to_channel
        else
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
          raise ChannelNotFound, id_options[:channel]
        end
      end

      def remove(data)
        raise MissingIdentifier unless data["identifier"].present?

        logger.info "Unsubscribing from channel: #{filtered_identifier(data["identifier"])}"
        subscription = find(data)
        remove_subscription(subscription) if subscription
      end

      def remove_subscription(subscription)
        subscription.unsubscribe_from_channel
        subscriptions.delete(subscription.identifier)
      end

      def perform_action(data)
        subscription = find(data)
        raise UnknownSubscription.new(filtered_identifier(data["identifier"])) unless subscription
        subscription.perform_action ActiveSupport::JSON.decode(data["data"])
      end

      def identifiers
        subscriptions.keys
      end

      def unsubscribe_from_all
        subscriptions.each { |id, channel| remove_subscription(channel) }
      end

      private
        attr_reader :connection, :subscriptions
        delegate :logger, to: :connection

        def find(data)
          subscriptions[data["identifier"]]
        end

        def subscription_from_identifier(id_key)
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
          subscription_klass = id_options[:channel]&.safe_constantize

          if subscription_klass && ActionCable::Channel::Base > subscription_klass
            subscription_klass.new(connection, id_key, id_options)
          end
        end

        def filtered_identifier(id_key)
          filtered_json(id_key)&.to_json || ActiveSupport::ParameterFilter::FILTERED
        end

        def filtered_command(data)
          data = data.merge("data" => filtered_json(data["data"]) || ActiveSupport::ParameterFilter::FILTERED) if data.key?("data")
          parameter_filter.filter(data)
        rescue StandardError
          ActiveSupport::ParameterFilter::FILTERED
        end

        def filtered_json(json)
          decoded = ActiveSupport::JSON.decode(json)
          parameter_filter.filter(decoded) if decoded.is_a?(Hash)
        rescue StandardError
          nil
        end

        def parameter_filter
          @parameter_filter ||= ActiveSupport::ParameterFilter.new(connection.config.filter_parameters)
        end
    end
  end
end
