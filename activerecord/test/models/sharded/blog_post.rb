# frozen_string_literal: true

module Sharded
  class BlogPost < ActiveRecord::Base
    self.table_name = :sharded_blog_posts
    query_constraints :blog_id, :id

    belongs_to :parent, polymorphic: true
    belongs_to :blog
    has_many :comments
    has_many :delete_comments, class_name: "Sharded::Comment", dependent: :delete_all
    has_many :children, class_name: name, as: :parent

    has_many :blog_post_tags
    has_many :tags, through: :blog_post_tags
    has_many :blog_post_tags_with_decoupled_qc,
      class_name: "Sharded::BlogPostTag",
      foreign_key: :blog_post_id,
      query_constraints: :blog_id
    has_many :tags_with_decoupled_qc,
      through: :blog_post_tags_with_decoupled_qc,
      source: :tag_with_decoupled_qc
    has_many :tags_with_decoupled_qc_without_joins,
      through: :blog_post_tags_with_decoupled_qc,
      source: :tag_with_decoupled_qc,
      disable_joins: true

    has_and_belongs_to_many :tags_with_composite_fk,
      class_name: "Sharded::Tag",
      join_table: "sharded_blog_posts_tags",
      foreign_key: [:blog_id, :blog_post_id],
      association_foreign_key: [:blog_id, :tag_id]

    has_many :comments_with_query_constraints,
      class_name: "Sharded::Comment",
      foreign_key: :blog_post_id,
      query_constraints: :blog_id

    has_many :comments_with_inverse,
      class_name: "Sharded::Comment",
      inverse_of: :blog_post_with_inverse

    belongs_to :featured_comment,
      class_name: "Sharded::Comment",
      foreign_key: :featured_comment_id,
      query_constraints: [:blog_id, { id: :blog_post_id }]
    belongs_to :featured_comment_bare_hash_qc,
      class_name: "Sharded::Comment",
      foreign_key: :featured_comment_id,
      query_constraints: { blog_id: :blog_id }
  end
end
