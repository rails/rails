# frozen_string_literal: true

require "rails-html-sanitizer"

module ActionView
  # = Action View Sanitize Helpers
  module Helpers #:nodoc:
    # The SanitizeHelper module provides a set of methods for scrubbing text of undesired HTML elements.
    # These helper methods extend Action View making them callable within your template files.
    module SanitizeHelper
      extend ActiveSupport::Concern
      # Sanitizes HTML input, stripping all but known-safe tags and attributes.
      #
      # It also strips href/src attributes with unsafe protocols like
      # <tt>javascript:</tt>, while also protecting against attempts to use Unicode,
      # ASCII, and hex character references to work around these protocol filters.
      # All special characters will be escaped.
      #
      # The default sanitizer is Rails::Html::SafeListSanitizer. See {Rails HTML
      # Sanitizers}[https://github.com/rails/rails-html-sanitizer] for more information.
      #
      # Custom sanitization rules can also be provided.
      #
      # Please note that sanitizing user-provided text does not guarantee that the
      # resulting markup is valid or even well-formed.
      #
      # ==== Options
      #
      # * <tt>:tags</tt> - An array of allowed tags.
      # * <tt>:attributes</tt> - An array of allowed attributes.
      # * <tt>:scrubber</tt> - A {Rails::Html scrubber}[https://github.com/rails/rails-html-sanitizer]
      #   or {Loofah::Scrubber}[https://github.com/flavorjones/loofah] object that
      #   defines custom sanitization rules. A custom scrubber takes precedence over
      #   custom tags and attributes.
      #
      # ==== Examples
      #
      # Normal use:
      #
      #   <%= sanitize @comment.body %>
      #
      # Providing custom lists of permitted tags and attributes:
      #
      #   <%= sanitize @comment.body, tags: %w(strong em a), attributes: %w(href) %>
      #
      # Providing a custom Rails::Html scrubber:
      #
      #   class CommentScrubber < Rails::Html::PermitScrubber
      #     def initialize
      #       super
      #       self.tags = %w( form script comment blockquote )
      #       self.attributes = %w( style )
      #     end
      #
      #     def skip_node?(node)
      #       node.text?
      #     end
      #   end
      #
      #   <%= sanitize @comment.body, scrubber: CommentScrubber.new %>
      #
      # See {Rails HTML Sanitizer}[https://github.com/rails/rails-html-sanitizer] for
      # documentation about Rails::Html scrubbers.
      #
      # Providing a custom Loofah::Scrubber:
      #
      #   scrubber = Loofah::Scrubber.new do |node|
      #     node.remove if node.name == 'script'
      #   end
      #
      #   <%= sanitize @comment.body, scrubber: scrubber %>
      #
      # See {Loofah's documentation}[https://github.com/flavorjones/loofah] for more
      # information about defining custom Loofah::Scrubber objects.
      #
      # To set the default allowed tags or attributes across your application:
      #
      #   # In config/application.rb
      #   config.action_view.sanitized_allowed_tags = ['strong', 'em', 'a']
      #   config.action_view.sanitized_allowed_attributes = ['href', 'title']
      def sanitize(html, options = {})
        self.class.safe_list_sanitizer.sanitize(html, options)&.html_safe
      end

      # Sanitizes a block of CSS code. Used by +sanitize+ when it comes across a style attribute.
      def sanitize_css(style)
        self.class.safe_list_sanitizer.sanitize_css(style)
      end

      # Strips all HTML tags from +html+, including comments and special characters.
      #
      #   strip_tags("Strip <i>these</i> tags!")
      #   # => Strip these tags!
      #
      #   strip_tags("<b>Bold</b> no more!  <a href='more.html'>See more here</a>...")
      #   # => Bold no more!  See more here...
      #
      #   strip_tags("<div id='top-bar'>Welcome to my website!</div>")
      #   # => Welcome to my website!
      #
      #   strip_tags("> A quote from Smith & Wesson")
      #   # => &gt; A quote from Smith &amp; Wesson
      def strip_tags(html)
        self.class.full_sanitizer.sanitize(html)
      end

      # Strips all link tags from +html+ leaving just the link text.
      #
      #   strip_links('<a href="http://www.rubyonrails.org">Ruby on Rails</a>')
      #   # => Ruby on Rails
      #
      #   strip_links('Please e-mail me at <a href="mailto:me@email.com">me@email.com</a>.')
      #   # => Please e-mail me at me@email.com.
      #
      #   strip_links('Blog: <a href="http://www.myblog.com/" class="nav" target=\"_blank\">Visit</a>.')
      #   # => Blog: Visit.
      #
      #   strip_links('<<a href="https://example.org">malformed & link</a>')
      #   # => &lt;malformed &amp; link
      def strip_links(html)
        self.class.link_sanitizer.sanitize(html)
      end

      module ClassMethods #:nodoc:
        attr_writer :full_sanitizer, :link_sanitizer, :safe_list_sanitizer

        def sanitizer_vendor
          Rails::Html::Sanitizer
        end

        def sanitized_allowed_tags
          safe_list_sanitizer.allowed_tags
        end

        def sanitized_allowed_attributes
          safe_list_sanitizer.allowed_attributes
        end

        # Gets the Rails::Html::FullSanitizer instance used by +strip_tags+. Replace with
        # any object that responds to +sanitize+.
        #
        #   class Application < Rails::Application
        #     config.action_view.full_sanitizer = MySpecialSanitizer.new
        #   end
        def full_sanitizer
          @full_sanitizer ||= sanitizer_vendor.full_sanitizer.new
        end

        # Gets the Rails::Html::LinkSanitizer instance used by +strip_links+.
        # Replace with any object that responds to +sanitize+.
        #
        #   class Application < Rails::Application
        #     config.action_view.link_sanitizer = MySpecialSanitizer.new
        #   end
        def link_sanitizer
          @link_sanitizer ||= sanitizer_vendor.link_sanitizer.new
        end

        # Gets the Rails::Html::SafeListSanitizer instance used by sanitize and +sanitize_css+.
        # Replace with any object that responds to +sanitize+.
        #
        #   class Application < Rails::Application
        #     config.action_view.safe_list_sanitizer = MySpecialSanitizer.new
        #   end
        def safe_list_sanitizer
          @safe_list_sanitizer ||= sanitizer_vendor.safe_list_sanitizer.new
        end
      end
    end
  end
end
