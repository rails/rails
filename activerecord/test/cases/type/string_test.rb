require 'cases/helper'

module ActiveRecord
  class StringTypeTest < ActiveRecord::TestCase
    test "type casting" do
      type = Type::String.new
      assert_equal "t", type.cast(true)
      assert_equal "f", type.cast(false)
      assert_equal "123", type.cast(123)
    end

    test "values are duped coming out" do
      s = "foo"
      type = Type::String.new
      assert_not_same s, type.cast(s)
      assert_not_same s, type.deserialize(s)
    end

    test "string mutations are detected" do
      klass = Class.new(Base)
      klass.table_name = 'authors'

      author = klass.create!(name: 'Sean')
      assert_not author.changed?

      author.name << ' Griffin'
      assert author.name_changed?

      author.save!
      author.reload

      assert_equal 'Sean Griffin', author.name
      assert_not author.changed?
    end
  end
end
