# frozen_string_literal: true

module Sharded
  class BlogPostTag < ActiveRecord::Base
    self.table_name = :sharded_blog_posts_tags

    belongs_to :blog_post, query_constraints: [:blog_id, :blog_post_id]
    belongs_to :tag, query_constraints: [:blog_id, :tag_id]
  end
end
