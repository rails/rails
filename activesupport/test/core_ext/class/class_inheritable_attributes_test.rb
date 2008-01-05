require 'abstract_unit'

class ClassInheritableAttributesTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
  end

  def test_reader_declaration
    assert_nothing_raised do
      @klass.class_inheritable_reader :a
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
    end
  end

  def test_writer_declaration
    assert_nothing_raised do
      @klass.class_inheritable_writer :a
      assert_respond_to @klass, :a=
      assert_respond_to @klass.new, :a=
    end
  end
  
  def test_writer_declaration_without_instance_writer
    assert_nothing_raised do
      @klass.class_inheritable_writer :a, :instance_writer => false
      assert_respond_to @klass, :a=
      assert !@klass.new.respond_to?(:a=)
    end
  end

  def test_accessor_declaration
    assert_nothing_raised do
      @klass.class_inheritable_accessor :a
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
      assert_respond_to @klass, :a=
      assert_respond_to @klass.new, :a=
    end
  end
  
  def test_accessor_declaration_without_instance_writer
    assert_nothing_raised do
      @klass.class_inheritable_accessor :a, :instance_writer => false
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
      assert_respond_to @klass, :a=
      assert !@klass.new.respond_to?(:a=)
    end
  end

  def test_array_declaration
    assert_nothing_raised do
      @klass.class_inheritable_array :a
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
      assert_respond_to @klass, :a=
      assert_respond_to @klass.new, :a=
    end
  end

  def test_array_declaration_without_instance_writer
    assert_nothing_raised do
      @klass.class_inheritable_array :a, :instance_writer => false
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
      assert_respond_to @klass, :a=
      assert !@klass.new.respond_to?(:a=)
    end
  end

  def test_hash_declaration
    assert_nothing_raised do
      @klass.class_inheritable_hash :a
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
      assert_respond_to @klass, :a=
      assert_respond_to @klass.new, :a=
    end
  end

  def test_hash_declaration_without_instance_writer
    assert_nothing_raised do
      @klass.class_inheritable_hash :a, :instance_writer => false
      assert_respond_to @klass, :a
      assert_respond_to @klass.new, :a
      assert_respond_to @klass, :a=
      assert !@klass.new.respond_to?(:a=)
    end
  end

  def test_reader
    @klass.class_inheritable_reader :a
    assert_nil @klass.a
    assert_nil @klass.new.a

    @klass.send(:write_inheritable_attribute, :a, 'a')

    assert_equal 'a', @klass.a
    assert_equal 'a', @klass.new.a
    assert_equal @klass.a, @klass.new.a
    assert_equal @klass.a.object_id, @klass.new.a.object_id
  end

  def test_writer
    @klass.class_inheritable_reader :a
    @klass.class_inheritable_writer :a

    assert_nil @klass.a
    assert_nil @klass.new.a

    @klass.a = 'a'
    assert_equal 'a', @klass.a
    @klass.new.a = 'A'
    assert_equal 'A', @klass.a
  end

  def test_array
    @klass.class_inheritable_array :a

    assert_nil @klass.a
    assert_nil @klass.new.a

    @klass.a = %w(a b c)
    assert_equal %w(a b c), @klass.a
    assert_equal %w(a b c), @klass.new.a

    @klass.new.a = %w(A B C)
    assert_equal %w(a b c A B C), @klass.a
    assert_equal %w(a b c A B C), @klass.new.a
  end

  def test_hash
    @klass.class_inheritable_hash :a

    assert_nil @klass.a
    assert_nil @klass.new.a

    @klass.a = { :a => 'a' }
    assert_equal({ :a => 'a' }, @klass.a)
    assert_equal({ :a => 'a' }, @klass.new.a)

    @klass.new.a = { :b => 'b' }
    assert_equal({ :a => 'a', :b => 'b' }, @klass.a)
    assert_equal({ :a => 'a', :b => 'b' }, @klass.new.a)
  end

  def test_inheritance
    @klass.class_inheritable_accessor :a
    @klass.a = 'a'

    @sub = eval("class FlogMe < @klass; end; FlogMe")

    @klass.class_inheritable_accessor :b

    assert_respond_to @sub, :a
    assert_respond_to @sub, :b
    assert_equal @klass.a, @sub.a
    assert_equal @klass.b, @sub.b
    assert_equal 'a', @sub.a
    assert_nil @sub.b

    @klass.b = 'b'
    assert_not_equal @klass.b, @sub.b
    assert_equal 'b', @klass.b
    assert_nil @sub.b

    @sub.a = 'A'
    assert_not_equal @klass.a, @sub.a
    assert_equal 'a', @klass.a
    assert_equal 'A', @sub.a

    @sub.b = 'B'
    assert_not_equal @klass.b, @sub.b
    assert_equal 'b', @klass.b
    assert_equal 'B', @sub.b
  end
  
  def test_array_inheritance
    @klass.class_inheritable_accessor :a
    @klass.a = []

    @sub = eval("class SubbyArray < @klass; end; SubbyArray")
    
    assert_equal [], @klass.a
    assert_equal [], @sub.a
    
    @sub.a << :first
    
    assert_equal [:first], @sub.a
    assert_equal [], @klass.a
  end
  
  def test_array_inheritance_
    @klass.class_inheritable_accessor :a
    @klass.a = {}

    @sub = eval("class SubbyHash < @klass; end; SubbyHash")
    
    assert_equal Hash.new, @klass.a
    assert_equal Hash.new, @sub.a
    
    @sub.a[:first] = :first
    
    assert_equal 1, @sub.a.keys.size
    assert_equal 0, @klass.a.keys.size
  end
  
  def test_reset_inheritable_attributes
    @klass.class_inheritable_accessor :a
    @klass.a = 'a'

    @sub = eval("class Inheriting < @klass; end; Inheriting")

    assert_equal 'a', @klass.a
    assert_equal 'a', @sub.a

    @klass.reset_inheritable_attributes
    @sub = eval("class NotInheriting < @klass; end; NotInheriting")

    assert_equal nil, @klass.a
    assert_equal nil, @sub.a
  end
end
