# frozen_string_literal: true

require_dependency "models/arunit2_model"
require "active_support/core_ext/object/with_options"

class College < ARUnit2Model
  has_many :courses

  with_options dependent: :destroy do |assoc|
    assoc.has_many :students, -> { where(active: true) }
  end
end
