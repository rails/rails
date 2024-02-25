# frozen_string_literal: true

module Cpk
  class InventoryItemCategory < ActiveRecord::Base
    self.table_name = :cpk_inventory_item_categories

    belongs_to :inventory_item, class_name: "Cpk::InventoryItem", primary_key: [:shop_id, :id], query_constraints: [:shop_id, :inventory_item_id]
    belongs_to :category, class_name: "Cpk::Category", primary_key: [:shop_id, :id], query_constraints: [:shop_id, :category_id]
  end
end
