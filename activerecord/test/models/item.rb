# frozen_string_literal: true

class AbstractItem < ActiveRecord::Base
  self.abstract_class = true
  has_one :tagging, as: :taggable
end

class Item < AbstractItem
end
