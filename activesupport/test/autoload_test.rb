require 'abstract_unit'

class TestAutoloadModule < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  module ::Fixtures
    extend ActiveSupport::Autoload

    module Autoload
      extend ActiveSupport::Autoload
    end
  end

  test "the autoload module works like normal autoload" do
    module ::Fixtures::Autoload
      autoload :SomeClass, "fixtures/autoload/some_class"
    end

    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "when specifying an :eager constant it still works like normal autoload by default" do
    module ::Fixtures::Autoload
      autoload :SomeClass, "fixtures/autoload/some_class"
    end

    assert !$LOADED_FEATURES.include?("fixtures/autoload/some_class.rb")
    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "the location of autoloaded constants defaults to :name.underscore" do
    module ::Fixtures::Autoload
      autoload :SomeClass
    end

    assert !$LOADED_FEATURES.include?("fixtures/autoload/some_class.rb")
    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "the location of :eager autoloaded constants defaults to :name.underscore" do
    module ::Fixtures::Autoload
      autoload :SomeClass
    end

    ::Fixtures::Autoload.eager_load!
    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "a directory for a block of autoloads can be specified" do
    module ::Fixtures
      autoload_under "autoload" do
        autoload :AnotherClass
      end
    end

    assert !$LOADED_FEATURES.include?("fixtures/autoload/another_class.rb")
    assert_nothing_raised { ::Fixtures::AnotherClass }
  end

  test "a path for a block of autoloads can be specified" do
    module ::Fixtures
      autoload_at "fixtures/autoload/another_class" do
        autoload :AnotherClass
      end
    end

    assert !$LOADED_FEATURES.include?("fixtures/autoload/another_class.rb")
    assert_nothing_raised { ::Fixtures::AnotherClass }
  end
end