require 'action_view/helpers/tag_helper'
require 'html/document'

module ActionView
  module Helpers #:nodoc:
    # The SanitizeHelper module provides a set of methods for scrubbing text of undesired HTML elements.
    # These helper methods extend ActionView making them callable within your template files.
    module SanitizeHelper
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      # This #sanitize helper will html encode all tags and strip all attributes that aren't specifically allowed.  
      # It also strips href/src tags with invalid protocols, like javascript: especially.  It does its best to counter any
      # tricks that hackers may use, like throwing in unicode/ascii/hex values to get past the javascript: filters.  Check out
      # the extensive test suite.
      #
      #   <%= sanitize @article.body %>
      # 
      # You can add or remove tags/attributes if you want to customize it a bit.  See ActionView::Base for full docs on the
      # available options.  You can add tags/attributes for single uses of #sanitize by passing either the :attributes or :tags options:
      #
      # Normal Use
      #
      #   <%= sanitize @article.body %>
      #
      # Custom Use (only the mentioned tags and attributes are allowed, nothing else)
      #
      #   <%= sanitize @article.body, :tags => %w(table tr td), :attributes => %w(id class style)
      # 
      # Add table tags to the default allowed tags
      #   
      #   Rails::Initializer.run do |config|
      #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
      #   end
      # 
      # Remove tags to the default allowed tags
      #   
      #   Rails::Initializer.run do |config|
      #     config.after_initialize do
      #       ActionView::Base.sanitized_allowed_tags.delete 'div'
      #     end
      #   end
      # 
      # Change allowed default attributes
      # 
      #   Rails::Initializer.run do |config|
      #     config.action_view.sanitized_allowed_attributes = 'id', 'class', 'style'
      #   end
      # 
      def sanitize(html, options = {})
        self.class.white_list_sanitizer.sanitize(html, options)
      end

      # Sanitizes a block of css code.  Used by #sanitize when it comes across a style attribute
      def sanitize_css(style)
        self.class.white_list_sanitizer.sanitize_css(style)
      end

      # Strips all HTML tags from the +html+, including comments.  This uses the 
      # html-scanner tokenizer and so its HTML parsing ability is limited by 
      # that of html-scanner.
      #
      # ==== Examples
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
      # ==== Examples
      #   strip_links('<a href="http://www.rubyonrails.org">Ruby on Rails</a>')
      #   # => Ruby on Rails
      #
      #   strip_links('Please e-mail me at <a href="mailto:me@email.com">me@email.com</a>.')
      #   # => Please e-mail me at me@email.com.
      #
      #   strip_links('Blog: <a href="http://www.myblog.com/" class="nav" target=\"_blank\">Visit</a>.')
      #   # => Blog: Visit
      def strip_links(html)
        self.class.link_sanitizer.sanitize(html)
      end

      module ClassMethods #:nodoc:
        def self.extended(base)
          class << base
            attr_writer :full_sanitizer, :link_sanitizer, :white_list_sanitizer

            # we want these to be class methods on ActionView::Base, they'll get mattr_readers for these below.
            helper_def = [:sanitized_protocol_separator, :sanitized_uri_attributes, :sanitized_bad_tags, :sanitized_allowed_tags,
                :sanitized_allowed_attributes, :sanitized_allowed_css_properties, :sanitized_allowed_css_keywords,
                :sanitized_shorthand_css_properties, :sanitized_allowed_protocols, :sanitized_protocol_separator=].collect! do |prop|
              prop = prop.to_s
              "def #{prop}(#{:value if prop =~ /=$/}) white_list_sanitizer.#{prop.sub /sanitized_/, ''} #{:value if prop =~ /=$/} end"
            end.join("\n")
            eval helper_def
          end
        end
        
        # Gets the HTML::FullSanitizer instance used by strip_tags.  Replace with
        # any object that responds to #sanitize
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.full_sanitizer = MySpecialSanitizer.new
        #   end
        #
        def full_sanitizer
          @full_sanitizer ||= HTML::FullSanitizer.new
        end

        # Gets the HTML::LinkSanitizer instance used by strip_links.  Replace with
        # any object that responds to #sanitize
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.link_sanitizer = MySpecialSanitizer.new
        #   end
        #
        def link_sanitizer
          @link_sanitizer ||= HTML::LinkSanitizer.new
        end

        # Gets the HTML::WhiteListSanitizer instance used by sanitize and sanitize_css.
        # Replace with any object that responds to #sanitize
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.white_list_sanitizer = MySpecialSanitizer.new
        #   end
        #
        def white_list_sanitizer
          @white_list_sanitizer ||= HTML::WhiteListSanitizer.new
        end

        # Adds valid HTML attributes that the #sanitize helper checks for URIs.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_uri_attributes = 'lowsrc', 'target'
        #   end
        #
        def sanitized_uri_attributes=(attributes)
          HTML::WhiteListSanitizer.uri_attributes.merge(attributes)
        end

        # Adds to the Set of 'bad' tags for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_bad_tags = 'embed', 'object'
        #   end
        #
        def sanitized_bad_tags=(attributes)
          HTML::WhiteListSanitizer.bad_tags.merge(attributes)
        end
        # Adds to the Set of allowed tags for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
        #   end
        #
        def sanitized_allowed_tags=(attributes)
          HTML::WhiteListSanitizer.allowed_tags.merge(attributes)
        end

        # Adds to the Set of allowed html attributes for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_attributes = 'onclick', 'longdesc'
        #   end
        #
        def sanitized_allowed_attributes=(attributes)
          HTML::WhiteListSanitizer.allowed_attributes.merge(attributes)
        end

        # Adds to the Set of allowed css properties for the #sanitize and #sanitize_css heleprs.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_css_properties = 'expression'
        #   end
        #
        def sanitized_allowed_css_properties=(attributes)
          HTML::WhiteListSanitizer.allowed_css_properties.merge(attributes)
        end

        # Adds to the Set of allowed css keywords for the #sanitize and #sanitize_css helpers.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_css_keywords = 'expression'
        #   end
        #
        def sanitized_allowed_css_keywords=(attributes)
          HTML::WhiteListSanitizer.allowed_css_keywords.merge(attributes)
        end

        # Adds to the Set of allowed shorthand css properties for the #sanitize and #sanitize_css helpers.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_shorthand_css_properties = 'expression'
        #   end
        #
        def sanitized_shorthand_css_properties=(attributes)
          HTML::WhiteListSanitizer.shorthand_css_properties.merge(attributes)
        end

        # Adds to the Set of allowed protocols for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_protocols = 'ssh', 'feed'
        #   end
        #
        def sanitized_allowed_protocols=(attributes)
          HTML::WhiteListSanitizer.allowed_protocols.merge(attributes)
        end
      end
    end
  end
end
