# frozen_string_literal: true

module Cpk
  class Book < ActiveRecord::Base
    attr_accessor :fail_destroy

    self.table_name = :cpk_books
    belongs_to :order, autosave: true, foreign_key: [:shop_id, :order_id], counter_cache: true
    belongs_to :order_explicit_fk_pk, class_name: "Cpk::Order", foreign_key: [:shop_id, :order_id], primary_key: [:shop_id, :id]
    belongs_to :author, class_name: "Cpk::Author"

    has_many :chapters, foreign_key: [:author_id, :book_id]
    accepts_nested_attributes_for :chapters

    before_destroy :prevent_destroy_if_set

    generates_token_for :test

    private
      def prevent_destroy_if_set
        throw(:abort) if fail_destroy
      end
  end

  class BestSeller < Book
  end

  class BrokenBook < Book
    belongs_to :order, class_name: "Cpk::OrderWithSpecialPrimaryKey"
  end

  class BrokenBookWithNonCpkOrder < Book
    belongs_to :order, class_name: "Cpk::NonCpkOrder", foreign_key: [:shop_id, :order_id]
  end

  class NonCpkBook < Book
    self.primary_key = :id

    belongs_to :non_cpk_order, foreign_key: [:order_id]
  end

  class NullifiedBook < Book
    has_one :chapter, foreign_key: [:author_id, :book_id], dependent: :nullify
  end

  class BookWithOrderAgreements < Book
    has_many :order_agreements, through: :order
    has_one :order_agreement, through: :order, source: :order_agreements
  end
end
