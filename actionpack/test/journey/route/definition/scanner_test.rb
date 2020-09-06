# frozen_string_literal: true

require 'abstract_unit'

module ActionDispatch
  module Journey
    module Definition
      class TestScanner < ActiveSupport::TestCase
        def setup
          @scanner = Scanner.new
        end

        CASES = [
          ['/',       [[:SLASH, '/']]],
          ['*omg',    [[:STAR, '*omg']]],
          ['/page',   [[:SLASH, '/'], [:LITERAL, 'page']]],
          ['/page!',  [[:SLASH, '/'], [:LITERAL, 'page!']]],
          ['/page$',  [[:SLASH, '/'], [:LITERAL, 'page$']]],
          ['/page&',  [[:SLASH, '/'], [:LITERAL, 'page&']]],
          ["/page'",  [[:SLASH, '/'], [:LITERAL, "page'"]]],
          ['/page*',  [[:SLASH, '/'], [:LITERAL, 'page*']]],
          ['/page+',  [[:SLASH, '/'], [:LITERAL, 'page+']]],
          ['/page,',  [[:SLASH, '/'], [:LITERAL, 'page,']]],
          ['/page;',  [[:SLASH, '/'], [:LITERAL, 'page;']]],
          ['/page=',  [[:SLASH, '/'], [:LITERAL, 'page=']]],
          ['/page@',  [[:SLASH, '/'], [:LITERAL, 'page@']]],
          ['/page\:', [[:SLASH, '/'], [:LITERAL, 'page:']]],
          ['/page\(', [[:SLASH, '/'], [:LITERAL, 'page(']]],
          ['/page\)', [[:SLASH, '/'], [:LITERAL, 'page)']]],
          ['/~page',  [[:SLASH, '/'], [:LITERAL, '~page']]],
          ['/pa-ge',  [[:SLASH, '/'], [:LITERAL, 'pa-ge']]],
          ['/:page',  [[:SLASH, '/'], [:SYMBOL, ':page']]],
          ['/:page|*foo', [
                            [:SLASH, '/'],
                            [:SYMBOL, ':page'],
                            [:OR, '|'],
                            [:STAR, '*foo']
                          ]],
          ['/(:page)', [
                        [:SLASH, '/'],
                        [:LPAREN, '('],
                        [:SYMBOL, ':page'],
                        [:RPAREN, ')'],
                      ]],
          ['(/:action)', [
                          [:LPAREN, '('],
                          [:SLASH, '/'],
                          [:SYMBOL, ':action'],
                          [:RPAREN, ')'],
                         ]],
          ['(())', [[:LPAREN, '('],
                   [:LPAREN, '('], [:RPAREN, ')'], [:RPAREN, ')']]],
          ['(.:format)', [
                          [:LPAREN, '('],
                          [:DOT, '.'],
                          [:SYMBOL, ':format'],
                          [:RPAREN, ')'],
                        ]],
        ]

        CASES.each do |pattern, expected_tokens|
          test "Scanning `#{pattern}`" do
            @scanner.scan_setup pattern
            assert_tokens expected_tokens, @scanner, pattern
          end
        end

        private
          def assert_tokens(expected_tokens, scanner, pattern)
            actual_tokens = []
            while token = scanner.next_token
              actual_tokens << token
            end
            assert_equal expected_tokens, actual_tokens, "Wrong tokens for `#{pattern}`"
          end
      end
    end
  end
end
