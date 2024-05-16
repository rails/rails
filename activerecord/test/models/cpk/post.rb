# frozen_string_literal: true

module Cpk
  class Post < ActiveRecord::Base
    self.table_name = :cpk_posts
    has_many :comments, class_name: "Cpk::Comment", foreign_key: %i[commentable_title commentable_author], as: :commentable
  end
end
