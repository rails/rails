require "abstract_unit"

class DescribeTest < ActiveSupport::TestCase
  test "prefixes declarative test names for show" do
    cls = Class.new(ActiveSupport::TestCase) do
      describe "context" do
        test "something"

        # Non-declarative test names are untouched.
        def test_something_else
        end
      end
    end

    assert_includes cls.instance_methods, :test_context_something
    assert_includes cls.instance_methods, :test_something_else
  end

  test "the context can be anything we can show" do
    cls = Class.new(ActiveSupport::TestCase) do
      Inner = Class.new do
        def self.to_s
          "Inner"
        end
      end

      describe Inner do
        test "internal_work"
      end
    end

    assert_includes cls.instance_methods, :"test_Inner_internal_work"
  end

  test "cannot be nested" do
    assert_raises RuntimeError do
      Class.new(ActiveSupport::TestCase) do
        describe "context" do
          describe "we do not encourage nested contexts" do
            test "something"
          end
        end
      end
    end
  end
end
