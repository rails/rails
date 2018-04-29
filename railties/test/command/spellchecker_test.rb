# frozen_string_literal: true

require "abstract_unit"
require "rails/command/spellchecker"

class Rails::Command::SpellcheckerTest < ActiveSupport::TestCase
  test "suggests a word correction from dictionary" do
    expected = defined?(DidYouMean::SpellChecker) ? "thin" : ""
    assert_equal expected, Rails::Command::Spellchecker.suggest("tin", from: %w(puma thin cgi))
  end
end
