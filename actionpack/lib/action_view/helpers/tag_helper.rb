require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/output_safety'
require 'set'

module ActionView
  # = Action View Tag Helpers
  module Helpers #:nodoc:
    # Provides methods to generate HTML tags programmatically when you can't use
    # a Builder. By default, they output XHTML compliant tags.
    module TagHelper
      extend ActiveSupport::Concern
      include CaptureHelper

      BOOLEAN_ATTRIBUTES = %w(disabled readonly multiple checked autobuffer
                           autoplay controls loop selected hidden scoped async
                           defer reversed ismap seemless muted required
                           autofocus novalidate formnovalidate open pubdate).to_set
      BOOLEAN_ATTRIBUTES.merge(BOOLEAN_ATTRIBUTES.map {|attribute| attribute.to_sym })

      # Returns an empty HTML tag of type +name+ which by default is XHTML
      # compliant. Set +open+ to true to create an open tag compatible
      # with HTML 4.0 and below. Add HTML attributes by passing an attributes
      # hash to +options+. Set +escape+ to false to disable attribute value
      # escaping.
      #
      # ==== Options
      # You can use symbols or strings for the attribute names.
      #
      # Use +true+ with boolean attributes that can render with no value, like
      # +disabled+ and +readonly+.
      #
      # HTML5 <tt>data-*</tt> attributes can be set with a single +data+ key
      # pointing to a hash of sub-attributes.
      #
      # To play nicely with JavaScript conventions sub-attributes are dasherized.
      # For example, a key +user_id+ would render as <tt>data-user-id</tt> and
      # thus accessed as <tt>dataset.userId</tt>.
      #
      # Values are encoded to JSON, with the exception of strings and symbols.
      # This may come in handy when using jQuery's HTML5-aware <tt>.data()<tt>
      # from 1.4.3.
      #
      # ==== Examples
      #   tag("br")
      #   # => <br />
      #
      #   tag("br", nil, true)
      #   # => <br>
      #
      #   tag("input", :type => 'text', :disabled => true)
      #   # => <input type="text" disabled="disabled" />
      #
      #   tag("img", :src => "open & shut.png")
      #   # => <img src="open &amp; shut.png" />
      #
      #   tag("img", {:src => "open &amp; shut.png"}, false, false)
      #   # => <img src="open &amp; shut.png" />
      #
      #   tag("div", :data => {:name => 'Stephen', :city_state => %w(Chicago IL)})
      #   # => <div data-name="Stephen" data-city-state="[&quot;Chicago&quot;,&quot;IL&quot;]" />
      def tag(name, options = nil, open = false, escape = true)
        "<#{name}#{tag_options(options, escape) if options}#{open ? ">" : " />"}".html_safe
      end

      # Returns an HTML block tag of type +name+ surrounding the +content+. Add
      # HTML attributes by passing an attributes hash to +options+.
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +options+ as the second parameter.
      # Set escape to false to disable attribute value escaping.
      #
      # ==== Options
      # The +options+ hash is used with attributes with no value like (<tt>disabled</tt> and
      # <tt>readonly</tt>), which you can give a value of true in the +options+ hash. You can use
      # symbols or strings for the attribute names.
      #
      # ==== Examples
      #   content_tag(:p, "Hello world!")
      #    # => <p>Hello world!</p>
      #   content_tag(:div, content_tag(:p, "Hello world!"), :class => "strong")
      #    # => <div class="strong"><p>Hello world!</p></div>
      #   content_tag("select", options, :multiple => true)
      #    # => <select multiple="multiple">...options...</select>
      #
      #   <%= content_tag :div, :class => "strong" do -%>
      #     Hello world!
      #   <% end -%>
      #    # => <div class="strong">Hello world!</div>
      def content_tag(name, content_or_options_with_block = nil, options = nil, escape = true, &block)
        if block_given?
          options = content_or_options_with_block if content_or_options_with_block.is_a?(Hash)
          content_tag_string(name, capture(&block), options, escape)
        else
          content_tag_string(name, content_or_options_with_block, options, escape)
        end
      end

      # Returns a CDATA section with the given +content+.  CDATA sections
      # are used to escape blocks of text containing characters which would
      # otherwise be recognized as markup. CDATA sections begin with the string
      # <tt><![CDATA[</tt> and end with (and may not contain) the string <tt>]]></tt>.
      #
      # ==== Examples
      #   cdata_section("<hello world>")
      #   # => <![CDATA[<hello world>]]>
      #
      #   cdata_section(File.read("hello_world.txt"))
      #   # => <![CDATA[<hello from a text file]]>
      def cdata_section(content)
        "<![CDATA[#{content}]]>".html_safe
      end

      # Returns an escaped version of +html+ without affecting existing escaped entities.
      #
      # ==== Examples
      #   escape_once("1 < 2 &amp; 3")
      #   # => "1 &lt; 2 &amp; 3"
      #
      #   escape_once("&lt;&lt; Accept & Checkout")
      #   # => "&lt;&lt; Accept &amp; Checkout"
      def escape_once(html)
        ActiveSupport::Multibyte.clean(html.to_s).gsub(/[\"><]|&(?!([a-zA-Z]+|(#\d+));)/) { |special| ERB::Util::HTML_ESCAPE[special] }
      end

      # Adds one or more css classes to a string of css classes
      # This method guards against nil and duplicate classes.
      #
      # Strings or symbols may be passed in, but this method always returns a string.
      #
      # Examples:
      # add_css_class(nil,"myclass")
      # => "myclass"
      # add_css_class("existing","new")
      # => "existing new"
      # add_css_class("another existing","existing","new")
      # => "another existing new"
      def add_css_class(*classes)
        classes.flatten.compact.map{|c| c.to_s.strip.split(/\s+/)}.flatten.uniq.sort.join(" ")
      end

      # merge with_attrs into the original_attrs.
      # making sure to merge existing attributes instead of overwriting them.
      #
      # original_attrs = {}
      # merge_tag_attributes!(original_attrs, :id => "special", :class => "foo", :style => "color: red;")
      # => {:id => "special", :class => "foo", :style => "color: red;"}
      #
      # A second call:
      # merge_tag_attributes!(:id => "more-special", :class => "bar", :style => "background-color: #ccc;")
      # => {:id => "more-special", :class => "bar foo", :style => "color: red; background-color: #ccc;"}
      #
      # The following attributes are merged instead of being overwritten:
      #   * :class - class attributes are merged with the add_css_class method.
      #   * :style - style attributes are merged with a semi-colon separator
      #   * :onanything - Anything starting with `on` is merged like javascript.
      #
      # Otherwise, the attribute is overwritten by the value in with_attrs.
      def merge_tag_attributes!(original_attrs, with_attrs)
        original_attrs ||= {}
        return original_attrs unless with_attrs
        original_attrs.merge!(with_attrs) do |k, v1, v2|
          case k.to_s
          when "class"
            add_css_class(v1, v2)
          when "style", /^on/
            [v1, v2].compact.map{|a| a.sub(/;\s*$/,"")}.join("; ")
          else
            v2
          end
        end
      end

      # Returns a new hash that has merged original_attrs with with_attrs.
      # See merge_tag_attributes! for more information.
      def merge_tag_attributes(original_attrs, with_attrs)
        merge_tag_attributes!(original_attrs && original_attrs.dup || {}, with_attrs)
      end

      private

        def content_tag_string(name, content, options, escape = true)
          tag_options = tag_options(options, escape) if options
          "<#{name}#{tag_options}>#{escape ? ERB::Util.h(content) : content}</#{name}>".html_safe
        end

        def tag_options(options, escape = true)
          unless options.blank?
            attrs = []
            options.each_pair do |key, value|
              if key.to_s == 'data' && value.is_a?(Hash)
                value.each do |k, v|
                  if !v.is_a?(String) && !v.is_a?(Symbol)
                    v = v.to_json
                  end
                  v = ERB::Util.html_escape(v) if escape
                  attrs << %(data-#{k.to_s.dasherize}="#{v}")
                end
              elsif BOOLEAN_ATTRIBUTES.include?(key)
                attrs << %(#{key}="#{key}") if value
              elsif !value.nil?
                final_value = value.is_a?(Array) ? value.join(" ") : value
                final_value = ERB::Util.html_escape(final_value) if escape
                attrs << %(#{key}="#{final_value}")
              end
            end
            " #{attrs.sort * ' '}".html_safe unless attrs.empty?
          end
        end
    end
  end
end
