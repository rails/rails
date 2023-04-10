# frozen_string_literal: true

module Cpk
  class Order < ActiveRecord::Base
    self.table_name = :cpk_orders
    self.primary_key = [:shop_id, :id]
  end
end
