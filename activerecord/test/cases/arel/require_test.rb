# frozen_string_literal: true

require_relative "helper"

module Arel
  class RequireTest < Arel::Test
    # Arel references ActiveSupport::Ractors at load time, so requiring it on its
    # own (as some libraries do for SQL inspection) must pull in that dependency.
    def test_arel_can_be_required_on_its_own
      arel_load_path = $LOAD_PATH.find { |path| File.exist?(File.join(path, "arel.rb")) }
      active_support_load_path = $LOAD_PATH.find { |path| File.exist?(File.join(path, "active_support/ractors.rb")) }

      output = IO.popen(
        [Gem.ruby, "-I", arel_load_path, "-I", active_support_load_path, "-e", 'require "arel"'],
        err: [:child, :out],
        &:read
      )

      assert_predicate $?, :success?, "Expected `require \"arel\"` to succeed on its own, but got:\n#{output}"
    end
  end
end
