# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module MigrationCompatibility # :nodoc: all
        extend ActiveRecord::Migration::Compatibility::Versioned

        module V6_0
          def add_reference(table_name, ref_name, **options)
            options[:type] = :integer
            super
          end
          alias :add_belongs_to :add_reference
        end
      end
    end
  end
end
