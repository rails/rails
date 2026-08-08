# frozen_string_literal: true

module Sharded
  class BlogPostTag < ActiveRecord::Base
    self.table_name = :sharded_blog_posts_tags
    query_constraints :blog_id, :id

    belongs_to :blog_post
    belongs_to :tag
    belongs_to :tag_with_decoupled_qc, class_name: "Sharded::Tag", foreign_key: :tag_id, query_constraints: :blog_id
  end
end
