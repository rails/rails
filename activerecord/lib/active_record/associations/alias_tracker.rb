require 'active_support/core_ext/string/conversions'

module ActiveRecord
  module Associations
    # Keeps track of table aliases for ActiveRecord::Associations::ClassMethods::JoinDependency and
    # ActiveRecord::Associations::ThroughAssociationScope
    class AliasTracker # :nodoc:
      attr_reader :aliases, :connection

      def self.empty(connection)
        new connection, Hash.new(0)
      end

      def self.create(connection, table_joins)
        if table_joins.empty?
          empty connection
        else
          aliases = Hash.new { |h,k|
            h[k] = initial_count_for(connection, k, table_joins)
          }
          new connection, aliases
        end
      end

      def self.initial_count_for(connection, name, table_joins)
        # quoted_name should be downcased as some database adapters (Oracle) return quoted name in uppercase
        quoted_name = connection.quote_table_name(name).downcase

        counts = table_joins.map do |join|
          if join.is_a?(Arel::Nodes::StringJoin)
            # Table names + table aliases
            join.left.downcase.scan(
              /join(?:\s+\w+)?\s+(\S+\s+)?#{quoted_name}\son/
            ).size
          else
            join.left.table_name == name ? 1 : 0
          end
        end

        counts.sum
      end

      # table_joins is an array of arel joins which might conflict with the aliases we assign here
      def initialize(connection, aliases)
        @aliases    = aliases
        @connection = connection
      end

      def aliased_table_for(table_name, aliased_name)
        table_alias = aliased_name_for(table_name, aliased_name)

        if table_alias == table_name
          Arel::Table.new(table_name)
        else
          Arel::Table.new(table_name).alias(table_alias)
        end
      end

      def aliased_name_for(table_name, aliased_name)
        if aliases[table_name].zero?
          # If it's zero, we can have our table_name
          aliases[table_name] = 1
          table_name
        else
          # Otherwise, we need to use an alias
          aliased_name = connection.table_alias_for(aliased_name)

          # Update the count
          aliases[aliased_name] += 1

          if aliases[aliased_name] > 1
            "#{truncate(aliased_name)}_#{aliases[aliased_name]}"
          else
            aliased_name
          end
        end
      end

      private

        def truncate(name)
          name.slice(0, connection.table_alias_length - 2)
        end
    end
  end
end
