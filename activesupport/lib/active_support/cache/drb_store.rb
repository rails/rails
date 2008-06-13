require 'drb'

module ActiveSupport
  module Cache
    class DRbStore < MemoryStore #:nodoc:
      attr_reader :address

      def initialize(address = 'druby://localhost:9192')
        super()
        @address = address
        @data = DRbObject.new(nil, address)
      end
    end
  end
end