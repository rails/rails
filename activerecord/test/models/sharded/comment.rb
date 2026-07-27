# frozen_string_literal: true

module Sharded
  class Comment < ActiveRecord::Base
    self.table_name = :sharded_comments
    query_constraints :blog_id, :id

    belongs_to :blog_post
    belongs_to :blog_post_by_id, class_name: "Sharded::BlogPost", foreign_key: :blog_post_id, primary_key: :id
    belongs_to :blog_post_with_inverse,
      class_name: "Sharded::BlogPost",
      foreign_key: :blog_post_id,
      query_constraints: :blog_id,
      inverse_of: :comments_with_inverse
    belongs_to :blog_post_with_decoupled_qc, class_name: "Sharded::BlogPost", foreign_key: :blog_post_id, query_constraints: :blog_id
    has_one :blog_through_post_with_decoupled_qc, through: :blog_post_with_decoupled_qc, source: :blog
    belongs_to :blog_post_with_fk_in_qc,
      class_name: "Sharded::BlogPost",
      foreign_key: :blog_post_id,
      query_constraints: [:blog_id, :blog_post_id]
    belongs_to :blog
  end

  class CompositePrimaryKeyComment < ActiveRecord::Base
    self.table_name = :sharded_comments
    self.primary_key = [:blog_id, :id]

    belongs_to :blog_post,
      class_name: "Sharded::BlogPost",
      foreign_key: [:blog_id, :blog_post_id]
  end
end
