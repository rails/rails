# frozen_string_literal: true

module Cpk
  class OrderTag < ActiveRecord::Base
    self.table_name = :cpk_order_tags

    belongs_to :tag, optional: true
    belongs_to :order, optional: true
  end
end
