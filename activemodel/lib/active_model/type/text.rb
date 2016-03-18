require 'active_model/type/string'

module ActiveModel
  module Type
    class Text < String # :nodoc:
      def type
        :text
      end
    end
  end
end
