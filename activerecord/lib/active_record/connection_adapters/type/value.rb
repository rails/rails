module ActiveRecord
  module ConnectionAdapters
    module Type
      class Value # :nodoc:
        def type; end

        def infinity(options = {})
          options[:negative] ? -::Float::INFINITY : ::Float::INFINITY
        end
      end
    end
  end
end
