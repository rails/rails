# frozen_string_literal: true

module Cpk
  class CarReview < ActiveRecord::Base
    self.table_name = :cpk_car_reviews

    belongs_to :car, foreign_key: [:car_make, :car_model]
  end
end
