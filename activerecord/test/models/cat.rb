# frozen_string_literal: true

class Cat < ActiveRecord::Base
  self.abstract_class = true

  enum :gender, [:female, :male]

  default_scope -> { where(is_vegetarian: false) }
end

class Lion < Cat
end
