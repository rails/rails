# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module MigrationCompatibility # :nodoc: all
        extend ActiveRecord::Migration::Compatibility::Versioned

        module V7_0
          def change_column(table_name, column_name, type, **options)
            options[:collation] ||= :no_collation
            super
          end
        end

        module V5_1
          def create_table(table_name, **options)
            options = { options: "ENGINE=InnoDB", **options }
            super(table_name, **options)
          end
        end

        module V5_0
          def create_table(table_name, **options)
            options[:_skip_pk_nil_default] = true if options[:id] == :bigint
            super
          end
        end
      end
    end
  end
end
