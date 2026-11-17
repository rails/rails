# frozen_string_literal: true

class Shipment < ActiveRecord::Base
  has_many :adjustments,
    as: :adjustable,
    foreign_key: [:region_id, :adjustable_id],
    primary_key: [:region_id, :id],
    inverse_of: :adjustable
end
