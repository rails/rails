# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module DefaultScopes
    extend ActiveSupport::Concern

    included do
      scope :chronologically, -> { ordered_relation }
      scope :reverse_chronologically, -> { ordered_relation.reverse_order }
    end
  end
end
