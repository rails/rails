# frozen_string_literal: true

class Node < ActiveRecord::Base
  belongs_to :tree, touch: true
  belongs_to :parent, class_name: "Node", touch: true, optional: true, counter_cache: "children_count"
  has_many   :children, class_name: "Node", foreign_key: :parent_id, dependent: :destroy
end
