# frozen_string_literal: true

require_relative "abstract_unit"

class TestAutoloadModule < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  module ::Fixtures
    extend ActiveSupport::Autoload

    module Autoload
      extend ActiveSupport::Autoload
    end
  end

  def setup
    @some_class_path = File.expand_path("test/fixtures/autoload/some_class.rb")
    @another_class_path = File.expand_path("test/fixtures/autoload/another_class.rb")
    $LOAD_PATH << "test"
  end

  def teardown
    $LOAD_PATH.pop
  end

  test "the autoload module works like normal autoload" do
    module ::Fixtures::Autoload
      autoload :SomeClass, "fixtures/autoload/some_class"
    end

    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "when specifying an :eager constant it still works like normal autoload by default" do
    module ::Fixtures::Autoload
      eager_autoload do
        autoload :SomeClass, "fixtures/autoload/some_class"
      end
    end

    assert_not_includes $LOADED_FEATURES, @some_class_path
    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "the location of autoloaded constants defaults to :name.underscore" do
    module ::Fixtures::Autoload
      autoload :SomeClass
    end

    assert_not_includes $LOADED_FEATURES, @some_class_path
    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "the location of :eager autoloaded constants defaults to :name.underscore" do
    module ::Fixtures::Autoload
      eager_autoload do
        autoload :SomeClass
      end
    end

    assert_not_includes $LOADED_FEATURES, @some_class_path
    ::Fixtures::Autoload.eager_load!
    assert_includes $LOADED_FEATURES, @some_class_path
    assert_nothing_raised { ::Fixtures::Autoload::SomeClass }
  end

  test "a directory for a block of autoloads can be specified" do
    module ::Fixtures
      autoload_under "autoload" do
        autoload :AnotherClass
      end
    end

    assert_not_includes $LOADED_FEATURES, @another_class_path
    assert_nothing_raised { ::Fixtures::AnotherClass }
  end

  test "a path for a block of autoloads can be specified" do
    module ::Fixtures
      autoload_at "fixtures/autoload/another_class" do
        autoload :AnotherClass
      end
    end

    assert_not_includes $LOADED_FEATURES, @another_class_path
    assert_nothing_raised { ::Fixtures::AnotherClass }
  end
end
