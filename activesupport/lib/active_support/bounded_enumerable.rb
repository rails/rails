# frozen_string_literal: true

module ActiveSupport
  class BoundedEnumerable # :nodoc:
    def initialize(collection, max_count)
      @collection = collection
      @max_count = max_count
    end

    def enumerable
      return @collection if @collection.count <= @max_count
      @collection.to_a.first(@max_count)
    end
  end
end
