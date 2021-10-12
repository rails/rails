# frozen_string_literal: true

module Catalog
  def self.table_name_prefix
    "catalog_"
  end

  class Book < ActiveRecord::Base
    delegated_type :readable, types: [
      { name: "Catalog::Book::PrintedBook", scope: "printed_books" },
      { name: "Catalog::Book::Ebook", scope: "ebooks" }
    ]
  end
end
