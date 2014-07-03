module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module Cast # :nodoc:
        def range_to_string(object) # :nodoc:
          from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
          to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
          "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
        end
      end
    end
  end
end
