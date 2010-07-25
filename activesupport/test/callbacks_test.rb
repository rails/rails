require 'abstract_unit'

class Record
  include ActiveSupport::Callbacks

  define_callbacks :before_save, :after_save

  class << self
    def callback_symbol(callback_method)
      "#{callback_method}_method".tap do |method_name|
        define_method(method_name) do
          history << [callback_method, :symbol]
        end
      end
    end

    def callback_string(callback_method)
      "history << [#{callback_method.to_sym.inspect}, :string]"
    end

    def callback_proc(callback_method)
      Proc.new { |model| model.history << [callback_method, :proc] }
    end

    def callback_object(callback_method)
      klass = Class.new
      klass.send(:define_method, callback_method) do |model|
        model.history << [callback_method, :object]
      end
      klass.new
    end
  end

  def history
    @history ||= []
  end
end

class Person < Record
  [:before_save, :after_save].each do |callback_method|
    callback_method_sym = callback_method.to_sym
    send(callback_method, callback_symbol(callback_method_sym))
    send(callback_method, callback_string(callback_method_sym))
    send(callback_method, callback_proc(callback_method_sym))
    send(callback_method, callback_object(callback_method_sym))
    send(callback_method) { |model| model.history << [callback_method_sym, :block] }
  end

  def save
    run_callbacks(:before_save)
    run_callbacks(:after_save)
  end
end

class ConditionalPerson < Record
  # proc
  before_save Proc.new { |r| r.history << [:before_save, :proc] }, :if => Proc.new { |r| true }
  before_save Proc.new { |r| r.history << "b00m" }, :if => Proc.new { |r| false }
  before_save Proc.new { |r| r.history << [:before_save, :proc] }, :unless => Proc.new { |r| false }
  before_save Proc.new { |r| r.history << "b00m" }, :unless => Proc.new { |r| true }
  # symbol
  before_save Proc.new { |r| r.history << [:before_save, :symbol] }, :if => :yes
  before_save Proc.new { |r| r.history << "b00m" }, :if => :no
  before_save Proc.new { |r| r.history << [:before_save, :symbol] }, :unless => :no
  before_save Proc.new { |r| r.history << "b00m" }, :unless => :yes
  # string
  before_save Proc.new { |r| r.history << [:before_save, :string] }, :if => 'yes'
  before_save Proc.new { |r| r.history << "b00m" }, :if => 'no'
  before_save Proc.new { |r| r.history << [:before_save, :string] }, :unless => 'no'
  before_save Proc.new { |r| r.history << "b00m" }, :unless => 'yes'
  # Array with conditions
  before_save Proc.new { |r| r.history << [:before_save, :symbol_array] }, :if => [:yes, :other_yes]
  before_save Proc.new { |r| r.history << "b00m" }, :if => [:yes, :no]
  before_save Proc.new { |r| r.history << [:before_save, :symbol_array] }, :unless => [:no, :other_no]
  before_save Proc.new { |r| r.history << "b00m" }, :unless => [:yes, :no]
  # Combined if and unless
  before_save Proc.new { |r| r.history << [:before_save, :combined_symbol] }, :if => :yes, :unless => :no
  before_save Proc.new { |r| r.history << "b00m" }, :if => :yes, :unless => :yes
  # Array with different types of conditions
  before_save Proc.new { |r| r.history << [:before_save, :symbol_proc_string_array] }, :if => [:yes, Proc.new { |r| true }, 'yes']
  before_save Proc.new { |r| r.history << "b00m" }, :if => [:yes, Proc.new { |r| true }, 'no']
  # Array with different types of conditions comibned if and unless
  before_save Proc.new { |r| r.history << [:before_save, :combined_symbol_proc_string_array] },
              :if => [:yes, Proc.new { |r| true }, 'yes'], :unless => [:no, 'no']
  before_save Proc.new { |r| r.history << "b00m" }, :if => [:yes, Proc.new { |r| true }, 'no'], :unless => [:no, 'no']

  def yes; true; end
  def other_yes; true; end
  def no; false; end
  def other_no; false; end

  def save
    run_callbacks(:before_save)
    run_callbacks(:after_save)
  end
end

class CallbacksTest < Test::Unit::TestCase
  def test_save_person
    person = Person.new
    assert_equal [], person.history
    person.save
    assert_equal [
      [:before_save, :symbol],
      [:before_save, :string],
      [:before_save, :proc],
      [:before_save, :object],
      [:before_save, :block],
      [:after_save, :symbol],
      [:after_save, :string],
      [:after_save, :proc],
      [:after_save, :object],
      [:after_save, :block]
    ], person.history
  end
end

class ConditionalCallbackTest < Test::Unit::TestCase
  def test_save_conditional_person
    person = ConditionalPerson.new
    person.save
    assert_equal [
      [:before_save, :proc],
      [:before_save, :proc],
      [:before_save, :symbol],
      [:before_save, :symbol],
      [:before_save, :string],
      [:before_save, :string],
      [:before_save, :symbol_array],
      [:before_save, :symbol_array],
      [:before_save, :combined_symbol],
      [:before_save, :symbol_proc_string_array],
      [:before_save, :combined_symbol_proc_string_array]
    ], person.history
  end
end

class CallbackTest < Test::Unit::TestCase
  include ActiveSupport::Callbacks

  def test_eql
    callback = Callback.new(:before, :save, :identifier => :lifesaver)
    assert callback.eql?(Callback.new(:before, :save, :identifier => :lifesaver))
    assert callback.eql?(Callback.new(:before, :save))
    assert callback.eql?(:lifesaver)
    assert callback.eql?(:save)
    assert !callback.eql?(Callback.new(:before, :destroy))
    assert !callback.eql?(:destroy)
  end

  def test_dup
    a = Callback.new(:before, :save)
    assert_equal({}, a.options)
    b = a.dup
    b.options[:unless] = :pigs_fly
    assert_equal({:unless => :pigs_fly}, b.options)
    assert_equal({}, a.options)
  end
end

class CallbackChainTest < Test::Unit::TestCase
  include ActiveSupport::Callbacks

  def setup
    @chain = CallbackChain.build(:make, :bacon, :lettuce, :tomato)
  end

  def test_build
    assert_equal 3, @chain.size
    assert_equal [:bacon, :lettuce, :tomato], @chain.map(&:method)
  end

  def test_find
    assert_equal :bacon, @chain.find(:bacon).method
  end

  def test_replace_or_append
    assert_equal [:bacon, :lettuce, :tomato], (@chain.replace_or_append!(Callback.new(:make, :bacon))).map(&:method)
    assert_equal [:bacon, :lettuce, :tomato, :turkey], (@chain.replace_or_append!(Callback.new(:make, :turkey))).map(&:method)
    assert_equal [:bacon, :lettuce, :tomato, :turkey, :mayo], (@chain.replace_or_append!(Callback.new(:make, :mayo))).map(&:method)
  end

  def test_delete
    assert_equal [:bacon, :lettuce, :tomato], @chain.map(&:method)
    @chain.delete(:bacon)
    assert_equal [:lettuce, :tomato], @chain.map(&:method)
  end
end
