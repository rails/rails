# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Post < ActiveRecord::Base
  belongs_to :author

  has_many :comments, class_name: "DATS::Comment", dependent: :destroy
  has_many :deprecated_comments, class_name: "DATS::Comment", dependent: :destroy, deprecated: true

  has_many :author_favorites, through: :author, class_name: "DATS::AuthorFavorite", source: :deprecated_author_favorites
end
