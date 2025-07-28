# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Category < ActiveRecord::Base
  self.inheritance_column = nil

  has_and_belongs_to_many :posts, class_name: "DATS::Post"
  has_and_belongs_to_many :deprecated_posts, class_name: "DATS::Post", deprecated: true
end
