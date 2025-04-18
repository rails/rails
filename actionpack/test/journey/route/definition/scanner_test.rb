# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    module Definition
      class TestScanner < ActiveSupport::TestCase
        def setup
          @scanner = Scanner.new
        end

        CASES = [
          ["/",       [:SLASH]],
          ["*omg",    [:STAR]],
          ["/page",   [:SLASH, :LITERAL]],
          ["/page!",  [:SLASH, :LITERAL]],
          ["/page$",  [:SLASH, :LITERAL]],
          ["/page&",  [:SLASH, :LITERAL]],
          ["/page'",  [:SLASH, :LITERAL]],
          ["/page*",  [:SLASH, :LITERAL]],
          ["/page+",  [:SLASH, :LITERAL]],
          ["/page,",  [:SLASH, :LITERAL]],
          ["/page;",  [:SLASH, :LITERAL]],
          ["/page=",  [:SLASH, :LITERAL]],
          ["/page@",  [:SLASH, :LITERAL]],
          ['/page\:', [:SLASH, :LITERAL]],
          ['/page\(', [:SLASH, :LITERAL]],
          ['/page\)', [:SLASH, :LITERAL]],
          ["/~page",  [:SLASH, :LITERAL]],
          ["/pa-ge",  [:SLASH, :LITERAL]],
          ["/:page",  [:SLASH, :SYMBOL]],
          ["/:page|*foo", [
                            :SLASH,
                            :SYMBOL,
                            :OR,
                            :STAR
                          ]],
          ["/(:page)", [
                        :SLASH,
                        :LPAREN,
                        :SYMBOL,
                        :RPAREN,
                      ]],
          ["(/:action)", [
                          :LPAREN,
                          :SLASH,
                          :SYMBOL,
                          :RPAREN,
                         ]],
          ["(())", [
                    :LPAREN,
                    :LPAREN,
                    :RPAREN,
                    :RPAREN,
                  ]],
          ["(.:format)", [
                          :LPAREN,
                          :DOT,
                          :SYMBOL,
                          :RPAREN,
                        ]],
          ["/sort::sort", [
                           :SLASH,
                           :LITERAL,
                           :LITERAL,
                           :SYMBOL
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
