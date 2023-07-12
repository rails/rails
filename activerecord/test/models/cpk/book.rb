# frozen_string_literal: true

module Cpk
  class Book < ActiveRecord::Base
    self.table_name = :cpk_books
    belongs_to :order, autosave: true, query_constraints: [:shop_id, :order_id]
    belongs_to :author, class_name: "Cpk::Author"

    has_many :chapters, query_constraints: [:author_id, :book_id]
  end

  class BestSeller < Book
  end

  class BrokenBook < Book
    belongs_to :order
  end

  class BrokenBookWithNonCpkOrder < Book
    belongs_to :order, class_name: "Cpk::NonCpkOrder", query_constraints: [:shop_id, :order_id]
  end

  class NonCpkBook < Book
    self.primary_key = :id

    belongs_to :non_cpk_order, query_constraints: [:order_id]
  end

  class NullifiedBook < Book
    has_one :chapter, query_constraints: [:author_id, :book_id], dependent: :nullify
  end

  class BookWithOrderAgreements < Book
    has_many :order_agreements, through: :order
    has_one :order_agreement, through: :order, source: :order_agreements
  end
end
