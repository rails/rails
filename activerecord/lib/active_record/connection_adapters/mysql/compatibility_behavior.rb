# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module CompatibilityBehavior # :nodoc: all
        Base = ActiveRecord::Migration::CompatibilityBehavior
        extend Base::Resolver

        class V7_0 < Base
          def change_column(table_name, column_name, type, **options)
            options[:collation] ||= :no_collation
            super
          end
        end

        class V6_1 < V7_0
        end

        class V6_0 < V6_1
        end

        class V5_2 < V6_0
        end

        class V5_1 < V5_2
          def create_table(table_name, **options)
            options[:options] = "ENGINE=InnoDB" unless options.key?(:options)
            super
          end
        end

        class V5_0 < V5_1
          # The framework V5_0 applies default: nil to integer/bigint ids and
          # runs before this behavior, so MySQL's bigint-without-default is
          # restored by dropping the injected default back out. The marker
          # keeps a user-written `default: nil` untouched.
          def create_table(table_name, **options)
            if options.delete(:_compat_injected_default) && options[:id] == :bigint
              options.delete(:default)
            end
            super
          end
        end
      end
    end
  end
end
