# frozen_string_literal: true

require "test_helper"

class JavascriptPackageTest < ActiveSupport::TestCase
  def test_compiled_code_is_in_sync_with_source_code
    compiled_file = File.expand_path("../app/assets/javascripts/action_cable.js", __dir__)
    original_compiled_code = File.read(compiled_file)

    system "yarn build"

    rebuilt_compiled_code = File.read(compiled_file)
    assert_equal original_compiled_code, rebuilt_compiled_code
  end
end
