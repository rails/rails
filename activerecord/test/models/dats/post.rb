# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Post < ActiveRecord::Base
  self.inheritance_column = nil

  belongs_to :author

  has_many :comments, class_name: "DATS::Comment"
  has_many :deprecated_comments, class_name: "DATS::Comment", deprecated: true

  has_many :author_favorites, through: :author, class_name: "DATS::AuthorFavorite", source: :deprecated_author_favorites

  has_one :comment, class_name: "DATS::Comment"
  has_one :deprecated_comment, class_name: "DATS::Comment", deprecated: true
  has_one :author_favorite, through: :author, class_name: "DATS::AuthorFavorite", source: :deprecated_author_favorite
end
