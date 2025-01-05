# frozen_string_literal: true

class Aircraft < ActiveRecord::Base
  self.pluralize_table_names = false
  has_many :engines, foreign_key: "car_id"
  has_many :wheels, as: :wheelable

  self.table_alias = "a"
end
