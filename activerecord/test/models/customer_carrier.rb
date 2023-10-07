# frozen_string_literal: true

class CustomerCarrier < ActiveRecord::Base
  cattr_accessor :current_customer

  belongs_to :customer, optional: true
  belongs_to :carrier, optional: true

  default_scope -> {
    if current_customer
      where(customer: current_customer)
    else
      all
    end
  }
end
