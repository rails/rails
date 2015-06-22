module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition

        attr_reader :virtual

        def initialize(types, name, temporary, virtual, options, as = nil)
          super(types, name, temporary, options, as)
          @virtual = virtual
        end

      end
    end
  end
end