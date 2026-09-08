# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/string"

module ActiveSupport
  class ERBUtilTest < ActiveSupport::TestCase
    def test_template_output
      source = "Posts: <%= @post.length %>"
      actual_tokens = tokenize source
      assert_equal [[:TEXT, "Posts: "], [:OPEN, "<%="], [:CODE, " @post.length "], [:CLOSE, "%>"]], actual_tokens
    end

    def test_multi_tag
      source = "Posts: <%= @post.length %> <% puts 'hi' %>"
      actual_tokens = tokenize source
      assert_equal [[:TEXT, "Posts: "],
                    [:OPEN, "<%="],
                    [:CODE, " @post.length "],
                    [:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
      ], actual_tokens
    end

    def test_multi_line
      source = "Posts: <%= @post.length %> <% puts 'hi' %>\nfoo <%"
      actual_tokens = tokenize source
      assert_equal [[:TEXT, "Posts: "],
                    [:OPEN, "<%="],
                    [:CODE, " @post.length "],
                    [:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
                    [:TEXT, "\nfoo "],
                    [:OPEN, "<%"],
      ], actual_tokens
    end

    def test_starts_with_newline
      source = "\nPosts: <%= @post.length %> <% puts 'hi' %>\nfoo <%"
      actual_tokens = tokenize source
      assert_equal [[:TEXT, "\nPosts: "],
                    [:OPEN, "<%="],
                    [:CODE, " @post.length "],
                    [:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
                    [:TEXT, "\nfoo "],
                    [:OPEN, "<%"],
      ], actual_tokens
    end

    def test_newline_inside_tag
      source = "Posts: <%= \n @post.length %> <% puts 'hi' %>\nfoo <%"
      actual_tokens = tokenize source
      assert_equal [[:TEXT, "Posts: "],
                    [:OPEN, "<%="],
                    [:CODE, " \n @post.length "],
                    [:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
                    [:TEXT, "\nfoo "],
                    [:OPEN, "<%"],
      ], actual_tokens
    end

    def test_start
      source = "<%= @post.length %> <% puts 'hi' %>"
      actual_tokens = tokenize source
      assert_equal [[:OPEN, "<%="],
                    [:CODE, " @post.length "],
                    [:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
      ], actual_tokens
    end

    def test_mid
      source = "@post.length %> <% puts 'hi' %>"
      actual_tokens = tokenize source
      assert_equal [[:CODE, "@post.length "],
                    [:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
      ], actual_tokens
    end

    def test_mid_start
      source = "%> <% puts 'hi' %>"
      actual_tokens = tokenize source
      assert_equal [[:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi' "],
                    [:CLOSE, "%>"],
      ], actual_tokens
    end

    def test_no_end
      source = "%> <% puts 'hi'"
      actual_tokens = tokenize source
      assert_equal [[:CLOSE, "%>"],
                    [:TEXT, " "],
                    [:OPEN, "<%"],
                    [:CODE, " puts 'hi'"],
      ], actual_tokens

      source = "<% puts 'hi'"
      actual_tokens = tokenize source
      assert_equal [[:OPEN, "<%"],
                    [:CODE, " puts 'hi'"],
      ], actual_tokens
    end

    def test_text_end
      source = "<%= @post.title %>   "
      actual_tokens = tokenize source
      assert_equal [[:OPEN, "<%="],
                    [:CODE, " @post.title "],
                    [:CLOSE, "%>"],
                    [:TEXT, "   "],
      ], actual_tokens
    end

    # This happens when a template is multiline and no
    # ERB tags are used on the current line.
    def test_plain_without_tags
      source = " @post.title\n"
      actual_tokens = tokenize source
      assert_equal [[:PLAIN, " @post.title"]], actual_tokens
    end

    def test_multibyte_characters_start
      source = "こんにちは<%= name %>"
      actual_tokens = tokenize source
      assert_equal [[:TEXT, "こんにちは"],
                    [:OPEN, "<%="],
                    [:CODE, " name "],
                    [:CLOSE, "%>"],
      ], actual_tokens
    end

    def test_multibyte_characters_end
      source = " 'こんにちは' %>"
      actual_tokens = tokenize source
      assert_equal [[:CODE, " 'こんにちは' "],
                    [:CLOSE, "%>"],
      ], actual_tokens
    end

    def tokenize(source)
      ERB::Util.tokenize source
    end
  end
end
