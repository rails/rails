# frozen_string_literal: true

module ActiveRecord
  module Type
    class Integer < ActiveModel::Type::Integer # :nodoc:
      private
        def _limit
          limit || 4 # 4 bytes means an integer as opposed to smallint etc.
        end
    end
  end
end
