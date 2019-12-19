# frozen_string_literal: true

require "test_helper"

class JavascriptPackageTest < ActiveSupport::TestCase
  def test_compiled_code_is_in_sync_with_source_code
    compiled_file = File.expand_path("../app/assets/javascripts/action_cable.js", __dir__)

    assert_no_changes -> { File.read(compiled_file) } do
      system "yarn build"
    end
  end
end
