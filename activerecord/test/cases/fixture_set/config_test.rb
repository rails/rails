# frozen_string_literal: true

require "cases/helper"
require "tempfile"

module ActiveRecord
  class FixtureSet
    class ConfigRowTest < ActiveRecord::TestCase
      def test_validate_config_row_with_valid_keys
        assert Config.validate_config_row("filename.yml", { "model_class" => "Foo", "ignore" => ["Bar"] })
      end

      def test_validate_config_row_with_unknown_key
        error = assert_raises(ActiveRecord::Fixture::FormatError) do
          Config.validate_config_row("filename.yml", { "class_name" => "Foo" })
        end
        assert_equal "Invalid `_fixture` section: Unknown key: \"class_name\". Valid keys are: \"model_class\", \"ignore\": filename.yml", error.message
      end

      def test_validate_config_row_with_invalid_data_foramt
        error = assert_raises(ActiveRecord::Fixture::FormatError) do
          Config.validate_config_row("filename.yml", [{ "model_class" => "Foo", "ignore" => ["Bar"] }])
        end
        assert_equal "Invalid `_fixture` section: `_fixture` must be a hash: filename.yml", error.message
      end
    end

    class ConfigReadFixtureFileTest < ActiveRecord::TestCase
      def test_erb_processing
        result = Config.read_fixture_file(::File.join(FIXTURES_ROOT, "developers.yml"))

        devs = Array.new(8) { |i| "dev_#{i + 3}" }

        assert_equal [], devs - result.map(&:first)
      end

      def test_empty_file
        tmp_yaml ["empty", "yml"], "" do |t|
          assert_equal [], Config.read_fixture_file(t.path)
        end
      end

      # A valid YAML file is not necessarily a value Fixture file. Make sure
      # an exception is raised if the format is not valid Fixture format.
      def test_wrong_fixture_format_string
        tmp_yaml ["empty", "yml"], "qwerty" do |t|
          assert_raises(ActiveRecord::Fixture::FormatError) do
            Config.read_fixture_file(t.path)
          end
        end
      end

      def test_wrong_fixture_format_nested
        tmp_yaml ["empty", "yml"], "one: two" do |t|
          assert_raises(ActiveRecord::Fixture::FormatError) do
            Config.read_fixture_file(t.path)
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
          golden = [["one", { "name" => "Fixture helper" }]]
          assert_equal golden, Config.read_fixture_file(t.path)
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
          assert_equal golden, Config.read_fixture_file(t.path)
        end
      end

      # Make sure that each fixture gets its own rendering context so that
      # fixtures are independent.
      def test_independent_render_contexts
        yaml1 = "<% def leaked_method; 'leak'; end %>\n"
        yaml2 = "one:\n  name: <%= leaked_method %>\n"
        tmp_yaml ["leaky", "yml"], yaml1 do |t1|
          tmp_yaml ["curious", "yml"], yaml2 do |t2|
            Config.read_fixture_file(t1.path)
            assert_raises(NameError) do
              Config.read_fixture_file(t2.path)
            end
          end
        end
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
