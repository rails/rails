# frozen_string_literal: true

require_relative "abstract_unit"
require 'benchmark'

class StringInquirerTest < ActiveSupport::TestCase
  def setup
    @string_inquirer = ActiveSupport::StringInquirer.new("production")
  end

  def test_match
    assert_predicate @string_inquirer, :production?
  end

  def test_miss
    assert_not_predicate @string_inquirer, :development?
  end

  def test_missing_question_mark
    assert_raise(NoMethodError) { @string_inquirer.production }
  end

  def test_respond_to
    assert_respond_to @string_inquirer, :development?
  end

  def test_respond_to_fallback
    str = ActiveSupport::StringInquirer.new("hello")

    class << str
      def respond_to_missing?(name, include_private = false)
        (name == :bar) || super
      end
    end

    assert_respond_to str, :are_you_ready?
    assert_respond_to str, :bar
    assert_not_respond_to str, :nope
  end

  def test_benchmark
    str   = ActiveSupport::StringInquirer.new("hello")
    count = 100_000

    Benchmark.bm do |bm|
      bm.report 'all true' do
        count.times do
          str.hello?
        end
      end
      bm.report 'all false' do
        count.times do
          str.hi?
        end
      end
      bm.report 'half' do
        (count / 2).times do
          str.hello?
        end
        (count / 2).times do
          str.hi?
        end
      end
    end
  end
end
