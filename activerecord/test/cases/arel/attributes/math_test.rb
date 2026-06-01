# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Attributes
    class MathTest < Arel::Test
      %i[* /].each do |math_operator|
        test "average should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            AVG("users"."id") #{math_operator} 2
          }, table[:id].average.public_send(math_operator, 2).to_sql
        end

        test "count should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            COUNT("users"."id") #{math_operator} 2
          }, table[:id].count.public_send(math_operator, 2).to_sql
        end

        test "maximum should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            MAX("users"."id") #{math_operator} 2
          }, table[:id].maximum.public_send(math_operator, 2).to_sql
        end

        test "minimum should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            MIN("users"."id") #{math_operator} 2
          }, table[:id].minimum.public_send(math_operator, 2).to_sql
        end

        test "attribute node should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            "users"."id" #{math_operator} 2
          }, table[:id].public_send(math_operator, 2).to_sql
        end
      end

      %i[+ - & | ^ << >>].each do |math_operator|
        test "average should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            (AVG("users"."id") #{math_operator} 2)
          }, table[:id].average.public_send(math_operator, 2).to_sql
        end

        test "count should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            (COUNT("users"."id") #{math_operator} 2)
          }, table[:id].count.public_send(math_operator, 2).to_sql
        end

        test "maximum should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            (MAX("users"."id") #{math_operator} 2)
          }, table[:id].maximum.public_send(math_operator, 2).to_sql
        end

        test "minimum should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            (MIN("users"."id") #{math_operator} 2)
          }, table[:id].minimum.public_send(math_operator, 2).to_sql
        end

        test "attribute node should be compatible with #{math_operator}" do
          table = Arel::Table.new :users
          assert_like %{
            ("users"."id" #{math_operator} 2)
          }, table[:id].public_send(math_operator, 2).to_sql
        end
      end
    end
  end
end
