module SessionAutoloadTest
  class Foo
    def initialize(bar='baz')
      @bar = bar
    end
    def inspect
      "#<#{self.class} bar:#{@bar.inspect}>"
    end
  end
end
