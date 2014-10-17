module ActiveRecord
  module Type
    module Decorator # :nodoc:
      def init_with(coder)
        @subtype = coder['subtype']
        __setobj__(@subtype)
      end

      def encode_with(coder)
        coder['subtype'] = __getobj__
      end
    end
  end
end
