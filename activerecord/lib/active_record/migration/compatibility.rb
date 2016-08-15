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

      module FourTwoShared
        module TableDefinition
          def references(*, **options)
            options[:index] ||= false
            super
          end
          alias :belongs_to :references

          def timestamps(*, **options)
            options[:null] = true if options[:null].nil?
            super
          end
        end

        def create_table(table_name, options = {})
          if block_given?
            super(table_name, options) do |t|
              class << t
                prepend TableDefinition
              end
              yield t
            end
          else
            super
          end
        end

        def change_table(table_name, options = {})
          if block_given?
            super(table_name, options) do |t|
              class << t
                prepend TableDefinition
              end
              yield t
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

        def add_timestamps(*, **options)
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

          def index_name_for_remove(table_name, options = {})
            index_name = index_name(table_name, options)

            unless index_name_exists?(table_name, index_name, true)
              if options.is_a?(Hash) && options.has_key?(:name)
                options_without_column = options.dup
                options_without_column.delete :column
                index_name_without_column = index_name(table_name, options_without_column)

                return index_name_without_column if index_name_exists?(table_name, index_name_without_column, false)
              end

              raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
            end

            index_name
          end
      end

      class V5_0 < V5_1
      end

      class V4_2 < V5_0
        # 4.2 is defined as a module because it needs to be shared with
        # Legacy. When the time comes, V5_0 should be defined straight
        # in its class.
        include FourTwoShared
      end

      module Legacy
        include FourTwoShared

        def migrate(*)
          ActiveSupport::Deprecation.warn \
            "Directly inheriting from ActiveRecord::Migration is deprecated. " \
            "Please specify the Rails release the migration was written for:\n" \
            "\n" \
            "  class #{self.class.name} < ActiveRecord::Migration[4.2]"
          super
        end
      end
    end
  end
end
