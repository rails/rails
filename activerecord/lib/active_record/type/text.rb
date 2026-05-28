# frozen_string_literal: true

module ActiveRecord
  module Type
    class Text < String # :nodoc:
      def type
        :text
      end
    end
  end
end
