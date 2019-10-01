# frozen_string_literal: true

require "uri"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification # :nodoc:
      attr_reader :name, :db_config

      def initialize(name, db_config)
        @name, @db_config = name, db_config
      end
    end
  end
end
