# frozen_string_literal: true

require "cases/helper"
require "tempfile"

module ActiveRecord
  class FixtureSet
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
        assert called, "block called"
      end

      def test_names
        File.open(::File.join(FIXTURES_ROOT, "accounts.yml")) do |fh|
          assert_equal ["signals37",
                        "unknown",
                        "rails_core_account",
                        "last_account",
                        "rails_core_account_2",
                        "odegy_account"].sort, fh.to_a.map(&:first).sort
        end
      end

      def test_values
        File.open(::File.join(FIXTURES_ROOT, "accounts.yml")) do |fh|
          assert_equal [1, 2, 3, 4, 5, 6].sort, fh.to_a.map(&:last).map { |x|
            x["id"]
          }.sort
        end
      end

      def test_erb_processing
        File.open(::File.join(FIXTURES_ROOT, "developers.yml")) do |fh|
          devs = Array.new(8) { |i| "dev_#{i + 3}" }
          assert_equal [], devs - fh.to_a.map(&:first)
        end
      end

      def test_empty_file
        tmp_yaml ["empty", "yml"], "" do |t|
          assert_equal [], File.open(t.path) { |fh| fh.to_a }
        end
      end

      # A valid YAML file is not necessarily a value Fixture file. Make sure
      # an exception is raised if the format is not valid Fixture format.
      def test_wrong_fixture_format_string
        tmp_yaml ["empty", "yml"], "qwerty" do |t|
          assert_raises(ActiveRecord::Fixture::FormatError) do
            File.open(t.path) { |fh| fh.to_a }
          end
        end
      end

      def test_wrong_fixture_format_nested
        tmp_yaml ["empty", "yml"], "one: two" do |t|
          assert_raises(ActiveRecord::Fixture::FormatError) do
            File.open(t.path) { |fh| fh.to_a }
          end
        end
      end

      def test_render_context_helper
        ActiveRecord::FixtureSet.context_class.class_eval do
          def fixture_helper
            "Fixture helper"
          end
        end
        yaml = "one:\n  name: <%= fixture_helper %>\n"
        tmp_yaml ["curious", "yml"], yaml do |t|
          golden =
              [["one", { "name" => "Fixture helper" }]]
          assert_equal golden, File.open(t.path) { |fh| fh.to_a }
        end
        ActiveRecord::FixtureSet.context_class.class_eval do
          remove_method :fixture_helper
        end
      end

      def test_render_context_lookup_scope
        yaml = <<END
one:
  ActiveRecord: <%= defined? ActiveRecord %>
  ActiveRecord_FixtureSet: <%= defined? ActiveRecord::FixtureSet %>
  FixtureSet: <%= defined? FixtureSet %>
  ActiveRecord_FixtureSet_File: <%= defined? ActiveRecord::FixtureSet::File %>
  File: <%= File.name %>
END

        golden = [["one", {
          "ActiveRecord" => "constant",
          "ActiveRecord_FixtureSet" => "constant",
          "FixtureSet" => nil,
          "ActiveRecord_FixtureSet_File" => "constant",
          "File" => "File"
        }]]

        tmp_yaml ["curious", "yml"], yaml do |t|
          assert_equal golden, File.open(t.path) { |fh| fh.to_a }
        end
      end

      # Make sure that each fixture gets its own rendering context so that
      # fixtures are independent.
      def test_independent_render_contexts
        yaml1 = "<% def leaked_method; 'leak'; end %>\n"
        yaml2 = "one:\n  name: <%= leaked_method %>\n"
        tmp_yaml ["leaky", "yml"], yaml1 do |t1|
          tmp_yaml ["curious", "yml"], yaml2 do |t2|
            File.open(t1.path) { |fh| fh.to_a }
            assert_raises(NameError) do
              File.open(t2.path) { |fh| fh.to_a }
            end
          end
        end
      end

      def test_removes_fixture_config_row
        File.open(::File.join(FIXTURES_ROOT, "other_posts.yml")) do |fh|
          assert_equal(["second_welcome"], fh.each.map { |name, _| name })
        end
      end

      def test_extracts_model_class_from_config_row
        File.open(::File.join(FIXTURES_ROOT, "other_posts.yml")) do |fh|
          assert_equal "Post", fh.model_class
        end
      end

      def test_erb_filename
        filename = "filename.yaml"
        erb = File.new(filename).send(:prepare_erb, "<% Rails.env %>\n")
        assert_equal erb.filename, filename
      end

      private
        def tmp_yaml(name, contents)
          t = Tempfile.new name
          t.binmode
          t.write contents
          t.close
          yield t
        ensure
          t.close true
        end
    end
  end
end
