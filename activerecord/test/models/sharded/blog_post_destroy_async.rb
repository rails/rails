# frozen_string_literal: true

module Sharded
  class BlogPostDestroyAsync < ActiveRecord::Base
    self.table_name = :sharded_blog_posts
    query_constraints :blog_id, :id

    belongs_to :blog
    has_many :comments, dependent: :destroy_async, foreign_key: [:blog_id, :blog_post_id], class_name: "Sharded::CommentDestroyAsync"

    has_many :blog_post_tags, foreign_key: [:blog_id, :blog_post_id], class_name: "Sharded::BlogPostTag"
    has_many :tags, through: :blog_post_tags, dependent: :destroy_async, class_name: "Sharded::Tag"
  end
end
