module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class Strexp # :nodoc:
        class << self
          alias :compile :new
        end

        attr_reader :path, :requirements, :separators, :ast

        def self.build(path, requirements, separators)
          parser = Journey::Parser.new
          ast = parser.parse path
          new ast, path, requirements, separators
        end

        def initialize(ast, path, requirements, separators)
          @ast          = ast
          @path         = path
          @requirements = requirements
          @separators   = separators
        end
      end
    end
  end
end
