# frozen_string_literal: true

module Sharded
  class Tag < ActiveRecord::Base
    self.table_name = :sharded_tags
    query_constraints :blog_id, :id

    has_many :blog_post_tags
    has_many :blog_posts, through: :blog_post_tags
  end
end
