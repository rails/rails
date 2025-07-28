# frozen_string_literal: true

module Cpk
  class Post < ActiveRecord::Base
    self.table_name = :cpk_posts
    has_many :comments, class_name: "Cpk::Comment", foreign_key: %i[commentable_title commentable_author], as: :commentable
    has_many :posts_tags, class_name: "Cpk::PostsTag", foreign_key: %i[post_title post_author]
    has_many :tags, through: :posts_tags, class_name: "Cpk::Tag"
  end
end
