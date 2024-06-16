# frozen_string_literal: true

class Element < ActiveRecord::Base
  belongs_to :parent, class_name: "Element", optional: true
  has_many :children, class_name: "Element", foreign_key: "parent_id"
end
