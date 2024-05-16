# frozen_string_literal: true

require "active_support/core_ext/string/conversions"

module ActiveRecord
  module Associations
    # Keeps track of table aliases for ActiveRecord::Associations::JoinDependency
    class AliasTracker # :nodoc:
      def self.create(pool, initial_table, joins, aliases = nil)
        pool.with_connection do |connection|
          if joins.empty?
            aliases ||= Hash.new(0)
          elsif aliases
            default_proc = aliases.default_proc || proc { 0 }
            aliases.default_proc = proc { |h, k|
              h[k] = initial_count_for(connection, k, joins) + default_proc.call(h, k)
            }
          else
            aliases = Hash.new { |h, k|
              h[k] = initial_count_for(connection, k, joins)
            }
          end
          aliases[initial_table] = 1
          new(connection.table_alias_length, aliases)
        end
      end

      def self.initial_count_for(connection, name, table_joins)
        quoted_name = nil

        counts = table_joins.map do |join|
          if join.is_a?(Arel::Nodes::StringJoin)
            # quoted_name should be case ignored as some database adapters (Oracle) return quoted name in uppercase
            quoted_name ||= connection.quote_table_name(name)

            # Table names + table aliases
            join.left.scan(
              /JOIN(?:\s+\w+)?\s+(?:\S+\s+)?(?:#{quoted_name}|#{name})\sON/i
            ).size
          elsif join.is_a?(Arel::Nodes::Join)
            join.left.name == name ? 1 : 0
          else
            raise ArgumentError, "joins list should be initialized by list of Arel::Nodes::Join"
          end
        end

        counts.sum
      end

      # table_joins is an array of arel joins which might conflict with the aliases we assign here
      def initialize(table_alias_length, aliases)
        @aliases = aliases
        @table_alias_length = table_alias_length
      end

      def aliased_table_for(arel_table, table_name = nil)
        table_name ||= arel_table.name

        if aliases[table_name] == 0
          # If it's zero, we can have our table_name
          aliases[table_name] = 1
          arel_table = arel_table.alias(table_name) if arel_table.name != table_name
        else
          # Otherwise, we need to use an alias
          aliased_name = table_alias_for(yield)

          # Update the count
          count = aliases[aliased_name] += 1

          aliased_name = "#{truncate(aliased_name)}_#{count}" if count > 1

          arel_table = arel_table.alias(aliased_name)
        end

        arel_table
      end

      attr_reader :aliases

      private
        def table_alias_for(table_name)
          table_name[0...@table_alias_length].tr(".", "_")
        end

        def truncate(name)
          name.slice(0, @table_alias_length - 2)
        end
    end
  end
end
