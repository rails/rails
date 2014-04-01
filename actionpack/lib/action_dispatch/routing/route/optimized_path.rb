module ActionDispatch
  module Routing # :nodoc:
    class Route # :nodoc:
      class OptimizedPath # :nodoc:
        SEGMENTS          = %r{ \/ | [\%\w]+ | [:\*]\w+ | \. }x.freeze
        OPTIONAL_SEGMENTS = %r{ \(.+?\) }x.freeze

        class << self
          def build(path)
            arr = path.string.gsub(OPTIONAL_SEGMENTS, '').scan SEGMENTS

            arr.map! { |s| s =~ /(?<=\A[:\*])\w+\Z/ ? $~[0].to_sym : s }
          end
        end
      end
    end
  end
end
