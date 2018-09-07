# frozen_string_literal: true

require "abstract_unit"
require "rails/command/spellchecker"

class Rails::Command::SpellcheckerTest < ActiveSupport::TestCase
  test "suggests a word correction from dictionary" do
    assert_equal "thin", Rails::Command::Spellchecker.suggest("tin", from: %w(puma thin cgi))
  end
end
