# frozen_string_literal: true

module Sharded
  class BlogPost < ActiveRecord::Base
    self.table_name = :sharded_blog_posts
    query_constraints :blog_id, :id

    belongs_to :blog
    has_many :comments, query_constraints: [:blog_id, :blog_post_id]

    has_many :blog_post_tags, query_constraints: [:blog_id, :blog_post_id]
    has_many :tags, through: :blog_post_tags
  end
end
