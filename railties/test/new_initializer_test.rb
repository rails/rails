require 'abstract_unit'
require 'active_support/ruby/shim'

module Rails
  class Initializer
    class Error < StandardError ; end
    class Runner
      def initialize
        @names = {}
        @initializers = []
      end
      
      def add(name, options = {}, &block)
        if other = options[:before] || options[:after] and !@names[other]
          raise Error, "The #{other.inspect} initializer does not exist"
        end
        
        Class.new(Initializer, &block).new.tap do |initializer|
          index = if options[:before]
            @initializers.index(@names[other])
          elsif options[:after]
            @initializers.index(@names[other]) + 1
          else
            -1
          end
          
          @initializers.insert(index, initializer)
          @names[name] = initializer
        end
      end
      
      def run
        @initializers.each { |init| init.run }
      end
    end
    
    def self.run(&blk)
      define_method(:run, &blk)
    end
  end
end


class InitializerRunnerTest < ActiveSupport::TestCase
  
  def setup
    @runner = Rails::Initializer::Runner.new
  end
  
  test "A new runner can be created" do
    assert @runner
  end
  
  test "You can create initializers" do
    init = @runner.add :foo do
      
    end
    
    assert_kind_of Rails::Initializer, init
  end
  
  test "The initializers actually get run when the runner is run" do
    state = nil
    
    @runner.add :foo do
      run { state = true }
    end
    
    @runner.run
    assert state
  end
  
  test "By default, initializers get run in the order that they are added" do
    state = []
    
    @runner.add :first do
      run { state << :first }
    end
    
    @runner.add :second do
      run { state << :second }
    end
    
    @runner.run
    assert_equal [:first, :second], state
  end
  
  test "Raises an exception if :before or :after are specified, but don't exist" do
    assert_raise(Rails::Initializer::Error) do
      @runner.add(:fail, :before => :whale) { 1 }
    end
    
    assert_raise(Rails::Initializer::Error) do
      @runner.add(:fail, :after => :whale) { 1 }
    end
  end
  
  test "When adding an initializer, specifying :after allows you to move an initializer after another" do
    state = []
    
    @runner.add :first do
      run { state << :first }
    end
    
    @runner.add :second do
      run { state << :second }
    end
    
    @runner.add :third, :after => :first do
      run { state << :third }
    end
    
    @runner.run
    assert_equal [:first, :third, :second], state
  end
  
end

