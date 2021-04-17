# frozen_string_literal: true

require "cases/helper"
require "models/account"
require "models/aircraft"

class BatchMethodTest < ActiveRecord::TestCase
  def test_can_call_batch_method_on_single_object
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number) do |instances|
        instances.each.with_object({}) { |k, h| h[k] = 42 }
      end
    end

    assert_equal 42, klass.new.interesting_number
  end

  def test_can_call_batch_method_on_single_object_with_default_proc
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number) do |instances|
        Hash.new { |h, k| h[k] = 42 }
      end
    end

    assert_equal 42, klass.new.interesting_number
  end

  def test_memoizes_batched_method_calls
    call_count = 0

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number) do |instances|
        call_count += 1
        instances.each.with_object({}) { |k, h| h[k] = 42 }
      end
    end

    instance = klass.new
    2.times { instance.interesting_number }

    assert_equal 1, call_count
  end

  def test_combines_batched_method_calls_with_default_proc
    call_instances = []

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number) do |instances|
        call_instances << instances
        Hash.new { |h, k| h[k] = 42 }
      end
    end

    batch = ActiveRecord::BatchedMethods::Batch.new(klass)
    instances = 2.times.map { klass.new }
    instances.each { |k| k.batched_method_batch = batch }

    assert_equal [42, 42], instances.map(&:interesting_number)
    assert_equal [instances.to_set], call_instances # single call
  end

  def test_preload_with_batched_methods
    call_instances = []

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number) do |instances|
        call_instances = [instances]
        Hash.new { |h, k| h[k] = 42 }
      end
    end

    instances = 2.times.map { klass.create }

    scope = klass.where(id: instances.map(&:id)).preload(:interesting_number)

    assert_equal [42, 42], scope.map(&:interesting_number)
    assert_equal [instances.to_set], call_instances # single call
  end

  def test_includes_with_batched_methods
    call_instances = []

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number) do |instances|
        call_instances = [instances]
        Hash.new { |h, k| h[k] = 42 }
      end
    end

    instances = 2.times.map { klass.create }

    scope = klass.where(id: instances.map(&:id)).includes(:interesting_number)
    scope.first # greedy load

    assert_equal [42, 42], scope.map(&:interesting_number)
    assert_equal [instances.to_set], call_instances # single call
  end

  def test_allows_setting_batch_size
    call_instances = []

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number, batch_size: 1) do |instances|
        call_instances << instances
        instances.each.with_object({}) { |k, h| h[k] = 42 }
      end
    end

    batch = ActiveRecord::BatchedMethods::Batch.new(klass)
    instances = 2.times.map { klass.new }
    instances.each { |k| k.batched_method_batch = batch }

    2.times do
      assert_equal [42, 42], instances.map(&:interesting_number)
    end

    assert_equal instances.map { |k| [k] }, call_instances # single call
  end

  def test_allows_setting_batch_size_with_default_proc
    call_instances = []

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:interesting_number, batch_size: 1) do |instances|
        call_instances << instances
        Hash.new { |h, k| h[k] = 42 }
      end
    end

    batch = ActiveRecord::BatchedMethods::Batch.new(klass)
    instances = 2.times.map { klass.new }
    instances.each { |k| k.batched_method_batch = batch }

    2.times do
      assert_equal [42, 42], instances.map(&:interesting_number)
    end

    assert_equal instances.map { |k| [k] }, call_instances # single call
  end

  def test_allows_passing_arguments
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:incremented_number, batch_size: 1) do |instances, *args|
        instances.each.with_object({}) { |k, h| h[k] = args[0] + 1 }
      end
    end

    assert_equal 1, klass.new.incremented_number(0)
  end

  def test_allows_batching_by_arguments
    call_instances_with_arguments = []

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "funny_jokes"

      batch_method(:incremented_number) do |instances, *args|
        call_instances_with_arguments << [instances, args]
        instances.each.with_object({}) { |k, h| h[k] = args[0] + 1 }
      end
    end

    batch = ActiveRecord::BatchedMethods::Batch.new(klass)
    instances = 2.times.map { klass.new }
    instances.each { |k| k.batched_method_batch = batch }

    instances.each do |instance|
      2.times do |i|
        assert_equal i + 1, instance.incremented_number(i)
      end
    end

    expected = 2.times.map { |i| [instances.to_set, [i]] }
    assert_equal expected, call_instances_with_arguments
  end

  def test_raises_error_when_mixing_types_in_batch
    klass1 = Account
    klass2 = Aircraft

    batch = ActiveRecord::BatchedMethods::Batch.new(klass1)
    klass1.new.batched_method_batch = batch

    raised_error = assert_raises(ActiveRecord::BatchedMethods::TypeMismatch) do
      klass2.new.batched_method_batch = batch
    end

    assert_equal "Cannot add object of type #{klass2} to batch of #{klass1}", raised_error.message
  end
end
