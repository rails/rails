require 'active_support/core_ext/object/try'
require 'active_support/deprecation'
require 'rails-html-sanitizer'

module ActionView
  # = Action View Sanitize Helpers
  module Helpers
    # The SanitizeHelper module provides a set of methods for scrubbing text of undesired HTML elements.
    # These helper methods extend Action View making them callable within your template files.
    module SanitizeHelper
      extend ActiveSupport::Concern
      # This +sanitize+ helper will html encode all tags and strip all attributes that
      # aren't specifically allowed.
      #
      # It also strips href/src tags with invalid protocols, like javascript: especially.
      # It does its best to counter any  tricks that hackers may use, like throwing in
      # unicode/ascii/hex values to get past the javascript: filters. Check out
      # the extensive test suite.
      #
      #   <%= sanitize @article.body %>
      #
      # You can add or remove tags/attributes if you want to customize it a bit.
      # See ActionView::Base for full docs on the available options. You can add
      # tags/attributes for single uses of +sanitize+ by passing either the
      # <tt>:attributes</tt> or <tt>:tags</tt> options:
      #
      # Normal Use
      #
      #   <%= sanitize @article.body %>
      #
      # Custom Use - Custom Scrubber
      # (supply a Loofah::Scrubber that does the sanitization)
      #
      # scrubber can either wrap a block:
      # scrubber = Loofah::Scrubber.new do |node|
      #   node.text = "dawn of cats"
      # end
      #
      # or be a subclass of Loofah::Scrubber which responds to scrub:
      # class KittyApocalypse < Loofah::Scrubber
      #   def scrub(node)
      #     node.text = "dawn of cats"
      #   end
      # end
      # scrubber = KittyApocalypse.new
      #
      # <%= sanitize @article.body, scrubber: scrubber %>
      #
      # A custom scrubber takes precedence over custom tags and attributes
      # Learn more about scrubbers here: https://github.com/flavorjones/loofah
      #
      # Custom Use - tags and attributes
      # (only the mentioned tags and attributes are allowed, nothing else)
      #
      #   <%= sanitize @article.body, tags: %w(table tr td), attributes: %w(id class style) %>
      #
      # Add table tags to the default allowed tags
      #
      #   class Application < Rails::Application
      #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
      #   end
      #
      # Remove tags to the default allowed tags
      #
      #   class Application < Rails::Application
      #     config.after_initialize do
      #       ActionView::Base.sanitized_allowed_tags.delete 'div'
      #     end
      #   end
      #
      # Change allowed default attributes
      #
      #   class Application < Rails::Application
      #     config.action_view.sanitized_allowed_attributes = ['id', 'class', 'style']
      #   end
      #
      # Please note that sanitizing user-provided text does not guarantee that the
      # resulting markup is valid (conforming to a document type) or even well-formed.
      # The output may still contain e.g. unescaped '<', '>', '&' characters and
      # confuse browsers.
      #
      def sanitize(html, options = {})
        self.class.white_list_sanitizer.sanitize(html, options).try(:html_safe)
      end

      # Sanitizes a block of CSS code. Used by +sanitize+ when it comes across a style attribute.
      def sanitize_css(style)
        self.class.white_list_sanitizer.sanitize_css(style)
      end

      # Strips all HTML tags from the +html+, including comments. This uses
      # Nokogiri for tokenization (via Loofah) and so its HTML parsing ability
      # is limited by that of Nokogiri.
      #
      #   strip_tags("Strip <i>these</i> tags!")
      #   # => Strip these tags!
      #
      #   strip_tags("<b>Bold</b> no more!  <a href='more.html'>See more here</a>...")
      #   # => Bold no more!  See more here...
      #
      #   strip_tags("<div id='top-bar'>Welcome to my website!</div>")
      #   # => Welcome to my website!
      def strip_tags(html)
        self.class.full_sanitizer.sanitize(html)
      end

      # Strips all link tags from +text+ leaving just the link text.
      #
      #   strip_links('<a href="http://www.rubyonrails.org">Ruby on Rails</a>')
      #   # => Ruby on Rails
      #
      #   strip_links('Please e-mail me at <a href="mailto:me@email.com">me@email.com</a>.')
      #   # => Please e-mail me at me@email.com.
      #
      #   strip_links('Blog: <a href="http://www.myblog.com/" class="nav" target=\"_blank\">Visit</a>.')
      #   # => Blog: Visit.
      def strip_links(html)
        self.class.link_sanitizer.sanitize(html)
      end

      module ClassMethods #:nodoc:
        attr_writer :full_sanitizer, :link_sanitizer, :white_list_sanitizer

        def sanitized_protocol_separator
          ActiveSupport::Deprecation.warn('protocol_separator has been deprecated and has no effect.')
        end

        def sanitized_uri_attributes
          white_list_sanitizer.uri_attributes
        end

        def sanitized_bad_tags
          ActiveSupport::Deprecation.warn('bad_tags has been deprecated and has no effect. You can still affect the tags being sanitized using Rails::Html::WhiteListSanitizer.bad_tags= which changes the allowed_tags.')
        end

        def sanitized_allowed_tags
          white_list_sanitizer.allowed_tags
        end

        def sanitized_allowed_attributes
          white_list_sanitizer.allowed_attributes
        end

        def sanitized_allowed_css_properties
          white_list_sanitizer.allowed_css_properties
        end

        def sanitized_allowed_css_keywords
          white_list_sanitizer.allowed_css_keywords
        end

        def sanitized_shorthand_css_properties
          white_list_sanitizer.shorthand_css_properties
        end

        def sanitized_allowed_protocols
          white_list_sanitizer.allowed_protocols
        end

        # Gets the Rails::Html::FullSanitizer instance used by +strip_tags+. Replace with
        # any object that responds to +sanitize+.
        #
        #   class Application < Rails::Application
        #     config.action_view.full_sanitizer = MySpecialSanitizer.new
        #   end
        #
        def full_sanitizer
          @full_sanitizer ||= Rails::Html::FullSanitizer.new
        end

        # Gets the Rails::Html::LinkSanitizer instance used by +strip_links+.
        # Replace with any object that responds to +sanitize+.
        #
        #   class Application < Rails::Application
        #     config.action_view.link_sanitizer = MySpecialSanitizer.new
        #   end
        #
        def link_sanitizer
          @link_sanitizer ||= Rails::Html::LinkSanitizer.new
        end

        # Gets the Rails::Html::WhiteListSanitizer instance used by sanitize and +sanitize_css+.
        # Replace with any object that responds to +sanitize+.
        #
        #   class Application < Rails::Application
        #     config.action_view.white_list_sanitizer = MySpecialSanitizer.new
        #   end
        #
        def white_list_sanitizer
          @white_list_sanitizer ||= Rails::Html::WhiteListSanitizer.new
        end


        def sanitized_protocol_separator=(value)
          ActiveSupport::Deprecation.warn('protocol_separator= has been deprecated and has no effect.')
        end

        # Adds valid HTML attributes that the +sanitize+ helper checks for URIs.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_uri_attributes = 'lowsrc', 'target'
        #   end
        #
        def sanitized_uri_attributes=(attributes)
          Rails::Html::WhiteListSanitizer.update_uri_attributes(attributes)
        end

        # Adds to the Set of 'bad' tags for the +sanitize+ helper.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_bad_tags = 'embed', 'object'
        #   end
        #
        def sanitized_bad_tags=(attributes)
          Rails::Html::WhiteListSanitizer.bad_tags = attributes
        end

        # Adds to the Set of allowed tags for the +sanitize+ helper.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
        #   end
        #
        def sanitized_allowed_tags=(attributes)
          Rails::Html::WhiteListSanitizer.update_allowed_tags(attributes)
        end

        # Adds to the Set of allowed HTML attributes for the +sanitize+ helper.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_allowed_attributes = ['onclick', 'longdesc']
        #   end
        #
        def sanitized_allowed_attributes=(attributes)
          Rails::Html::WhiteListSanitizer.update_allowed_attributes(attributes)
        end

        # Adds to the Set of allowed CSS properties for the #sanitize and +sanitize_css+ helpers.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_allowed_css_properties = 'expression'
        #   end
        #
        def sanitized_allowed_css_properties=(attributes)
          Rails::Html::WhiteListSanitizer.update_allowed_css_properties(attributes)
        end

        # Adds to the Set of allowed CSS keywords for the +sanitize+ and +sanitize_css+ helpers.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_allowed_css_keywords = 'expression'
        #   end
        #
        def sanitized_allowed_css_keywords=(attributes)
          Rails::Html::WhiteListSanitizer.update_allowed_css_keywords(attributes)
        end

        # Adds to the Set of allowed shorthand CSS properties for the +sanitize+ and +sanitize_css+ helpers.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_shorthand_css_properties = 'expression'
        #   end
        #
        def sanitized_shorthand_css_properties=(attributes)
          Rails::Html::WhiteListSanitizer.update_shorthand_css_properties(attributes)
        end

        # Adds to the Set of allowed protocols for the +sanitize+ helper.
        #
        #   class Application < Rails::Application
        #     config.action_view.sanitized_allowed_protocols = 'ssh', 'feed'
        #   end
        #
        def sanitized_allowed_protocols=(attributes)
          Rails::Html::WhiteListSanitizer.update_allowed_protocols(attributes)
        end
      end
    end
  end
end
