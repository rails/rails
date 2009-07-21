module Gem
  class Specification
    attribute :source

    def source=(source)
      @source = source.is_a?(URI) ? source : URI.parse(source)
      raise ArgumentError, "The source must be an absolute URI" unless @source.absolute?
    end
  end
end