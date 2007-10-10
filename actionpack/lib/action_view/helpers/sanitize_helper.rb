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
        return html if html.blank? || !html.include?('<')

        attrs = options[:attributes] || sanitized_allowed_attributes
        tags  = options[:tags]       || sanitized_allowed_tags

        returning [] do |new_text|
          tokenizer = HTML::Tokenizer.new(html)
          parent    = [] 

          while token = tokenizer.next
            node = HTML::Node.parse(nil, 0, 0, token, false)

            new_text << case node
              when HTML::Tag
                if node.closing == :close
                  parent.shift
                else
                  parent.unshift node.name
                end

                node.attributes.keys.each do |attr_name|
                  value = node.attributes[attr_name].to_s

                  if !attrs.include?(attr_name) || contains_bad_protocols?(attr_name, value)
                    node.attributes.delete(attr_name)
                  else
                    node.attributes[attr_name] = attr_name == 'style' ? sanitize_css(value) : CGI::escapeHTML(value)
                  end
                end if node.attributes

                tags.include?(node.name) ? node : nil
              else
                sanitized_bad_tags.include?(parent.first) ? nil : node.to_s.gsub(/</, "&lt;")
            end
          end
        end.join
      end

      # Sanitizes a block of css code.  Used by #sanitize when it comes across a style attribute
      def sanitize_css(style)
        # disallow urls
        style = style.to_s.gsub(/url\s*\(\s*[^\s)]+?\s*\)\s*/, ' ')

        # gauntlet
        if style !~ /^([:,;#%.\sa-zA-Z0-9!]|\w-\w|\'[\s\w]+\'|\"[\s\w]+\"|\([\d,\s]+\))*$/ ||
            style !~ /^(\s*[-\w]+\s*:\s*[^:;]*(;|$))*$/
          return ''
        end

        returning [] do |clean|
          style.scan(/([-\w]+)\s*:\s*([^:;]*)/) do |prop,val|
            if sanitized_allowed_css_properties.include?(prop.downcase)
              clean <<  prop + ': ' + val + ';'
            elsif sanitized_shorthand_css_properties.include?(prop.split('-')[0].downcase) 
              unless val.split().any? do |keyword|
                !sanitized_allowed_css_keywords.include?(keyword) && 
                  keyword !~ /^(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)$/
              end
                clean << prop + ': ' + val + ';'
              end
            end
          end
        end.join(' ')
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
        return html if html.blank? || !html.index("<")
        tokenizer = HTML::Tokenizer.new(html)

        text = returning [] do |text|
          while token = tokenizer.next
            node = HTML::Node.parse(nil, 0, 0, token, false)
            # result is only the content of any Text nodes
            text << node.to_s if node.class == HTML::Text  
          end
        end
        
        # strip any comments, and if they have a newline at the end (ie. line with
        # only a comment) strip that too
        result = text.join.gsub(/<!--(.*?)-->[\n]?/m, "")
        
        # Recurse - handle all dirty nested tags
        result == html ? result : strip_tags(result)
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
        if !html.blank? && (html.index("<a") || html.index("<href")) && html.index(">")
          tokenizer = HTML::Tokenizer.new(html)
          result = returning [] do |result|
            while token = tokenizer.next 
              node = HTML::Node.parse(nil, 0, 0, token, false) 
              result << node.to_s unless node.is_a?(HTML::Tag) && ["a", "href"].include?(node.name) 
            end 
          end.join
          result == html ? result : strip_links(result) # Recurse - handle all dirty nested links
        else
          html
        end
      end

      # A regular expression of the valid characters used to separate protocols like
      # the ':' in 'http://foo.com'
      @@sanitized_protocol_separator = /:|(&#0*58)|(&#x70)|(%|&#37;)3A/
      mattr_accessor :sanitized_protocol_separator, :instance_writer => false

      # Specifies a Set of HTML attributes that can have URIs.
      @@sanitized_uri_attributes = Set.new(%w(href src cite action longdesc xlink:href lowsrc))
      mattr_reader :sanitized_uri_attributes

      # Specifies a Set of 'bad' tags that the #sanitize helper will remove completely, as opposed
      # to just escaping harmless tags like &lt;font&gt;
      @@sanitized_bad_tags = Set.new(%w(script))
      mattr_reader :sanitized_bad_tags

      # Specifies the default Set of tags that the #sanitize helper will allow unscathed.
      @@sanitized_allowed_tags = Set.new(%w(strong em b i p code pre tt output samp kbd var sub 
        sup dfn cite big small address hr br div span h1 h2 h3 h4 h5 h6 ul ol li dt dd abbr 
        acronym a img blockquote del ins fieldset legend))
      mattr_reader :sanitized_allowed_tags

      # Specifies the default Set of html attributes that the #sanitize helper will leave 
      # in the allowed tag.
      @@sanitized_allowed_attributes = Set.new(%w(href src width height alt cite datetime title class name xml:lang abbr))
      mattr_reader :sanitized_allowed_attributes

      # Specifies the default Set of acceptable css properties that #sanitize and #sanitize_css will accept.
      @@sanitized_allowed_css_properties = Set.new(%w(azimuth background-color border-bottom-color border-collapse 
        border-color border-left-color border-right-color border-top-color clear color cursor direction display 
        elevation float font font-family font-size font-style font-variant font-weight height letter-spacing line-height
        overflow pause pause-after pause-before pitch pitch-range richness speak speak-header speak-numeral speak-punctuation
        speech-rate stress text-align text-decoration text-indent unicode-bidi vertical-align voice-family volume white-space
        width))
      mattr_reader :sanitized_allowed_css_properties

      # Specifies the default Set of acceptable css keywords that #sanitize and #sanitize_css will accept.
      @@sanitized_allowed_css_keywords = Set.new(%w(auto aqua black block blue bold both bottom brown center
        collapse dashed dotted fuchsia gray green !important italic left lime maroon medium none navy normal
        nowrap olive pointer purple red right solid silver teal top transparent underline white yellow))
      mattr_reader :sanitized_allowed_css_keywords

      # Specifies the default Set of allowed shorthand css properties for the #sanitize and #sanitize_css helpers.
      @@sanitized_shorthand_css_properties = Set.new(%w(background border margin padding))
      mattr_reader :sanitized_shorthand_css_properties

      # Specifies the default Set of protocols that the #sanitize helper will leave in
      # protocol attributes.
      @@sanitized_allowed_protocols = Set.new(%w(ed2k ftp http https irc mailto news gopher nntp telnet webcal xmpp callto feed svn urn aim rsync tag ssh sftp rtsp afs))
      mattr_reader :sanitized_allowed_protocols

      module ClassMethods #:nodoc:
        def self.extended(base)
          class << base
            # we want these to be class methods on ActionView::Base, they'll get mattr_readers for these below.
            [:sanitized_protocol_separator, :sanitized_uri_attributes, :sanitized_bad_tags, :sanitized_allowed_tags,
                :sanitized_allowed_attributes, :sanitized_allowed_css_properties, :sanitized_allowed_css_keywords,
                :sanitized_shorthand_css_properties, :sanitized_allowed_protocols, :sanitized_protocol_separator=].each do |prop|
              delegate prop, :to => SanitizeHelper
            end
          end
        end

        # Adds valid HTML attributes that the #sanitize helper checks for URIs.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_uri_attributes = 'lowsrc', 'target'
        #   end
        #
        def sanitized_uri_attributes=(attributes)
          Helpers::SanitizeHelper.sanitized_uri_attributes.merge(attributes)
        end

        # Adds to the Set of 'bad' tags for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_bad_tags = 'embed', 'object'
        #   end
        #
        def sanitized_bad_tags=(attributes)
          Helpers::SanitizeHelper.sanitized_bad_tags.merge(attributes)
        end
        # Adds to the Set of allowed tags for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
        #   end
        #
        def sanitized_allowed_tags=(attributes)
          Helpers::SanitizeHelper.sanitized_allowed_tags.merge(attributes)
        end

        # Adds to the Set of allowed html attributes for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_attributes = 'onclick', 'longdesc'
        #   end
        #
        def sanitized_allowed_attributes=(attributes)
          Helpers::SanitizeHelper.sanitized_allowed_attributes.merge(attributes)
        end

        # Adds to the Set of allowed css properties for the #sanitize and #sanitize_css heleprs.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_css_properties = 'expression'
        #   end
        #
        def sanitized_allowed_css_properties=(attributes)
          Helpers::SanitizeHelper.sanitized_allowed_css_properties.merge(attributes)
        end

        # Adds to the Set of allowed css keywords for the #sanitize and #sanitize_css helpers.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_css_keywords = 'expression'
        #   end
        #
        def sanitized_allowed_css_keywords=(attributes)
          Helpers::SanitizeHelper.sanitized_allowed_css_keywords.merge(attributes)
        end

        # Adds to the Set of allowed shorthand css properties for the #sanitize and #sanitize_css helpers.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_shorthand_css_properties = 'expression'
        #   end
        #
        def sanitized_shorthand_css_properties=(attributes)
          Helpers::SanitizeHelper.sanitized_shorthand_css_properties.merge(attributes)
        end

        # Adds to the Set of allowed protocols for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_protocols = 'ssh', 'feed'
        #   end
        #
        def sanitized_allowed_protocols=(attributes)
          Helpers::SanitizeHelper.sanitized_allowed_protocols.merge(attributes)
        end
      end

      private
        def contains_bad_protocols?(attr_name, value)
          sanitized_uri_attributes.include?(attr_name) && 
          (value =~ /(^[^\/:]*):|(&#0*58)|(&#x70)|(%|&#37;)3A/ && !sanitized_allowed_protocols.include?(value.split(sanitized_protocol_separator).first))
        end
    end
  end
end
