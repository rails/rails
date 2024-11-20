# frozen_string_literal: true

module Cpk
  class Tag < ActiveRecord::Base
    self.table_name = :cpk_tags

    has_many :order_tags
    has_many :orders, through: :order_tags
  end
end
