# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

class Rails::EnvsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "reads from envs" do
    app("production")

    ENV["MYSTERY"] = "hidden"
    assert_equal "hidden", Rails.app.envs.require(:mystery)

    ENV.delete("MYSTERY")
    Rails.app.envs.reload

    assert_raises(KeyError) do
      Rails.app.envs.require(:mystery)
    end
  ensure
    ENV.delete("MYSTERY")
  end
end
