# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/secret/secret_command"

class Rails::Command::SecretTest < ActiveSupport::TestCase
  test "generates a 128 character alphanumeric secret" do
    secret = "Z" * 128

    assert_called_with(SecureRandom, :alphanumeric, [128], returns: secret) do
      assert_output("#{secret}\n") { Rails::Command::SecretCommand.new.perform }
    end
  end
end
