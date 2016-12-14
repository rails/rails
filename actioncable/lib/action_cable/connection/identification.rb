require "set"

module ActionCable
  module Connection
    module Identification
      extend ActiveSupport::Concern

      included do
        class_attribute :identifiers
        self.identifiers = Set.new
      end

      class_methods do
        # Mark a key as being a connection identifier index that can then be used to find the specific connection again later.
        # Common identifiers are current_user and current_account, but could be anything, really.
        #
        # Note that anything marked as an identifier will automatically create a delegate by the same name on any
        # channel instances created off the connection.
        def identified_by(*identifiers)
          Array(identifiers).each { |identifier| attr_accessor identifier }
          self.identifiers += identifiers
        end
      end

      # Return a single connection identifier that combines the value of all the registered identifiers into a single gid.
      def connection_identifier
        unless defined? @connection_identifier
          @connection_identifier = connection_gid identifiers.map { |id| instance_variable_get("@#{id}") }.compact
        end

        @connection_identifier
      end

      private
        def connection_gid(ids)
          ids.map do |o|
            if o.respond_to? :to_gid_param
              o.to_gid_param
            else
              o.to_s
            end
          end.sort.join(":")
        end
    end
  end
end
