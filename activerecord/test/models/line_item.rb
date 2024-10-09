# frozen_string_literal: true

class LineItem < ActiveRecord::Base
  belongs_to :invoice, touch: true
  has_many :discount_applications, class_name: "LineItemDiscountApplication"

  def raise_unless_invoice_present=(should_assert)
    return unless should_assert

    raise Exception, "Invoice is not present" unless invoice.present?
  end
end

class LineItemDiscountApplication < ActiveRecord::Base
  belongs_to :line_item
  belongs_to :discount
end
