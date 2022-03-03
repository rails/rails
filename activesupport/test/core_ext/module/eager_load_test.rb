# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/module/eager_load"

class EagerLoadTest < ActiveSupport::TestCase
  module TestModule
    autoload :DoesNotExist, "does/not/exist"
  end

  test "eager_load! trigger the load of autoloaded constants" do
    error = assert_raises LoadError do
      TestModule.eager_load!
    end
    assert_includes error.message, "does/not/exist"
  end
end
