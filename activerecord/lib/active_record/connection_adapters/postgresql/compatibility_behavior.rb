# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module CompatibilityBehavior # :nodoc: all
        extend Migration::CompatibilityBehavior::Resolver

        class V7_0 < Migration::CompatibilityBehavior
          def disable_extension(name, **options)
            options[:force] = :cascade unless options.key?(:force)
            super
          end

          def add_foreign_key(from_table, to_table, **options)
            options[:deferrable] = :immediate if options[:deferrable] == true
            super
          end
        end

        # For Rails <= 6.1, :datetime was aliased to :timestamp on PostgreSQL;
        # from Rails 7 onwards it resolves to whatever
        # `PostgreSQLAdapter.datetime_type` is set to.
        class V6_1 < V7_0
          def add_column(table_name, column_name, type, **options)
            type = :timestamp if type.to_sym == :datetime
            super
          end

          def change_column(table_name, column_name, type, **options)
            type = :timestamp if type.to_sym == :datetime
            super
          end

          module TableDefinition
            def new_column_definition(name, type, **options)
              type = :timestamp if type.to_sym == :datetime
              super
            end
          end
        end

        # Runs change_column with the type only, then applies :default /
        # :null / :comment separately.
        class V5_1 < V6_1
          def change_column(table_name, column_name, type, **options)
            super(table_name, column_name, type, **options.except(:default, :null, :comment))
            table_name = migration.proper_table_name(table_name, migration.table_name_options) unless connection.respond_to?(:revert)
            connection.change_column_default(table_name, column_name, options[:default]) if options.key?(:default)
            connection.change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
            connection.change_column_comment(table_name, column_name, options[:comment]) if options.key?(:comment)
          end
        end

        class V5_0 < V5_1
          def create_table(table_name, **options)
            if options[:id] == :uuid && !options.key?(:default)
              options[:default] = "uuid_generate_v4()"
            end
            super
          end
        end
      end
    end
  end
end
