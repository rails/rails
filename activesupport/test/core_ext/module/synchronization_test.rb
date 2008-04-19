require 'abstract_unit'

class SynchronizationTest < Test::Unit::TestCase
  def setup
    @target = Class.new
    @target.cattr_accessor :mutex, :instance_writer => false
    @target.mutex = Mutex.new
    @instance = @target.new
  end

  def test_synchronize_aliases_method_chain_with_synchronize
    @target.module_eval do
      attr_accessor :value
      synchronize :value, :with => :mutex
    end
    assert @instance.respond_to?(:value_with_synchronization)
    assert @instance.respond_to?(:value_without_synchronization)
  end

  def test_synchronize_does_not_change_behavior
    @target.module_eval do
      attr_accessor :value
      synchronize :value, :with => :mutex
    end
    expected = "some state"
    @instance.value = expected
    assert_equal expected, @instance.value
  end

  def test_synchronize_with_no_mutex_raises_an_argument_error
    assert_raises(ArgumentError) do
      @target.synchronize :to_s
    end
  end

  def test_double_synchronize_raises_an_argument_error
    @target.synchronize :to_s, :with => :mutex
    assert_raises(ArgumentError) do
      @target.synchronize :to_s, :with => :mutex
    end
  end

  def test_mutex_is_entered_during_method_call
    dummy = Object.new
    def dummy.synchronize
      @sync_count ||= 0
      @sync_count += 1
      yield
    end
    def dummy.sync_count; @sync_count; end
    @target.mutex = dummy
    @target.synchronize :to_s, :with => :mutex
    @instance.to_s
    @instance.to_s
    assert_equal 2, dummy.sync_count
  end

  def test_can_synchronize_method_with_punctuation
    @target.module_eval do
      def dangerous?
        @dangerous
      end
      def dangerous!
        @dangerous = true
      end
    end
    @target.synchronize :dangerous?, :dangerous!, :with => :mutex
    @instance.dangerous!
    assert @instance.dangerous?
  end
end