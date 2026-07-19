# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module CompatibilityBehavior # :nodoc: all
        Base = ActiveRecord::Migration::CompatibilityBehavior
        extend Base::Resolver

        class V6_0 < Base
          def add_reference(table_name, ref_name, **options)
            options[:type] = :integer
            super
          end
        end
      end
    end
  end
end
