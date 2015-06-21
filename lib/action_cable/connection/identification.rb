module ActionCable
  module Connection
    module Identification
      extend ActiveSupport::Concern

      included do
        class_attribute :identifiers
        self.identifiers = Set.new
      end

      class_methods do
        def identified_by(*identifiers)
          self.identifiers += identifiers
        end
      end

      def connection_identifier
        @connection_identifier ||= connection_gid identifiers.map { |id| instance_variable_get("@#{id}") }.compact
      end

      def connection_gid(ids)
        ids.map { |o| o.to_global_id.to_s }.sort.join(":")
      end
    end
  end
end
