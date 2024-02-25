# frozen_string_literal: true

module Cpk
  class Category < ActiveRecord::Base
    self.table_name = :cpk_categories

    has_many :inventory_item_categories, class_name: "Cpk::InventoryItemCategory", primary_key: [:shop_id, :id], query_constraints: [:shop_id, :category_id]
    has_many :inventory_items, through: :inventory_item_categories
  end
end
