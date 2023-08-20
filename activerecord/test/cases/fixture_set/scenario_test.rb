# frozen_string_literal: true

require "cases/helper"
require "tempfile"

module ActiveRecord
  class FixtureSet
    class ScenarioTest < ActiveRecord::TestCase
      def setup
        @path = ::File.join(SCENARIOS_ROOT, "/organisation_with_author_and_posts.yml")
        @scenario = Scenario.new(@path)
      end

      def test_sets
        scenario = <<~YAML
          organizations:
            _fixture:
              model_class: Organization
              ignore:
                - BASE
                - ARCHIVED

            ARCHIVED:
              name: archived

            BASE:
              name: base name

            code_monkeys:
              name: The code monkeys

          posts:
            <% 1.upto(3) do |i| %>
            alex_post<%= i %>:
              author: alex
              title: Alex post <%= i %>
              body: Such a lovely day
              type: Post
            <% end %>

          authors:
            _fixture:
              model_class: Author
              ignore: BASE

            BASE:
              name: Person's name

            alex:
              name: Alex
              author_address_id: 100
              organization: code_monkeys

          author_addresses:
            alex_address:
              id: 100
        YAML

        expected = {
          "organizations" => Config.new(
            table_name: "organizations",
            ignored_fixtures: ["BASE", "ARCHIVED"],
            model_class: "Organization",
            rows: {
              "code_monkeys" => { "name" => "The code monkeys" },
              "ARCHIVED" => { "name" => "archived" },
              "BASE" => { "name" => "base name" }
            }
          ),
          "authors" => Config.new(
            table_name: "authors",
            ignored_fixtures: "BASE",
            model_class: "Author",
            rows: {
              "alex" => {
                "name" => "Alex",
                "author_address_id" => 100,
                "organization" => "code_monkeys"
              },
              "BASE" => {
                "name" => "Person's name"
              }
            }
          ),
          "author_addresses" => Config.new(
            table_name: "author_addresses",
            ignored_fixtures: nil,
            model_class: nil,
            rows: { "alex_address" => { "id" => 100 } }
          ),
          "posts" => Config.new(
            table_name: "posts",
            ignored_fixtures: nil,
            model_class: nil,
            rows: {
              "alex_post1" => {
                "author" => "alex",
                "title" => "Alex post 1",
                "body" => "Such a lovely day",
                "type" => "Post"
              },
              "alex_post2" => {
                "author" => "alex",
                "title" => "Alex post 2",
                "body" => "Such a lovely day",
                "type" => "Post"
              },
              "alex_post3" => {
                "author" => "alex",
                "title" => "Alex post 3",
                "body" => "Such a lovely day",
                "type" => "Post"
              }
            }
          )
        }

        tmp_yaml ["full", "scenario", "yml"], scenario do |t|
          Scenario.open(t.path) do |fh|
            assert_equal expected, fh.to_h
          end
        end
      end

      def test_removes_fixture_config_row
        Scenario.open(@path) do |fh|
          assert fh.none? { |table_name, set| set.rows.include?("_fixture") }
        end
      end

      def test_extracts_model_class_from_config_row
        Scenario.open(@path) do |fh|
          assert_equal "Organization", fh["organizations"].model_class
        end
      end

      def test_extracts_ignored_fixtures_class_from_config_row
        yaml = <<~YAML
          organizations:
            _fixture:
              model_class: Organization
              ignore:
                - BASE
                - ARCHIVED_ORGANISATION
        YAML

        tmp_yaml ["config", "yml"], yaml do |t|
          Scenario.open(t.path) do |fh|
            assert_equal ["BASE", "ARCHIVED_ORGANISATION"], fh["organizations"].ignored_fixtures
          end
        end
      end

      def test_empty_file
        tmp_yaml ["empty", "yml"], "" do |t|
          assert_equal [], Scenario.open(t.path) { |fh| fh.to_a }
        end
      end

      # A valid YAML file is not necessarily a value Fixture file. Make sure
      # an exception is raised if the format is not valid Fixture format.
      def test_wrong_fixture_format_string
        tmp_yaml ["empty", "yml"], "qwerty" do |t|
          assert_raises(ActiveRecord::Fixture::FormatError) do
            Scenario.open(t.path) { |fh| fh.to_a }
          end
        end
      end

      def test_wrong_fixture_format_nested
        tmp_yaml ["empty", "yml"], "one: two" do |t|
          assert_raises(ActiveRecord::Fixture::FormatError) do
            Scenario.open(t.path) { |fh| fh.to_a }
          end
        end
      end

      def test_wrong_config_row
        tmp_yaml ["empty", "yml"], { "organizations" => { "_fixture" => { "class_name" => "Foo" } } }.to_yaml do |t|
          error = assert_raises(ActiveRecord::Fixture::FormatError) do
            Scenario.open(t.path) { |fh| fh.to_a }
          end
          assert_includes error.message, "Invalid `_fixture` section"
        end
      end

      def test_render_context_helper
        ActiveRecord::FixtureSet.context_class.class_eval do
          def fixture_helper
            "Fixture helper"
          end
        end

        yaml = <<~YAML
          organizations:
            one:
              name: <%= fixture_helper %>
        YAML

        tmp_yaml ["curious", "yml"], yaml do |t|
          golden = [["one", { "name" => "Fixture helper" }]]
          assert_equal golden, Scenario.open(t.path) { |fh| fh["organizations"].rows.to_a }
        end

        ActiveRecord::FixtureSet.context_class.class_eval do
          remove_method :fixture_helper
        end
      end

      def test_render_context_lookup_scope
        yaml = <<END
organizations:
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
          assert_equal golden, Scenario.open(t.path) { |fh| fh["organizations"].rows.to_a }
        end
      end

      # Make sure that each fixture gets its own rendering context so that
      # fixtures are independent.
      def test_independent_render_contexts
        yaml1 = "<% def leaked_method; 'leak'; end %>\n"
        yaml2 = "one:\n  name: <%= leaked_method %>\n"
        tmp_yaml ["leaky", "yml"], yaml1 do |t1|
          tmp_yaml ["curious", "yml"], yaml2 do |t2|
            Scenario.open(t1.path) { |fh| fh.to_a }
            assert_raises(NameError) do
              Scenario.open(t2.path) { |fh| fh.to_a }
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
