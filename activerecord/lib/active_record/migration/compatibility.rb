# frozen_string_literal: true

module ActiveRecord
  class Migration
    module Compatibility # :nodoc: all
      def self.find(version)
        version = version.to_s
        name = "V#{version.tr('.', '_')}"
        unless const_defined?(name)
          versions = constants.grep(/\AV[0-9_]+\z/).map { |s| s.to_s.delete("V").tr("_", ".").inspect }
          raise ArgumentError, "Unknown migration version #{version.inspect}; expected one of #{versions.sort.join(', ')}"
        end
        const_get(name)
      end

      # This file exists to ensure that old migrations run the same way they did before a Rails upgrade.
      # e.g. if you write a migration on Rails 6.1, then upgrade to Rails 7, the migration should do the same thing to your
      # database as it did when you were running Rails 6.1
      #
      # "Current" is an alias for `ActiveRecord::Migration`, it represents the current Rails version.
      # New migration functionality that will never be backward compatible should be added directly to `ActiveRecord::Migration`.
      #
      # There are classes for each prior Rails version. Each class descends from the *next* Rails version, so:
      # 6.1 < 7.0
      # 5.2 < 6.0 < 6.1 < 7.0
      #
      # If you are introducing new migration functionality that should only apply from Rails 7 onward, then you should
      # find the class that immediately precedes it (6.1), and override the relevant migration methods to undo your changes.
      #
      # For example, Rails 6 added a default value for the `precision` option on datetime columns. So in this file, the `V5_2`
      # class sets the value of `precision` to `nil` if it's not explicitly provided. This way, the default value will not apply
      # for migrations written for 5.2, but will for migrations written for 6.0.
      V7_0 = Current

      class V6_1 < V7_0
        class PostgreSQLCompat
          def self.compatible_timestamp_type(type, connection)
            if connection.adapter_name == "PostgreSQL"
              # For Rails <= 6.1, :datetime was aliased to :timestamp
              # See: https://github.com/rails/rails/blob/v6.1.3.2/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L108
              # From Rails 7 onwards, you can define what :datetime resolves to (the default is still :timestamp)
              # See `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type`
              type.to_sym == :datetime ? :timestamp : type
            else
              type
            end
          end
        end

        def add_column(table_name, column_name, type, **options)
          if type == :datetime
            options[:precision] ||= nil
          end

          type = PostgreSQLCompat.compatible_timestamp_type(type, connection)
          super
        end

        def change_column(table_name, column_name, type, **options)
          if type == :datetime
            options[:precision] ||= nil
          end

          type = PostgreSQLCompat.compatible_timestamp_type(type, connection)
          super
        end

        module TableDefinition
          def new_column_definition(name, type, **options)
            type = PostgreSQLCompat.compatible_timestamp_type(type, @conn)
            super
          end

          def change(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end

          def column(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end
        end

        private
          def compatible_table_definition(t)
            class << t
              prepend TableDefinition
            end
            super
          end
      end

      class V6_0 < V6_1
        class ReferenceDefinition < ConnectionAdapters::ReferenceDefinition
          def index_options(table_name)
            as_options(index)
          end
        end

        module TableDefinition
          def references(*args, **options)
            options[:_uses_legacy_reference_index_name] = true
            super
          end
          alias :belongs_to :references

          def column(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end
        end

        def add_reference(table_name, ref_name, **options)
          if connection.adapter_name == "SQLite"
            options[:type] = :integer
          end

          options[:_uses_legacy_reference_index_name] = true
          super
        end
        alias :add_belongs_to :add_reference

        private
          def compatible_table_definition(t)
            class << t
              prepend TableDefinition
            end
            super
          end
      end

      class V5_2 < V6_0
        module TableDefinition
          def timestamps(**options)
            options[:precision] ||= nil
            super
          end

          def column(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end

          private
            def raise_on_if_exist_options(options)
            end

            def raise_on_duplicate_column(name)
            end
        end

        module CommandRecorder
          def invert_transaction(args, &block)
            [:transaction, args, block]
          end

          def invert_change_column_comment(args)
            [:change_column_comment, args]
          end

          def invert_change_table_comment(args)
            [:change_table_comment, args]
          end
        end

        def add_timestamps(table_name, **options)
          options[:precision] ||= nil
          super
        end

        private
          def compatible_table_definition(t)
            class << t
              prepend TableDefinition
            end
            super
          end

          def command_recorder
            recorder = super
            class << recorder
              prepend CommandRecorder
            end
            recorder
          end
      end

      class V5_1 < V5_2
        def change_column(table_name, column_name, type, **options)
          if connection.adapter_name == "PostgreSQL"
            super(table_name, column_name, type, **options.except(:default, :null, :comment))
            connection.change_column_default(table_name, column_name, options[:default]) if options.key?(:default)
            connection.change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
            connection.change_column_comment(table_name, column_name, options[:comment]) if options.key?(:comment)
          else
            super
          end
        end

        def create_table(table_name, **options)
          if connection.adapter_name == "Mysql2"
            super(table_name, options: "ENGINE=InnoDB", **options)
          else
            super
          end
        end
      end

      class V5_0 < V5_1
        module TableDefinition
          def primary_key(name, type = :primary_key, **options)
            type = :integer if type == :primary_key
            super
          end

          def references(*args, **options)
            super(*args, type: :integer, **options)
          end
          alias :belongs_to :references
        end

        def create_table(table_name, **options)
          if connection.adapter_name == "PostgreSQL"
            if options[:id] == :uuid && !options.key?(:default)
              options[:default] = "uuid_generate_v4()"
            end
          end

          unless connection.adapter_name == "Mysql2" && options[:id] == :bigint
            if [:integer, :bigint].include?(options[:id]) && !options.key?(:default)
              options[:default] = nil
            end
          end

          # Since 5.1 PostgreSQL adapter uses bigserial type for primary
          # keys by default and MySQL uses bigint. This compat layer makes old migrations utilize
          # serial/int type instead -- the way it used to work before 5.1.
          unless options.key?(:id)
            options[:id] = :integer
          end

          super
        end

        def create_join_table(table_1, table_2, column_options: {}, **options)
          column_options.reverse_merge!(type: :integer)
          super
        end

        def add_column(table_name, column_name, type, **options)
          if type == :primary_key
            type = :integer
            options[:primary_key] = true
          elsif type == :datetime
            options[:precision] ||= nil
          end
          super
        end

        def add_reference(table_name, ref_name, **options)
          super(table_name, ref_name, type: :integer, **options)
        end
        alias :add_belongs_to :add_reference

        private
          def compatible_table_definition(t)
            class << t
              prepend TableDefinition
            end
            super
          end
      end

      class V4_2 < V5_0
        module TableDefinition
          def references(*, **options)
            options[:index] ||= false
            super
          end
          alias :belongs_to :references

          def timestamps(**options)
            options[:null] = true if options[:null].nil?
            super
          end
        end

        def add_reference(table_name, ref_name, **options)
          options[:index] ||= false
          super
        end
        alias :add_belongs_to :add_reference

        def add_timestamps(table_name, **options)
          options[:null] = true if options[:null].nil?
          super
        end

        def index_exists?(table_name, column_name, **options)
          column_names = Array(column_name).map(&:to_s)
          options[:name] =
            if options[:name].present?
              options[:name].to_s
            else
              connection.index_name(table_name, column: column_names)
            end
          super
        end

        def remove_index(table_name, column_name = nil, **options)
          options[:name] = index_name_for_remove(table_name, column_name, options)
          super
        end

        private
          def compatible_table_definition(t)
            class << t
              prepend TableDefinition
            end
            super
          end

          def index_name_for_remove(table_name, column_name, options)
            index_name = connection.index_name(table_name, column_name || options)

            unless connection.index_name_exists?(table_name, index_name)
              if options.key?(:name)
                options_without_column = options.except(:column)
                index_name_without_column = connection.index_name(table_name, options_without_column)

                if connection.index_name_exists?(table_name, index_name_without_column)
                  return index_name_without_column
                end
              end

              raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
            end

            index_name
          end
      end
    end
  end
end
