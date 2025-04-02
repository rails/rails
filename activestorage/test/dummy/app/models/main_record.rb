# frozen_string_literal: true

class MainRecord < ApplicationRecord
  if ENV["MULTI_DB"]
    self.abstract_class = true

    connects_to database: { writing: :main, reading: :main }
  end
end