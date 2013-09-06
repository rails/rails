class AbstractItem < ApplicationModel
  self.abstract_class = true
  has_one :tagging, :as => :taggable
end

class Item < AbstractItem
end
