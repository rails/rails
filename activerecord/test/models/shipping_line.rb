# frozen_string_literal: true

class ShippingLine < ActiveRecord::Base
  belongs_to :invoice, touch: true, optional: true
  has_many :discount_applications, class_name: "ShippingLineDiscountApplication"
end

class ShippingLineDiscountApplication < ActiveRecord::Base
  belongs_to :shipping_line, optional: true
  belongs_to :discount, optional: true
end
