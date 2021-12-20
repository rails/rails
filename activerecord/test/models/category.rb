# frozen_string_literal: true

class Category < ActiveRecord::Base
  has_and_belongs_to_many :posts
  has_and_belongs_to_many :special_posts, class_name: "Post"
  has_and_belongs_to_many :other_posts, class_name: "Post"
  has_and_belongs_to_many :posts_with_authors_sorted_by_author_id, -> { includes(:authors).order("authors.id") }, class_name: "Post"

  has_and_belongs_to_many :select_testing_posts,
                          -> { select "posts.*, 1 as correctness_marker" },
                          class_name: "Post",
                          foreign_key: "category_id",
                          association_foreign_key: "post_id"

  has_and_belongs_to_many :post_with_conditions,
                          -> { where title: "Yet Another Testing Title" },
                          class_name: "Post"

  has_and_belongs_to_many :posts_grouped_by_title, -> { group("title").select("title") }, class_name: "Post"

  def self.what_are_you
    "a category..."
  end

  has_many :categorizations
  has_many :special_categorizations
  has_many :post_comments, through: :posts, source: :comments
  has_many :ordered_post_comments, -> { order(id: :desc) }, through: :posts, source: :comments

  has_many :authors, through: :categorizations
  has_many :authors_with_select, -> { select "authors.*, categorizations.post_id" }, through: :categorizations, source: :author

  has_many :essays, primary_key: :name
  has_many :human_writers_of_typed_essays, -> { where(essays: { type: TypedEssay.name }) }, through: :essays, source: :writer, source_type: "Human", primary_key: :name

  scope :general, -> { where(name: "General") }

  # Should be delegated `ast` and `locked` to `arel`.
  def self.ast
    raise
  end

  def self.locked
    raise
  end
end

class SpecialCategory < Category
end
