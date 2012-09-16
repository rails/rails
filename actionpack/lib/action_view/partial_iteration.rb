module ActionView
  class PartialIteration # :nodoc:
    attr_reader :size, :index

    def initialize(size, index)
      @size  = size
      @index = index
    end

    def first?
      index == 0
    end

    def last?
      index == size - 1
    end

  end
end
