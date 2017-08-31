# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    module Path
      class TestPattern < ActiveSupport::TestCase
        SEPARATORS = ["/", ".", "?"].join

        x = /.+/
        {
          "/:controller(/:action)"       => %r{\A/(#{x})(?:/([^/.?]+))?\Z},
          "/:controller/foo"             => %r{\A/(#{x})/foo\Z},
          "/:controller/:action"         => %r{\A/(#{x})/([^/.?]+)\Z},
          "/:controller"                 => %r{\A/(#{x})\Z},
          "/:controller(/:action(/:id))" => %r{\A/(#{x})(?:/([^/.?]+)(?:/([^/.?]+))?)?\Z},
          "/:controller/:action.xml"     => %r{\A/(#{x})/([^/.?]+)\.xml\Z},
          "/:controller.:format"         => %r{\A/(#{x})\.([^/.?]+)\Z},
          "/:controller(.:format)"       => %r{\A/(#{x})(?:\.([^/.?]+))?\Z},
          "/:controller/*foo"            => %r{\A/(#{x})/(.+)\Z},
          "/:controller/*foo/bar"        => %r{\A/(#{x})/(.+)/bar\Z},
          "/:foo|*bar"                   => %r{\A/(?:([^/.?]+)|(.+))\Z},
        }.each do |path, expected|
          define_method(:"test_to_regexp_#{Regexp.escape(path)}") do
            path = Pattern.build(
              path,
              { controller: /.+/ },
              SEPARATORS,
              true
            )
            assert_equal(expected, path.to_regexp)
          end
        end

        {
          "/:controller(/:action)"       => %r{\A/(#{x})(?:/([^/.?]+))?},
          "/:controller/foo"             => %r{\A/(#{x})/foo},
          "/:controller/:action"         => %r{\A/(#{x})/([^/.?]+)},
          "/:controller"                 => %r{\A/(#{x})},
          "/:controller(/:action(/:id))" => %r{\A/(#{x})(?:/([^/.?]+)(?:/([^/.?]+))?)?},
          "/:controller/:action.xml"     => %r{\A/(#{x})/([^/.?]+)\.xml},
          "/:controller.:format"         => %r{\A/(#{x})\.([^/.?]+)},
          "/:controller(.:format)"       => %r{\A/(#{x})(?:\.([^/.?]+))?},
          "/:controller/*foo"            => %r{\A/(#{x})/(.+)},
          "/:controller/*foo/bar"        => %r{\A/(#{x})/(.+)/bar},
          "/:foo|*bar"                   => %r{\A/(?:([^/.?]+)|(.+))},
        }.each do |path, expected|
          define_method(:"test_to_non_anchored_regexp_#{Regexp.escape(path)}") do
            path = Pattern.build(
              path,
              { controller: /.+/ },
              SEPARATORS,
              false
            )
            assert_equal(expected, path.to_regexp)
          end
        end

        {
          "/:controller(/:action)"       => %w{ controller action },
          "/:controller/foo"             => %w{ controller },
          "/:controller/:action"         => %w{ controller action },
          "/:controller"                 => %w{ controller },
          "/:controller(/:action(/:id))" => %w{ controller action id },
          "/:controller/:action.xml"     => %w{ controller action },
          "/:controller.:format"         => %w{ controller format },
          "/:controller(.:format)"       => %w{ controller format },
          "/:controller/*foo"            => %w{ controller foo },
          "/:controller/*foo/bar"        => %w{ controller foo },
        }.each do |path, expected|
          define_method(:"test_names_#{Regexp.escape(path)}") do
            path = Pattern.build(
              path,
              { controller: /.+/ },
              SEPARATORS,
              true
            )
            assert_equal(expected, path.names)
          end
        end

        def test_to_regexp_with_extended_group
          path = Pattern.build(
            "/page/:name",
            { name: /
              #ROFL
              (tender|love
              #MAO
              )/x },
            SEPARATORS,
            true
          )
          assert_match(path, "/page/tender")
          assert_match(path, "/page/love")
          assert_no_match(path, "/page/loving")
        end

        def test_optional_names
          [
            ["/:foo(/:bar(/:baz))", %w{ bar baz }],
            ["/:foo(/:bar)", %w{ bar }],
            ["/:foo(/:bar)/:lol(/:baz)", %w{ bar baz }],
          ].each do |pattern, list|
            path = Pattern.from_string pattern
            assert_equal list.sort, path.optional_names.sort
          end
        end

        def test_to_regexp_match_non_optional
          path = Pattern.build(
            "/:name",
            { name: /\d+/ },
            SEPARATORS,
            true
          )
          assert_match(path, "/123")
          assert_no_match(path, "/")
        end

        def test_to_regexp_with_group
          path = Pattern.build(
            "/page/:name",
            { name: /(tender|love)/ },
            SEPARATORS,
            true
          )
          assert_match(path, "/page/tender")
          assert_match(path, "/page/love")
          assert_no_match(path, "/page/loving")
        end

        def test_ast_sets_regular_expressions
          requirements = { name: /(tender|love)/, value: /./ }
          path = Pattern.build(
            "/page/:name/:value",
            requirements,
            SEPARATORS,
            true
          )

          nodes = path.ast.grep(Nodes::Symbol)
          assert_equal 2, nodes.length
          nodes.each do |node|
            assert_equal requirements[node.to_sym], node.regexp
          end
        end

        def test_match_data_with_group
          path = Pattern.build(
            "/page/:name",
            { name: /(tender|love)/ },
            SEPARATORS,
            true
          )
          match = path.match "/page/tender"
          assert_equal "tender", match[1]
          assert_equal 2, match.length
        end

        def test_match_data_with_multi_group
          path = Pattern.build(
            "/page/:name/:id",
            { name: /t(((ender|love)))()/ },
            SEPARATORS,
            true
          )
          match = path.match "/page/tender/10"
          assert_equal "tender", match[1]
          assert_equal "10", match[2]
          assert_equal 3, match.length
          assert_equal %w{ tender 10 }, match.captures
        end

        def test_star_with_custom_re
          z = /\d+/
          path = Pattern.build(
            "/page/*foo",
            { foo: z },
            SEPARATORS,
            true
          )
          assert_equal(%r{\A/page/(#{z})\Z}, path.to_regexp)
        end

        def test_insensitive_regexp_with_group
          path = Pattern.build(
            "/page/:name/aaron",
            { name: /(tender|love)/i },
            SEPARATORS,
            true
          )
          assert_match(path, "/page/TENDER/aaron")
          assert_match(path, "/page/loVE/aaron")
          assert_no_match(path, "/page/loVE/AAron")
        end

        def test_to_regexp_with_strexp
          path = Pattern.build("/:controller", {}, SEPARATORS, true)
          x = %r{\A/([^/.?]+)\Z}

          assert_equal(x.source, path.source)
        end

        def test_to_regexp_defaults
          path = Pattern.from_string "/:controller(/:action(/:id))"
          expected = %r{\A/([^/.?]+)(?:/([^/.?]+)(?:/([^/.?]+))?)?\Z}
          assert_equal expected, path.to_regexp
        end

        def test_failed_match
          path = Pattern.from_string "/:controller(/:action(/:id(.:format)))"
          uri = "content"

          assert_not path =~ uri
        end

        def test_match_controller
          path = Pattern.from_string "/:controller(/:action(/:id(.:format)))"
          uri = "/content"

          match = path =~ uri
          assert_equal %w{ controller action id format }, match.names
          assert_equal "content", match[1]
          assert_nil match[2]
          assert_nil match[3]
          assert_nil match[4]
        end

        def test_match_controller_action
          path = Pattern.from_string "/:controller(/:action(/:id(.:format)))"
          uri = "/content/list"

          match = path =~ uri
          assert_equal %w{ controller action id format }, match.names
          assert_equal "content", match[1]
          assert_equal "list", match[2]
          assert_nil match[3]
          assert_nil match[4]
        end

        def test_match_controller_action_id
          path = Pattern.from_string "/:controller(/:action(/:id(.:format)))"
          uri = "/content/list/10"

          match = path =~ uri
          assert_equal %w{ controller action id format }, match.names
          assert_equal "content", match[1]
          assert_equal "list", match[2]
          assert_equal "10", match[3]
          assert_nil match[4]
        end

        def test_match_literal
          path = Path::Pattern.from_string "/books(/:action(.:format))"

          uri = "/books"
          match = path =~ uri
          assert_equal %w{ action format }, match.names
          assert_nil match[1]
          assert_nil match[2]
        end

        def test_match_literal_with_action
          path = Path::Pattern.from_string "/books(/:action(.:format))"

          uri = "/books/list"
          match = path =~ uri
          assert_equal %w{ action format }, match.names
          assert_equal "list", match[1]
          assert_nil match[2]
        end

        def test_match_literal_with_action_and_format
          path = Path::Pattern.from_string "/books(/:action(.:format))"

          uri = "/books/list.rss"
          match = path =~ uri
          assert_equal %w{ action format }, match.names
          assert_equal "list", match[1]
          assert_equal "rss", match[2]
        end
      end
    end
  end
end
