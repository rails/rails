# frozen_string_literal: true

class JavascriptPackageTest < ActiveSupport::TestCase
  def test_compiled_code_is_in_sync_with_source_code
    assert_no_changes -> {
      %w[
        app/assets/javascripts/rails-ujs.js
        app/assets/javascripts/rails-ujs.esm.js
      ].map { |compiled_file|
        File.read(File.expand_path("../#{compiled_file}", __dir__))
      }
    } do
      system "yarn build"
    end
  end
end
