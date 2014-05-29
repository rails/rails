module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class Strexp # :nodoc:
        class << self
          alias :compile :new
        end

        attr_reader :path, :requirements, :separators, :anchor, :ast

        def self.build(path, requirements, separators, anchor = true)
          parser = Journey::Parser.new
          ast = parser.parse path
          new ast, path, requirements, separators, anchor
        end

        def initialize(ast, path, requirements, separators, anchor = true)
          @ast          = ast
          @path         = path
          @requirements = requirements
          @separators   = separators
          @anchor       = anchor
        end
      end
    end
  end
end
