# frozen_string_literal: true

module Arel
  module TreeManagerBehavior
    extend ActiveSupport::Concern

    class MyEngine
      class << self
        def type_caster; end

        def with_connection
          yield MyConnection.new
        end
      end

      class MyConnection
        def quote_table_name(name)
          "@#{name}@"
        end

        def visitor
          Arel::Visitors::ToSql.new(self)
        end
      end
    end

    included do
      describe "to_sql" do
        it "uses given table's engine if available" do
          table = Table.new(:users, klass: MyEngine)
          manager = build_manager(table)

          assert_includes manager.to_sql, "@users@"
        end
      end
    end
  end
end
