# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Type # :nodoc:
        class Linestring < ActiveModel::Type::String
          def type
            :linestring
          end
        end
      end
    end
  end
end
