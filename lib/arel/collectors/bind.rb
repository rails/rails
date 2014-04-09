module Arel
  module Collectors
    class Bind
      def initialize
        @parts = []
      end

      def << str
        @parts << str
        self
      end

      def add_bind bind
        @parts << bind
        self
      end

      def value; @parts; end

      def substitute_binds bvs
        bvs = bvs.dup
        @parts.map do |val|
          if Arel::Nodes::BindParam === val
            bvs.shift
          else
            val
          end
        end
      end

      def compile bvs
        substitute_binds(bvs).join
      end
    end
  end
end
