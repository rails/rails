# frozen_string_literal: true

module Arel # :nodoc: all
  module OrderPredications
    def asc
      Nodes::Ascending.new(self)
    end

    def desc
      Nodes::Descending.new(self)
    end

    def asc_nulls_first
      Nodes::Ascending.new(self).nulls_first
    end

    def desc_nulls_last
      Nodes::Descending.new(self).nulls_last
    end
  end
end
