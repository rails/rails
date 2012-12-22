require 'abstract_unit'

module ActionDispatch
  module Journey
    class Router
      class TestStrexp < MiniTest::Unit::TestCase
        def test_many_names
          exp = Strexp.new(
            "/:controller(/:action(/:id(.:format)))",
            {:controller=>/.+?/},
            ["/", ".", "?"],
            true)

          assert_equal ["controller", "action", "id", "format"], exp.names
        end

        def test_names
          {
            "/bar(.:format)"    => %w{ format },
            ":format"           => %w{ format },
            ":format-"          => %w{ format },
            ":format0"          => %w{ format0 },
            ":format1,:format2" => %w{ format1 format2 },
          }.each do |string, expected|
            exp = Strexp.new(string, {}, ["/", ".", "?"])
            assert_equal expected, exp.names
          end
        end
      end
    end
  end
end
