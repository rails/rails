# frozen_string_literal: true

module Cpk
  class Car < ActiveRecord::Base
    self.table_name = :cpk_cars

    has_many :car_reviews, foreign_key: [:car_make, :car_model]
  end
end
