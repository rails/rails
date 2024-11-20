# frozen_string_literal: true

module Sharded
  class Comment < ActiveRecord::Base
    self.table_name = :sharded_comments
    query_constraints :blog_id, :id

    belongs_to :blog_post
    belongs_to :blog_post_by_id, class_name: "Sharded::BlogPost", foreign_key: :blog_post_id, primary_key: :id
    belongs_to :blog
  end
end
