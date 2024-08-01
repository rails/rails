# frozen_string_literal: true

module Cpk
  # This is a non composite primary key model that is associated with `Cpk::Order` via `id` only.
  class OrderAgreement < ActiveRecord::Base
    self.table_name = :cpk_order_agreements

    belongs_to :order
  end
end
