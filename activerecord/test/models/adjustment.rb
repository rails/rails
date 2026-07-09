# frozen_string_literal: true

class Adjustment < ActiveRecord::Base
  belongs_to :adjustable, polymorphic: true, inverse_of: :adjustments, autosave: true
  belongs_to :composite_adjustable,
    polymorphic: true,
    primary_key: [:region_id, :id],
    foreign_key: [:region_id, :adjustable_id],
    foreign_type: :adjustable_type
end
