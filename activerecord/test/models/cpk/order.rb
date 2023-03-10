# frozen_string_literal: true

module Cpk
  class Order < ActiveRecord::Base
    self.table_name = :cpk_orders
    # explicit definition is to allow schema definition to be simplified
    # to be shared between different databases
    self.primary_key = [:shop_id, :id]

    has_many :order_agreements, primary_key: :id
    has_many :books, query_constraints: [:shop_id, :order_id]
    has_one :book, query_constraints: [:shop_id, :order_id]
  end

  class BrokenOrder < Order
    has_many :books
    has_one :book
  end
end
