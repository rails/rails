# frozen_string_literal: true

class PriceEstimate < ActiveRecord::Base
  include ActiveSupport::NumberHelper

  belongs_to :estimate_of, polymorphic: true
  belongs_to :thing, polymorphic: true

  validates_numericality_of :price

  def price
    number_to_currency super
  end
end
