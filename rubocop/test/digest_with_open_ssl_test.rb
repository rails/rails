# frozen_string_literal: true

require "abstract_unit"
require "rubocop"
require "rubocop/config"

module RuboCop
  module Linters
    class DigestWithOpenSSL < ::ActiveSupport::TestCase
      test "invalid syntax" do
        system_response = capture_subprocess_io do
          system("bundle exec rubocop rubocop/test/fixtures/incorrect_digest_open_ssl.rb")
        end
        assert(system_response.first.include?("5 offenses detected"))
      end

      test "valid syntax" do
        system_response = capture_subprocess_io do
          system("bundle exec rubocop rubocop/test/fixtures/correct_digest_open_ssl.rb")
        end
        assert(system_response.first.include?("no offenses detected"))
      end
    end
  end
end
