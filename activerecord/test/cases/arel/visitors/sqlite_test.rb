# frozen_string_literal: true

require_relative '../helper'

module Arel
  module Visitors
    class SqliteTest < Arel::Spec
      before do
        @visitor = SQLite.new Table.engine.connection
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it 'defaults limit to -1' do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        sql = @visitor.accept(stmt, Collectors::SQLString.new).value
        _(sql).must_be_like 'SELECT LIMIT -1 OFFSET 1'
      end

      it 'does not support locking' do
        node = Nodes::Lock.new(Arel.sql('FOR UPDATE'))
        assert_equal '', @visitor.accept(node, Collectors::SQLString.new).value
      end

      it 'does not support boolean' do
        node = Nodes::True.new()
        assert_equal '1', @visitor.accept(node, Collectors::SQLString.new).value
        node = Nodes::False.new()
        assert_equal '0', @visitor.accept(node, Collectors::SQLString.new).value
      end

      describe 'Nodes::IsNotDistinctFrom' do
        it 'should construct a valid generic SQL statement' do
          test = Table.new(:users)[:name].is_not_distinct_from 'Aaron Patterson'
          _(compile(test)).must_be_like %{
            "users"."name" IS 'Aaron Patterson'
          }
        end

        it 'should handle column names on both sides' do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" IS "users"."last_name"
          }
        end

        it 'should handle nil' do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NULL }
        end
      end

      describe 'Nodes::IsDistinctFrom' do
        it 'should handle column names on both sides' do
          test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NOT "users"."last_name"
          }
        end

        it 'should handle nil' do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NOT NULL }
        end
      end
    end
  end
end
