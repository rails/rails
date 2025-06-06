# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Author < ActiveRecord::Base
  has_many :posts, class_name: "DATS::Post", dependent: :destroy
  has_many :deprecated_posts, class_name: "DATS::Post", dependent: :destroy, deprecated: true

  has_many :comments, through: :posts, class_name: "DATS::Comment"

  has_many :deprecated_has_many, through: :posts, class_name: "DATS::Comment", source: :comments, deprecated: true
  has_many :deprecated_through, through: :deprecated_posts, class_name: "DATS::Comment", source: :comments
  has_many :deprecated_source, through: :posts, class_name: "DATS::Comment", source: :deprecated_comments
  has_many :deprecated_all, through: :deprecated_posts, class_name: "DATS::Comment", source: :deprecated_comments, deprecated: true

  has_many :author_favorites, class_name: "DATS::AuthorFavorite"
  has_many :deprecated_author_favorites, class_name: "DATS::AuthorFavorite", deprecated: true
  has_many :deprecated_nested, through: :posts, class_name: "DATS::AuthorFavorite", source: :author_favorites
end
