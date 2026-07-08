# frozen_string_literal: true

class Buyer < ActiveRecord::Base
  has_many :owned_parcel_items, class_name: "ParcelItem"
  has_many :placed_parcels, class_name: "Parcel", inverse_of: :buyer
end
