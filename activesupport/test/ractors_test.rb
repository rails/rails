# frozen_string_literal: true

require_relative "abstract_unit"

class KernelRactorShareabilityTest < ActiveSupport::TestCase
  if RUBY_VERSION >= "4.0"
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
