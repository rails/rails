# frozen_string_literal: true

class Parcel < ActiveRecord::Base
  has_many :parcel_items
  belongs_to :buyer, inverse_of: :placed_parcels
end
