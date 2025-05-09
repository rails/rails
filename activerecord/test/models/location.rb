# frozen_string_literal: true

class Location < ActiveRecord::Base; end

class City < Location
  belongs_to :county, foreign_key: :parent_id
  has_one :state, through: :county

  has_many :people
end

class County < Location
  belongs_to :state, foreign_key: :parent_id

  has_many :cities, foreign_key: :parent_id
  has_many :people, through: :cities
end

class State < Location
  has_many :counties, foreign_key: :parent_id
  has_many :cities, through: :counties
  has_many :people, through: :cities
end
