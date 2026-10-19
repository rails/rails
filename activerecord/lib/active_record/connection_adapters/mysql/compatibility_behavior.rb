# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module CompatibilityBehavior # :nodoc: all
        extend Migration::CompatibilityBehavior::Resolver

        class V7_0 < Migration::CompatibilityBehavior
          def change_column(table_name, column_name, type, **options)
            options[:collation] ||= :no_collation
            super
          end
        end

        class V5_1 < V7_0
          def create_table(table_name, **options)
            super(table_name, options: "ENGINE=InnoDB", **options)
          end
        end
      end
    end
  end
end
