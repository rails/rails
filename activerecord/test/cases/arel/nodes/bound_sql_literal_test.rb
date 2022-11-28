# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class BoundSqlLiteralTest < Arel::Spec
      describe "Arel with bind params" do
        it "works with Array binds" do
          result = Post.where(Arel.sql("x = ?", [1]))
          
          assert_equal result.to_sql, "SELECT \"posts\".* FROM \"posts\" WHERE x = 1"
        end

        it "works with Hash binds" do
          result = Post.where(Arel.sql("x = :value_of_x", nil, **{ value_of_x: 1 }))
          
          assert_equal result.to_sql, "SELECT \"posts\".* FROM \"posts\" WHERE x = 1"
        end

        it "works with Array & Hash binds" do
          result = Post.where(Arel.sql("x = :value_of_x AND y = ?", [2], **{ value_of_x: 1 }))
          
          assert_equal result.to_sql, "SELECT \"posts\".* FROM \"posts\" WHERE x = 1 AND y = 2"
        end
      end
    end
  end
end
