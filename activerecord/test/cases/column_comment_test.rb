# frozen_string_literal: true

require "cases/helper"

if ActiveRecord::Base.connection.supports_comments?
  class ColumnCommentTest < ActiveRecord::TestCase
    class ModelWithComment < ActiveRecord::Base
      self.table_name = "model_with_comments"
    end

    setup do
      @connection = ActiveRecord::Base.connection

      @connection.create_table("model_with_comments", force: true) do |t|
        t.string "column_with_comment", comment: "This column has a comment"
        t.string "column_with_no_comment"
      end
    end

    teardown do
      @connection.drop_table "model_with_comments", if_exists: true
    end

    test "returns column comment when column_name is valid and column has comment" do
      comment = ModelWithComment.column_comment("column_with_comment")
      assert_equal "This column has a comment", comment
    end

    test "returns nil when column_name is valid but column has no comment" do
      assert_nil ModelWithComment.column_comment("column_with_no_comment")
    end

    test "raises error when column_name is invalid" do
      assert_raises(RuntimeError) { ModelWithComment.column_comment("invalid") }
    end
  end
end
