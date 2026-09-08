# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Author < ActiveRecord::Base
  has_many :posts, class_name: "DATS::Post", dependent: :destroy
  has_many :deprecated_posts, class_name: "DATS::Post", dependent: :destroy, deprecated: true

  has_many :comments, through: :posts, class_name: "DATS::Comment", source: :comments

  has_many :deprecated_has_many_through, through: :posts, class_name: "DATS::Comment", source: :comments, deprecated: true
  has_many :deprecated_through, through: :deprecated_posts, class_name: "DATS::Comment", source: :comments
  has_many :deprecated_source, through: :posts, class_name: "DATS::Comment", source: :deprecated_comments
  has_many :deprecated_all, through: :deprecated_posts, class_name: "DATS::Comment", source: :deprecated_comments, deprecated: true

  has_many :author_favorites, class_name: "DATS::AuthorFavorite"
  has_many :deprecated_author_favorites, class_name: "DATS::AuthorFavorite", deprecated: true
  has_many :deprecated_nested, through: :posts, class_name: "DATS::AuthorFavorite", source: :author_favorites

  has_one :post
  has_one :deprecated_post, class_name: "DATS::Post", deprecated: true
  has_one :comment, through: :post, class_name: "DATS::Comment", source: :comment

  has_one :deprecated_has_one_through, through: :post, class_name: "DATS::Comment", source: :comment, deprecated: true
  has_one :deprecated_through1, through: :deprecated_post, class_name: "DATS::Comment", source: :comment
  has_one :deprecated_source1, through: :post, class_name: "DATS::Comment", source: :deprecated_comment
  has_one :deprecated_all1, through: :deprecated_post, class_name: "DATS::Comment", source: :deprecated_comment, deprecated: true

  has_one :author_favorite, class_name: "DATS::AuthorFavorite"
  has_one :deprecated_author_favorite, class_name: "DATS::AuthorFavorite", deprecated: true
  has_one :deprecated_nested1, through: :post, class_name: "DATS::AuthorFavorite", source: :author_favorite
end
