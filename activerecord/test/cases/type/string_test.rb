require "cases/helper"

module ActiveRecord
  class StringTypeTest < ActiveRecord::TestCase
    test "string mutations are detected" do
      klass = Class.new(Base)
      klass.table_name = "authors"

      author = klass.create!(name: "Sean")
      assert_not author.changed?

      author.name << " Griffin"
      assert author.name_changed?

      author.save!
      author.reload

      assert_equal "Sean Griffin", author.name
      assert_not author.changed?
    end
  end
end
