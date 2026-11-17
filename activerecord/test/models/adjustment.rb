# frozen_string_literal: true

class Adjustment < ActiveRecord::Base
  belongs_to :adjustable, polymorphic: true, inverse_of: :adjustments, autosave: true
end
