# frozen_string_literal: true

class ShopAccount < ActiveRecord::Base
  belongs_to :customer, optional: true
  belongs_to :customer_carrier, optional: true

  has_one :carrier, through: :customer_carrier
end
