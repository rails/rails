# frozen_string_literal: true

class Rating < ActiveRecord::Base
  belongs_to :comment
  has_many :taggings, as: :taggable
  has_many :taggings_without_tag, -> { left_joins(:tag).where("tags.id": [nil, 0]) }, as: :taggable, class_name: "Tagging"
  has_many :taggings_with_no_tag, -> { joins("LEFT OUTER JOIN tags ON tags.id = taggings.tag_id").where("tags.id": nil) }, as: :taggable, class_name: "Tagging"
end
