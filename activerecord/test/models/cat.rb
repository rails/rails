class Cat < ActiveRecord::Base
  self.abstract_class = true

  enum gender: [:female, :male]

  scope :female, -> { where(gender: genders[:female]) }
  scope :male, -> { where(gender: genders[:male]) }

  default_scope -> { where(is_vegetarian: false) }
end

class Lion < Cat
end
