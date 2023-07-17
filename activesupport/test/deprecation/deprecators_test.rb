# frozen_string_literal: true

require_relative "../abstract_unit"

class DeprecationTest < ActiveSupport::TestCase
  setup do
    @deprecator_names = [:fubar, :foo, :bar]
    @deprecators = ActiveSupport::Deprecation::Deprecators.new
    @deprecator_names.each do |name|
      @deprecators[name] = ActiveSupport::Deprecation.new("2.0", name.to_s)
    end
  end

  test "#[] gets an individual deprecator" do
    @deprecator_names.each do |name|
      assert_equal name.to_s, @deprecators[name].gem_name
    end
  end

  test "#each iterates over each deprecator" do
    gem_names = []
    @deprecators.each { |deprecator| gem_names << deprecator.gem_name }

    assert_equal @deprecator_names.map(&:to_s).sort, gem_names.sort
  end

  test "#each without block returns an Enumerator" do
    assert_kind_of Enumerator, @deprecators.each
    assert_equal @deprecator_names.map(&:to_s).sort, @deprecators.each.map(&:gem_name).sort
  end

  test "#silenced= applies to each deprecator" do
    @deprecators.each { |deprecator| assert_not_predicate deprecator, :silenced }

    @deprecators.silenced = true
    @deprecators.each { |deprecator| assert_predicate deprecator, :silenced }

    @deprecators.silenced = false
    @deprecators.each { |deprecator| assert_not_predicate deprecator, :silenced }
  end

  test "#debug= applies to each deprecator" do
    @deprecators.each { |deprecator| assert_not_predicate deprecator, :debug }

    @deprecators.debug = true
    @deprecators.each { |deprecator| assert_predicate deprecator, :debug }

    @deprecators.debug = false
    @deprecators.each { |deprecator| assert_not_predicate deprecator, :debug }
  end

  test "#behavior= applies to each deprecator" do
    callback = proc { }

    @deprecators.behavior = callback
    @deprecators.each { |deprecator| assert_equal [callback], deprecator.behavior }
  end

  test "#disallowed_behavior= applies to each deprecator" do
    callback = proc { }

    @deprecators.disallowed_behavior = callback
    @deprecators.each { |deprecator| assert_equal [callback], deprecator.disallowed_behavior }
  end

  test "#disallowed_warnings= applies to each deprecator" do
    @deprecators.disallowed_warnings = :all
    @deprecators.each { |deprecator| assert_equal :all, deprecator.disallowed_warnings }
  end

  test "#silence silences each deprecator" do
    @deprecators.each { |deprecator| assert_not_silencing(deprecator) }

    @deprecators.silence do
      @deprecators.each { |deprecator| assert_silencing(deprecator) }
    end

    @deprecators.each { |deprecator| assert_not_silencing(deprecator) }
  end

  test "#silence returns the result of the block" do
    assert_equal 123, @deprecators.silence { 123 }
  end

  test "#silence ensures silencing is reverted after an error is raised" do
    assert_raises do
      @deprecators.silence { raise }
    end

    @deprecators.each { |deprecator| assert_not_silencing(deprecator) }
  end

  test "#silence blocks can be nested" do
    @deprecators.each { |deprecator| assert_not_silencing(deprecator) }

    @deprecators.silence do
      @deprecators.each { |deprecator| assert_silencing(deprecator) }

      @deprecators.silence do
        @deprecators.each { |deprecator| assert_silencing(deprecator) }
      end

      @deprecators.each { |deprecator| assert_silencing(deprecator) }
    end

    @deprecators.each { |deprecator| assert_not_silencing(deprecator) }
  end

  test "#silence only affects the current thread" do
    @deprecators.silence do
      @deprecators.each { |deprecator| assert_silencing(deprecator) }

      Thread.new do
        @deprecators.each { |deprecator| assert_not_silencing(deprecator) }

        @deprecators.silence do
          @deprecators.each { |deprecator| assert_silencing(deprecator) }
        end

        @deprecators.each { |deprecator| assert_not_silencing(deprecator) }
      end.join

      @deprecators.each { |deprecator| assert_silencing(deprecator) }
    end
  end

  private
    def assert_silencing(deprecator)
      assert_not_deprecated(deprecator) { deprecator.warn }
    end

    def assert_not_silencing(deprecator)
      assert_deprecated(deprecator) { deprecator.warn }
    end
end
