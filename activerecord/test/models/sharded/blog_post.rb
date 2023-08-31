# frozen_string_literal: true

module Sharded
  class BlogPost < ActiveRecord::Base
    self.table_name = :sharded_blog_posts
    query_constraints :blog_id, :id

    belongs_to :blog
    has_many :comments
    has_many :delete_comments, class_name: "Sharded::Comment", dependent: :delete_all

    has_many :blog_post_tags
    has_many :tags, through: :blog_post_tags
  end
end
