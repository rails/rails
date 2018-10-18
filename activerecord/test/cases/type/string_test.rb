# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class StringTypeTest < ActiveRecord::TestCase
    test "string mutations are detected" do
      klass = Class.new(Base)
      klass.table_name = "authors"

      author = klass.create!(name: "Sean")
      assert_not_predicate author, :changed?

      author.name << " Griffin"
      assert_predicate author, :name_changed?

      author.save!
      author.reload

      assert_equal "Sean Griffin", author.name
      assert_not_predicate author, :changed?
    end
  end
end
