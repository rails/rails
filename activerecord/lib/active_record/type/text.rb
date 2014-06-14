require 'active_record/type/string'

module ActiveRecord
  module Type
    class Text < String # :nodoc:
      def type
        :text
      end
    end
  end
end
