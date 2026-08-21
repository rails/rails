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
          ["/",       [:SLASH].freeze].freeze,
          ["*omg",    [:STAR].freeze].freeze,
          ["/page",   [:SLASH, :LITERAL].freeze].freeze,
          ["/page!",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page$",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page&",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page'",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page*",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page+",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page,",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page;",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page=",  [:SLASH, :LITERAL].freeze].freeze,
          ["/page@",  [:SLASH, :LITERAL].freeze].freeze,
          ['/page\:', [:SLASH, :LITERAL].freeze].freeze,
          ['/page\(', [:SLASH, :LITERAL].freeze].freeze,
          ['/page\)', [:SLASH, :LITERAL].freeze].freeze,
          ["/~page",  [:SLASH, :LITERAL].freeze].freeze,
          ["/pa-ge",  [:SLASH, :LITERAL].freeze].freeze,
          ["/:page",  [:SLASH, :SYMBOL].freeze].freeze,
          ["/:page|*foo", [
                            :SLASH,
                            :SYMBOL,
                            :OR,
                            :STAR
                          ].freeze].freeze,
          ["/(:page)", [
                        :SLASH,
                        :LPAREN,
                        :SYMBOL,
                        :RPAREN,
                      ].freeze].freeze,
          ["(/:action)", [
                          :LPAREN,
                          :SLASH,
                          :SYMBOL,
                          :RPAREN,
                         ].freeze].freeze,
          ["(())", [
                    :LPAREN,
                    :LPAREN,
                    :RPAREN,
                    :RPAREN,
                  ].freeze].freeze,
          ["(.:format)", [
                          :LPAREN,
                          :DOT,
                          :SYMBOL,
                          :RPAREN,
                        ].freeze].freeze,
          ["/sort::sort", [
                           :SLASH,
                           :LITERAL,
                           :LITERAL,
                           :SYMBOL
                         ].freeze].freeze,
        ].freeze

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
