require 'abstract_unit'

class LoadPathTest < ActiveSupport::TestCase
  class ::Rails::Application < ::Rails::Engine
    alias :original_add_lib_to_load_path :add_lib_to_load_path!

    def add_lib_to_load_path!
      original_add_lib_to_load_path
      $triggered = true
    end
  end

  test "load path get updated when Rails::Application is inherited" do
    assert_nil $triggered

    class Foo < Rails::Application; end
    assert_not_nil $triggered
  end
end
