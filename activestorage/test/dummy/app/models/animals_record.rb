# frozen_string_literal: true

class AnimalsRecord < ApplicationRecord
  if ENV["MULTI_DB"]
    self.abstract_class = true

    connects_to database: { writing: :animals, reading: :animals }
  end
end