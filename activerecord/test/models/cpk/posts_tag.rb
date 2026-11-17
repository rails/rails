# frozen_string_literal: true

module Cpk
  class PostsTag < ActiveRecord::Base
    self.table_name = :cpk_posts_tags

    belongs_to :post, class_name: "Cpk:Post", foreign_key: %i[post_title post_author]
    belongs_to :tag, class_name: "Cpk::Tag"
  end
end
