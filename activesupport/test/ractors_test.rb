# frozen_string_literal: true

require_relative "abstract_unit"

class RactorsTest < ActiveSupport::TestCase
  if RUBY_VERSION >= "4.0"
    def test_on_main_runs_block_on_main_ractor
      value = Ractor.new do
        ActiveSupport::Ractors.on_main { ActiveSupport::Ractors.main? }
      end.value

      assert value
    end

    def test_on_main_evaluates_block_against_object
      object = Class.new do
        self.singleton_class.attr_accessor :foo
        self.foo = :foo
      end
      Ractor.new(object) do |obj|
        ActiveSupport::Ractors.on_main(obj) { @foo = :bar }
      end.join

      assert_equal :bar, object.foo
    end

    def test_ractor_make_shareable_returns_a_shareable_object
      string = +"hello"
      assert_not ActiveSupport::Ractors.shareable?(string)

      shareable_string = ActiveSupport::Ractors.make_shareable(string)

      assert_same string, shareable_string
      assert ActiveSupport::Ractors.shareable?(string)
    end

    def test_ractor_shareable_proc_returns_a_shareable_proc_that_runs_the_block
      proc = ActiveSupport::Ractors.shareable_proc { 1 + 1 }

      assert ActiveSupport::Ractors.shareable?(proc)
      assert_equal 2, proc.call
    end

    def test_ractor_shareable_proc_with_self
      bar = 2
      proc = ActiveSupport::Ractors.shareable_proc(self: bar) { to_s }

      assert ActiveSupport::Ractors.shareable?(proc)
      assert_equal "2", proc.call
    end

    def test_ractor_shareable_lambda_returns_a_shareable_lambda_that_runs_the_block
      lambda = ActiveSupport::Ractors.shareable_lambda { 1 + 1 }

      assert_predicate lambda, :lambda?
      assert ActiveSupport::Ractors.shareable?(lambda)
      assert_equal 2, lambda.call
    end

    def test_ractor_shareable_lambda_with_self
      bar = 2
      lambda = ActiveSupport::Ractors.shareable_lambda(self: bar) { to_s }

      assert ActiveSupport::Ractors.shareable?(lambda)
      assert_equal "2", lambda.call
    end
  end
end
