# frozen_string_literal: true

module Cpk
  class Order < ActiveRecord::Base
    self.table_name = :cpk_orders
    # explicit definition is to allow schema definition to be simplified
    # to be shared between different databases
    self.primary_key = [:shop_id, :id]

    alias_attribute :id_value, :id

    has_many :order_agreements
    has_many :books, foreign_key: [:shop_id, :order_id]
    has_one :book, foreign_key: [:shop_id, :order_id]
    has_many :order_tags
    has_many :tags, through: :order_tags
  end

  class BrokenOrder < Order
    self.primary_key = [:shop_id, :status]

    has_many :books
    has_one :book
  end

  class OrderWithSpecialPrimaryKey < Order
    self.primary_key = [:shop_id, :status]

    has_many :books, foreign_key: [:shop_id, :status]
    has_one :book, foreign_key: [:shop_id, :status]
  end

  class BrokenOrderWithNonCpkBooks < Order
    self.primary_key = [:shop_id, :status]

    has_many :books, class_name: "Cpk::NonCpkBook"
    has_one :book, class_name: "Cpk::NonCpkBook"
  end

  class NonCpkOrder < Order
    self.primary_key = :id
  end

  class OrderWithPrimaryKeyAssociatedBook < Order
    has_one :book, foreign_key: :order_id
  end

  class OrderWithNullifiedBook < Order
    has_one :book, foreign_key: [:shop_id, :order_id], dependent: :nullify
  end

  class OrderWithSingularBookChapters < Order
    has_many :chapters, through: :book
  end
end
