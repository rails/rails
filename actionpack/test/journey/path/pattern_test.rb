require 'abstract_unit'

module ActionDispatch
  module Journey
    module Path
      class TestPattern < ActiveSupport::TestCase
        x = /.+/
        {
          '/:controller(/:action)'       => %r{\A/(#{x})(?:/([^/.?]+))?\Z},
          '/:controller/foo'             => %r{\A/(#{x})/foo\Z},
          '/:controller/:action'         => %r{\A/(#{x})/([^/.?]+)\Z},
          '/:controller'                 => %r{\A/(#{x})\Z},
          '/:controller(/:action(/:id))' => %r{\A/(#{x})(?:/([^/.?]+)(?:/([^/.?]+))?)?\Z},
          '/:controller/:action.xml'     => %r{\A/(#{x})/([^/.?]+)\.xml\Z},
          '/:controller.:format'         => %r{\A/(#{x})\.([^/.?]+)\Z},
          '/:controller(.:format)'       => %r{\A/(#{x})(?:\.([^/.?]+))?\Z},
          '/:controller/*foo'            => %r{\A/(#{x})/(.+)\Z},
          '/:controller/*foo/bar'        => %r{\A/(#{x})/(.+)/bar\Z},
        }.each do |path, expected|
          define_method(:"test_to_regexp_#{path}") do
            strexp = Router::Strexp.new(
              path,
              { :controller => /.+/ },
              ["/", ".", "?"]
            )
            path = Pattern.new strexp
            assert_equal(expected, path.to_regexp)
          end
        end

        {
          '/:controller(/:action)'       => %r{\A/(#{x})(?:/([^/.?]+))?},
          '/:controller/foo'             => %r{\A/(#{x})/foo},
          '/:controller/:action'         => %r{\A/(#{x})/([^/.?]+)},
          '/:controller'                 => %r{\A/(#{x})},
          '/:controller(/:action(/:id))' => %r{\A/(#{x})(?:/([^/.?]+)(?:/([^/.?]+))?)?},
          '/:controller/:action.xml'     => %r{\A/(#{x})/([^/.?]+)\.xml},
          '/:controller.:format'         => %r{\A/(#{x})\.([^/.?]+)},
          '/:controller(.:format)'       => %r{\A/(#{x})(?:\.([^/.?]+))?},
          '/:controller/*foo'            => %r{\A/(#{x})/(.+)},
          '/:controller/*foo/bar'        => %r{\A/(#{x})/(.+)/bar},
        }.each do |path, expected|
          define_method(:"test_to_non_anchored_regexp_#{path}") do
            strexp = Router::Strexp.new(
              path,
              { :controller => /.+/ },
              ["/", ".", "?"],
              false
            )
            path = Pattern.new strexp
            assert_equal(expected, path.to_regexp)
          end
        end

        {
          '/:controller(/:action)'       => %w{ controller action },
          '/:controller/foo'             => %w{ controller },
          '/:controller/:action'         => %w{ controller action },
          '/:controller'                 => %w{ controller },
          '/:controller(/:action(/:id))' => %w{ controller action id },
          '/:controller/:action.xml'     => %w{ controller action },
          '/:controller.:format'         => %w{ controller format },
          '/:controller(.:format)'       => %w{ controller format },
          '/:controller/*foo'            => %w{ controller foo },
          '/:controller/*foo/bar'        => %w{ controller foo },
        }.each do |path, expected|
          define_method(:"test_names_#{path}") do
            strexp = Router::Strexp.new(
              path,
              { :controller => /.+/ },
              ["/", ".", "?"]
            )
            path = Pattern.new strexp
            assert_equal(expected, path.names)
          end
        end

        def test_to_regexp_with_extended_group
          strexp = Router::Strexp.new(
            '/page/:name',
            { :name => /
              #ROFL
              (tender|love
              #MAO
              )/x },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          assert_match(path, '/page/tender')
          assert_match(path, '/page/love')
          assert_no_match(path, '/page/loving')
        end

        def test_optional_names
          [
            ['/:foo(/:bar(/:baz))', %w{ bar baz }],
            ['/:foo(/:bar)', %w{ bar }],
            ['/:foo(/:bar)/:lol(/:baz)', %w{ bar baz }],
          ].each do |pattern, list|
            path = Pattern.new pattern
            assert_equal list.sort, path.optional_names.sort
          end
        end

        def test_to_regexp_match_non_optional
          strexp = Router::Strexp.new(
            '/:name',
            { :name => /\d+/ },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          assert_match(path, '/123')
          assert_no_match(path, '/')
        end

        def test_to_regexp_with_group
          strexp = Router::Strexp.new(
            '/page/:name',
            { :name => /(tender|love)/ },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          assert_match(path, '/page/tender')
          assert_match(path, '/page/love')
          assert_no_match(path, '/page/loving')
        end

        def test_ast_sets_regular_expressions
          requirements = { :name => /(tender|love)/, :value => /./ }
          strexp = Router::Strexp.new(
            '/page/:name/:value',
            requirements,
            ["/", ".", "?"]
          )

          assert_equal requirements, strexp.requirements

          path = Pattern.new strexp
          nodes = path.ast.grep(Nodes::Symbol)
          assert_equal 2, nodes.length
          nodes.each do |node|
            assert_equal requirements[node.to_sym], node.regexp
          end
        end

        def test_match_data_with_group
          strexp = Router::Strexp.new(
            '/page/:name',
            { :name => /(tender|love)/ },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          match = path.match '/page/tender'
          assert_equal 'tender', match[1]
          assert_equal 2, match.length
        end

        def test_match_data_with_multi_group
          strexp = Router::Strexp.new(
            '/page/:name/:id',
            { :name => /t(((ender|love)))()/ },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          match = path.match '/page/tender/10'
          assert_equal 'tender', match[1]
          assert_equal '10', match[2]
          assert_equal 3, match.length
          assert_equal %w{ tender 10 }, match.captures
        end

        def test_star_with_custom_re
          z = /\d+/
          strexp = Router::Strexp.new(
            '/page/*foo',
            { :foo => z },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          assert_equal(%r{\A/page/(#{z})\Z}, path.to_regexp)
        end

        def test_insensitive_regexp_with_group
          strexp = Router::Strexp.new(
            '/page/:name/aaron',
            { :name => /(tender|love)/i },
            ["/", ".", "?"]
          )
          path = Pattern.new strexp
          assert_match(path, '/page/TENDER/aaron')
          assert_match(path, '/page/loVE/aaron')
          assert_no_match(path, '/page/loVE/AAron')
        end

        def test_to_regexp_with_strexp
          strexp = Router::Strexp.new('/:controller', { }, ["/", ".", "?"])
          path = Pattern.new strexp
          x = %r{\A/([^/.?]+)\Z}

          assert_equal(x.source, path.source)
        end

        def test_to_regexp_defaults
          path = Pattern.new '/:controller(/:action(/:id))'
          expected = %r{\A/([^/.?]+)(?:/([^/.?]+)(?:/([^/.?]+))?)?\Z}
          assert_equal expected, path.to_regexp
        end

        def test_failed_match
          path = Pattern.new '/:controller(/:action(/:id(.:format)))'
          uri = 'content'

          assert_not path =~ uri
        end

        def test_match_controller
          path = Pattern.new '/:controller(/:action(/:id(.:format)))'
          uri = '/content'

          match = path =~ uri
          assert_equal %w{ controller action id format }, match.names
          assert_equal 'content', match[1]
          assert_nil match[2]
          assert_nil match[3]
          assert_nil match[4]
        end

        def test_match_controller_action
          path = Pattern.new '/:controller(/:action(/:id(.:format)))'
          uri = '/content/list'

          match = path =~ uri
          assert_equal %w{ controller action id format }, match.names
          assert_equal 'content', match[1]
          assert_equal 'list', match[2]
          assert_nil match[3]
          assert_nil match[4]
        end

        def test_match_controller_action_id
          path = Pattern.new '/:controller(/:action(/:id(.:format)))'
          uri = '/content/list/10'

          match = path =~ uri
          assert_equal %w{ controller action id format }, match.names
          assert_equal 'content', match[1]
          assert_equal 'list', match[2]
          assert_equal '10', match[3]
          assert_nil match[4]
        end

        def test_match_literal
          path = Path::Pattern.new "/books(/:action(.:format))"

          uri = '/books'
          match = path =~ uri
          assert_equal %w{ action format }, match.names
          assert_nil match[1]
          assert_nil match[2]
        end

        def test_match_literal_with_action
          path = Path::Pattern.new "/books(/:action(.:format))"

          uri = '/books/list'
          match = path =~ uri
          assert_equal %w{ action format }, match.names
          assert_equal 'list', match[1]
          assert_nil match[2]
        end

        def test_match_literal_with_action_and_format
          path = Path::Pattern.new "/books(/:action(.:format))"

          uri = '/books/list.rss'
          match = path =~ uri
          assert_equal %w{ action format }, match.names
          assert_equal 'list', match[1]
          assert_equal 'rss', match[2]
        end
      end
    end
  end
end
