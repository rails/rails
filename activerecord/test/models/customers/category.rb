# frozen_string_literal: true

module Customers
  class Category < ActiveRecord::Base
    self.table_name = :customers_categories
  end
end
