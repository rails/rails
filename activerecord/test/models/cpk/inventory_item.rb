# frozen_string_literal: true

module Cpk
  class InventoryItem < ActiveRecord::Base
    self.table_name = :cpk_inventory_items

    has_many :inventory_item_categories, class_name: "Cpk::InventoryItemCategory", primary_key: [:shop_id, :id], query_constraints: [:shop_id, :inventory_item_id]
    has_many :categories, through: :inventory_item_categories
  end
end
