require "cases/helper"
require 'tempfile'

module ActiveRecord
  class Fixtures
    class FileTest < ActiveRecord::TestCase
      def test_open
        fh = File.open(::File.join(FIXTURES_ROOT, "accounts.yml"))
        assert_equal 6, fh.to_a.length
      end

      def test_open_with_block
        called = false
        File.open(::File.join(FIXTURES_ROOT, "accounts.yml")) do |fh|
          called = true
          assert_equal 6, fh.to_a.length
        end
        assert called, 'block called'
      end

      def test_names
        File.open(::File.join(FIXTURES_ROOT, "accounts.yml")) do |fh|
          assert_equal ["signals37",
                        "unknown",
                        "rails_core_account",
                        "last_account",
                        "rails_core_account_2",
                        "odegy_account"], fh.to_a.map(&:first)
        end
      end

      def test_values
        File.open(::File.join(FIXTURES_ROOT, "accounts.yml")) do |fh|
          assert_equal [1,2,3,4,5,6], fh.to_a.map(&:last).map { |x| x['id'] }
        end
      end

      def test_erb_processing
        File.open(::File.join(FIXTURES_ROOT, "developers.yml")) do |fh|
          devs = Array.new(8) { |i| "dev_#{i + 3}" }
          assert_equal [], devs - fh.to_a.map(&:first)
        end
      end
    end
  end
end
