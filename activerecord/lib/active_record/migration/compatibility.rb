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

      V6_1 = Current

      class V6_0 < V6_1
      end

      class V5_2 < V6_0
        module TableDefinition
          def timestamps(**options)
            options[:precision] ||= nil
            super
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

        def create_table(table_name, **options)
          if block_given?
            super { |t| yield compatible_table_definition(t) }
          else
            super
          end
        end

        def change_table(table_name, **options)
          if block_given?
            super { |t| yield compatible_table_definition(t) }
          else
            super
          end
        end

        def create_join_table(table_1, table_2, **options)
          if block_given?
            super { |t| yield compatible_table_definition(t) }
          else
            super
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
            t
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
