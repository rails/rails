module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class Strexp # :nodoc:
        class << self
          alias :compile :new
        end

        attr_reader :path, :requirements, :separators, :anchor

        def initialize(path, requirements, separators, anchor = true)
          @path         = path
          @requirements = requirements
          @separators   = separators
          @anchor       = anchor
        end

        def names
          @path.scan(/:\w+/).map { |s| s.tr(':', '') }
        end
      end
    end
  end
end
