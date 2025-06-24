# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      # = Active Record SQLite3 Adapter \Table Definition
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def change_column(column_name, type, **options)
          name = column_name.to_s
          @columns_hash[name] = nil
          column(name, type, **options)
        end

        def references(*args, **options)
          super(*args, type: :integer, **options)
        end
        alias :belongs_to :references

        def new_column_definition(name, type, **options) # :nodoc:
          case type
          when :virtual
            type = options[:type]
          end

          super
        end

        private
          def integer_like_primary_key_type(type, options)
            :primary_key
          end

          def valid_column_definition_options
            super + [:as, :type, :stored]
          end
      end
    end
  end
end
