# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/pet"
require "models/toy"

class DeleteAllTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :pets, :toys

  def test_destroy_all
    davids = Author.where(name: "David")

    # Force load
    assert_equal [authors(:david)], davids.to_a
    assert_predicate davids, :loaded?

    assert_difference("Author.count", -1) do
      destroyed = davids.destroy_all
      assert_equal [authors(:david)], destroyed
      assert_predicate destroyed.first, :frozen?
    end

    assert_equal [], davids.to_a
    assert_predicate davids, :loaded?
  end

  def test_delete_all
    davids = Author.where(name: "David")

    assert_difference("Author.count", -1) { davids.delete_all }
    assert_not_predicate davids, :loaded?
  end

  def test_delete_all_with_index_hint
    davids = Author.where(name: "David").from("#{Author.quoted_table_name} /*! USE INDEX (PRIMARY) */")

    assert_difference("Author.count", -1) { davids.delete_all }
    assert_not_predicate davids, :loaded?
  end

  def test_delete_all_loaded
    davids = Author.where(name: "David")

    # Force load
    assert_equal [authors(:david)], davids.to_a
    assert_predicate davids, :loaded?

    assert_difference("Author.count", -1) { davids.delete_all }

    assert_equal [], davids.to_a
    assert_predicate davids, :loaded?
  end

  def test_delete_all_with_unpermitted_relation_raises_error
    assert_raises(ActiveRecord::ActiveRecordError) { Author.distinct.delete_all }
    assert_raises(ActiveRecord::ActiveRecordError) { Author.group(:name).delete_all }
    assert_raises(ActiveRecord::ActiveRecordError) { Author.having("SUM(id) < 3").delete_all }
  end

  def test_delete_all_with_joins_and_where_part_is_hash
    pets = Pet.joins(:toys).where(toys: { name: "Bone" })

    assert_equal true, pets.exists?
    sqls = capture_sql do
      assert_equal pets.count, pets.delete_all
    end

    if current_adapter?(:Mysql2Adapter)
      assert_no_match %r/SELECT DISTINCT #{Regexp.escape(Pet.connection.quote_table_name("pets.pet_id"))}/, sqls.last
    else
      assert_match %r/SELECT #{Regexp.escape(Pet.connection.quote_table_name("pets.pet_id"))}/, sqls.last
    end
  end

  def test_delete_all_with_joins_and_where_part_is_not_hash
    pets = Pet.joins(:toys).where("toys.name = ?", "Bone")

    assert_equal true, pets.exists?
    assert_equal pets.count, pets.delete_all
  end

  def test_delete_all_with_left_joins
    pets = Pet.left_joins(:toys).where(toys: { name: "Bone" })

    assert_equal true, pets.exists?
    assert_equal pets.count, pets.delete_all
  end

  def test_delete_all_with_includes
    pets = Pet.includes(:toys).where(toys: { name: "Bone" })

    assert_equal true, pets.exists?
    assert_equal pets.count, pets.delete_all
  end

  def test_delete_all_with_order_and_limit_deletes_subset_only
    author = authors(:david)
    limited_posts = Post.where(author: author).order(:id).limit(1)
    assert_equal 1, limited_posts.size
    assert_equal 2, limited_posts.limit(2).size
    assert_equal 1, limited_posts.delete_all
    assert_raise(ActiveRecord::RecordNotFound) { posts(:welcome) }
    assert posts(:thinking)
  end

  def test_delete_all_with_order_and_limit_and_offset_deletes_subset_only
    author = authors(:david)
    limited_posts = Post.where(author: author).order(:id).limit(1).offset(1)
    assert_equal 1, limited_posts.size
    assert_equal 2, limited_posts.limit(2).size
    assert_equal 1, limited_posts.delete_all
    assert_raise(ActiveRecord::RecordNotFound) { posts(:thinking) }
    assert posts(:welcome)
  end
end
