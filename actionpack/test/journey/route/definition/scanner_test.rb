# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    module Definition
      class TestScanner < ActiveSupport::TestCase
        def setup
          @scanner = Scanner.new
        end

        # /page/:id(/:action)(.:format)
        def test_tokens
          [
            ["/",       [[:SLASH, "/"]]],
            ["*omg",    [[:STAR, "*omg"]]],
            ["/page",   [[:SLASH, "/"], [:LITERAL, "page"]]],
            ["/page!",  [[:SLASH, "/"], [:LITERAL, "page!"]]],
            ["/page$",  [[:SLASH, "/"], [:LITERAL, "page$"]]],
            ["/page&",  [[:SLASH, "/"], [:LITERAL, "page&"]]],
            ["/page'",  [[:SLASH, "/"], [:LITERAL, "page'"]]],
            ["/page*",  [[:SLASH, "/"], [:LITERAL, "page*"]]],
            ["/page+",  [[:SLASH, "/"], [:LITERAL, "page+"]]],
            ["/page,",  [[:SLASH, "/"], [:LITERAL, "page,"]]],
            ["/page;",  [[:SLASH, "/"], [:LITERAL, "page;"]]],
            ["/page=",  [[:SLASH, "/"], [:LITERAL, "page="]]],
            ["/page@",  [[:SLASH, "/"], [:LITERAL, "page@"]]],
            ['/page\:', [[:SLASH, "/"], [:LITERAL, "page:"]]],
            ['/page\(', [[:SLASH, "/"], [:LITERAL, "page("]]],
            ['/page\)', [[:SLASH, "/"], [:LITERAL, "page)"]]],
            ["/~page",  [[:SLASH, "/"], [:LITERAL, "~page"]]],
            ["/pa-ge",  [[:SLASH, "/"], [:LITERAL, "pa-ge"]]],
            ["/:page",  [[:SLASH, "/"], [:SYMBOL, ":page"]]],
            ["/(:page)", [
                          [:SLASH, "/"],
                          [:LPAREN, "("],
                          [:SYMBOL, ":page"],
                          [:RPAREN, ")"],
                        ]],
            ["(/:action)", [
                            [:LPAREN, "("],
                            [:SLASH, "/"],
                            [:SYMBOL, ":action"],
                            [:RPAREN, ")"],
                           ]],
            ["(())", [[:LPAREN, "("],
                     [:LPAREN, "("], [:RPAREN, ")"], [:RPAREN, ")"]]],
            ["(.:format)", [
                            [:LPAREN, "("],
                            [:DOT, "."],
                            [:SYMBOL, ":format"],
                            [:RPAREN, ")"],
                          ]],
          ].each do |str, expected|
            @scanner.scan_setup str
            assert_tokens expected, @scanner
          end
        end

        def assert_tokens(tokens, scanner)
          toks = []
          while tok = scanner.next_token
            toks << tok
          end
          assert_equal tokens, toks
        end
      end
    end
  end
end
