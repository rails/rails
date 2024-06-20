# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Type # :nodoc:
        class Multilinestring < ActiveModel::Type::String
          def type
            :multilinestring
          end
        end
      end
    end
  end
end
