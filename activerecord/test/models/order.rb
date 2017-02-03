class Order < ActiveRecord::Base
  belongs_to :billing, class_name: "Customer", foreign_key: "billing_customer_id"
  belongs_to :shipping, class_name: "Customer", foreign_key: "shipping_customer_id"
end
