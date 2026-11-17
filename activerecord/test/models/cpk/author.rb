# frozen_string_literal: true

module Cpk
  class Author < ActiveRecord::Base
    self.table_name = :cpk_authors

    has_many :books, class_name: "Cpk::Book", dependent: :delete_all

    has_many :ordered_books, -> { order(id: :desc) }, class_name: "Cpk::Book"
    has_many :orders, through: :ordered_books, source: :order
    has_many :no_joins_orders, through: :ordered_books, source: :order, disable_joins: true
  end
end
