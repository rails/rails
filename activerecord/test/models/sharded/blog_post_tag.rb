# frozen_string_literal: true

module Sharded
  class BlogPostTag < ActiveRecord::Base
    self.table_name = :sharded_blog_posts_tags
    query_constraints :blog_id, :id

    belongs_to :blog_post
    belongs_to :tag
    belongs_to :unconstrained_tag,
      class_name: "Sharded::UnconstrainedTag",
      primary_key: [:blog_id, :id],
      foreign_key: [:blog_id, :tag_id]
  end
end
