# frozen_string_literal: true

module Sharded
  # copy of the original `BlogPost` class, but with a different `query_constraints`
  class BlogPostWithRevision < ActiveRecord::Base
    self.table_name = :sharded_blog_posts
    query_constraints :blog_id, :revision, :id

    has_many :comments, foreign_key: :blog_post_id, query_constraints: :blog_id
  end
end
