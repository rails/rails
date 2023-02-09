# frozen_string_literal: true

module Sharded
  class BlogPost < ActiveRecord::Base
    self.table_name = :sharded_blog_posts
    query_constraints :blog_id, :id

    belongs_to :blog
    has_many :comments, foreign_key: [:blog_id, :blog_post_id]
  end
end
