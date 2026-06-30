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

    def test_try_shareable_proc_when_action_is_nil
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = nil

      proc = -> { }
      attempted = ActiveSupport::Ractors.try_shareable_proc(proc)

      assert_same(proc, attempted)
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_shareable_proc_creates_a_shareable_proc
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :raise

      proc = -> { }
      attempted = ActiveSupport::Ractors.try_shareable_proc(proc)

      assert_not_same(proc, attempted)
      assert ActiveSupport::Ractors.shareable?(attempted)
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_shareable_proc_raises
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :raise

      outer = []
      proc = -> { outer }

      assert_raises(Ractor::IsolationError) do
        ActiveSupport::Ractors.try_shareable_proc(proc)
      end
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_shareable_proc_warns
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :warn

      outer = []
      proc = -> { outer }

      assert_deprecated(/Rails attempted to make a Proc .* Ractor shareable/, ActiveSupport.deprecator) do
        attempted = ActiveSupport::Ractors.try_shareable_proc(proc)
        assert_same(proc, attempted)
      end
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_make_shareable_when_action_is_nil
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = nil

      obj = +"hello"
      attempted = ActiveSupport::Ractors.try_make_shareable(obj)

      assert_same(obj, attempted)
      assert_not ActiveSupport::Ractors.shareable?(obj)
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_make_shareable_makes_the_object_shareable
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :raise

      obj = +"hello"
      attempted = ActiveSupport::Ractors.try_make_shareable(obj)

      assert_same(obj, attempted)
      assert ActiveSupport::Ractors.shareable?(attempted)
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_make_shareable_raises
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :raise

      obj = proc { }

      assert_raises(Ractor::IsolationError) do
        ActiveSupport::Ractors.try_make_shareable(obj)
      end
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end

    def test_try_make_shareable_warns
      old = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :warn

      obj = proc { }

      assert_deprecated(/Rails attempted to make an object .* Ractor shareable/, ActiveSupport.deprecator) do
        attempted = ActiveSupport::Ractors.try_make_shareable(obj)
        assert_same(obj, attempted)
      end
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old
    end
  end
end
