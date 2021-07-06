# frozen_string_literal: true

class ViewItem < ActiveRecord::Base
  self.table_name = :items
  self.insert_table_name = :view_items
  self.update_table_name = :view_items
  self.delete_table_name = :view_items
end
