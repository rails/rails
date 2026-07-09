# frozen_string_literal: true

class Shipment < ActiveRecord::Base
  has_many :adjustments,
    as: :adjustable,
    foreign_key: [:region_id, :adjustable_id],
    primary_key: [:region_id, :id],
    inverse_of: :adjustable

  has_many :region_adjustments,
    class_name: "Adjustment",
    primary_key: :region_id,
    foreign_key: :region_id
  has_many :adjusted_shipments,
    through: :region_adjustments,
    source: :composite_adjustable,
    source_type: "Shipment"
end
