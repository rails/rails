# frozen_string_literal: true

class Shipment < ActiveRecord::Base
  has_many :adjustments,
    as: :adjustable,
    foreign_key: :adjustable_id,
    query_constraints: [:region_id],
    inverse_of: :adjustable
end
