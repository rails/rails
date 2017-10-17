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

      V5_1 = Current

      class V5_0 < V5_1
        module TableDefinition
          def references(*args, **options)
            super(*args, type: :integer, **options)
          end
          alias :belongs_to :references
        end

        def create_table(table_name, options = {})
          if adapter_name == "PostgreSQL"
            if options[:id] == :uuid && !options.key?(:default)
              options[:default] = "uuid_generate_v4()"
            end
          end

          unless adapter_name == "Mysql2" && options[:id] == :bigint
            if [:integer, :bigint].include?(options[:id]) && !options.key?(:default)
              options[:default] = nil
            end
          end

          # Since 5.1 Postgres adapter uses bigserial type for primary
          # keys by default and MySQL uses bigint. This compat layer makes old migrations utilize
          # serial/int type instead -- the way it used to work before 5.1.
          unless options.key?(:id)
            options[:id] = :integer
          end

          if block_given?
            super do |t|
              yield compatible_table_definition(t)
            end
          else
            super
          end
        end

        def change_table(table_name, options = {})
          if block_given?
            super do |t|
              yield compatible_table_definition(t)
            end
          else
            super
          end
        end

        def create_join_table(table_1, table_2, column_options: {}, **options)
          column_options.reverse_merge!(type: :integer)

          if block_given?
            super do |t|
              yield compatible_table_definition(t)
            end
          else
            super
          end
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
            t
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

        def create_table(table_name, options = {})
          if block_given?
            super do |t|
              yield compatible_table_definition(t)
            end
          else
            super
          end
        end

        def change_table(table_name, options = {})
          if block_given?
            super do |t|
              yield compatible_table_definition(t)
            end
          else
            super
          end
        end

        def add_reference(*, **options)
          options[:index] ||= false
          super
        end
        alias :add_belongs_to :add_reference

        def add_timestamps(_, **options)
          options[:null] = true if options[:null].nil?
          super
        end

        def index_exists?(table_name, column_name, options = {})
          column_names = Array(column_name).map(&:to_s)
          options[:name] =
            if options[:name].present?
              options[:name].to_s
            else
              index_name(table_name, column: column_names)
            end
          super
        end

        def remove_index(table_name, options = {})
          options = { column: options } unless options.is_a?(Hash)
          options[:name] = index_name_for_remove(table_name, options)
          super(table_name, options)
        end

        private
          def compatible_table_definition(t)
            class << t
              prepend TableDefinition
            end
            super
          end

          def index_name_for_remove(table_name, options = {})
            index_name = index_name(table_name, options)

            unless index_name_exists?(table_name, index_name)
              if options.is_a?(Hash) && options.has_key?(:name)
                options_without_column = options.dup
                options_without_column.delete :column
                index_name_without_column = index_name(table_name, options_without_column)

                return index_name_without_column if index_name_exists?(table_name, index_name_without_column)
              end

              raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
            end

            index_name
          end
      end
    end
  end
end
