require 'abstract_unit'

class Record
  include ActiveSupport::Callbacks

  define_callbacks :before_save, :after_save

  class << self
    def callback_symbol(callback_method)
      returning("#{callback_method}_method") do |method_name|
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
  before_save Proc.new { |r| r.history << [:before_save, :proc] }, :if => Proc.new { |r| true }
  before_save Proc.new { |r| r.history << "b00m" }, :if => Proc.new { |r| false }
  before_save Proc.new { |r| r.history << [:before_save, :proc] }, :unless => Proc.new { |r| false }
  before_save Proc.new { |r| r.history << "b00m" }, :unless => Proc.new { |r| true }

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
      [:before_save, :proc]
    ], person.history
  end
end
