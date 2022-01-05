# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/output_safety"
require "set"
require "action_view/helpers/capture_helper"
require "action_view/helpers/output_safety_helper"

module ActionView
  # = Action View Tag Helpers
  module Helpers # :nodoc:
    # Provides methods to generate HTML tags programmatically both as a modern
    # HTML5 compliant builder style and legacy XHTML compliant tags.
    module TagHelper
      include CaptureHelper
      include OutputSafetyHelper

      BOOLEAN_ATTRIBUTES = %w(allowfullscreen allowpaymentrequest async autofocus
                              autoplay checked compact controls declare default
                              defaultchecked defaultmuted defaultselected defer
                              disabled enabled formnovalidate hidden indeterminate
                              inert ismap itemscope loop multiple muted nohref
                              nomodule noresize noshade novalidate nowrap open
                              pauseonexit playsinline readonly required reversed
                              scoped seamless selected sortable truespeed
                              typemustmatch visible).to_set

      BOOLEAN_ATTRIBUTES.merge(BOOLEAN_ATTRIBUTES.map(&:to_sym))
      BOOLEAN_ATTRIBUTES.freeze

      ARIA_PREFIXES = ["aria", :aria].to_set.freeze
      DATA_PREFIXES = ["data", :data].to_set.freeze

      TAG_TYPES = {}
      TAG_TYPES.merge! BOOLEAN_ATTRIBUTES.index_with(:boolean)
      TAG_TYPES.merge! DATA_PREFIXES.index_with(:data)
      TAG_TYPES.merge! ARIA_PREFIXES.index_with(:aria)
      TAG_TYPES.freeze

      PRE_CONTENT_STRINGS             = Hash.new { "" }
      PRE_CONTENT_STRINGS[:textarea]  = "\n"
      PRE_CONTENT_STRINGS["textarea"] = "\n"

      class TagBuilder # :nodoc:
        include CaptureHelper
        include OutputSafetyHelper

        HTML_VOID_ELEMENTS = %i(area base br col circle embed hr img input keygen link meta param source track wbr).to_set
        SVG_VOID_ELEMENTS = %i(animate animateMotion animateTransform circle ellipse line path polygon polyline rect set stop use view).to_set

        def initialize(view_context)
          @view_context = view_context
        end

        # Transforms a Hash into HTML Attributes, ready to be interpolated into
        # ERB.
        #
        #   <input <%= tag.attributes(type: :text, aria: { label: "Search" }) %> >
        #   # => <input type="text" aria-label="Search">
        def attributes(attributes)
          tag_options(attributes.to_h).to_s.strip.html_safe
        end

        def p(*arguments, **options, &block)
          tag_string(:p, *arguments, **options, &block)
        end

        def tag_string(name, content = nil, **options, &block)
          escape = handle_deprecated_escape_options(options)

          content = @view_context.capture(self, &block) if block_given?
          if (HTML_VOID_ELEMENTS.include?(name) || SVG_VOID_ELEMENTS.include?(name)) && content.nil?
            "<#{name.to_s.dasherize}#{tag_options(options, escape)}>".html_safe
          else
            content_tag_string(name.to_s.dasherize, content || "", options, escape)
          end
        end

        def content_tag_string(name, content, options, escape = true)
          tag_options = tag_options(options, escape) if options

          if escape
            name = ERB::Util.xml_name_escape(name)
            content = ERB::Util.unwrapped_html_escape(content)
          end

          "<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name}>".html_safe
        end

        def tag_options(options, escape = true)
          return if options.blank?
          output = +""
          sep    = " "
          options.each_pair do |key, value|
            type = TAG_TYPES[key]
            if type == :data && value.is_a?(Hash)
              value.each_pair do |k, v|
                next if v.nil?
                output << sep
                output << prefix_tag_option(key, k, v, escape)
              end
            elsif type == :aria && value.is_a?(Hash)
              value.each_pair do |k, v|
                next if v.nil?

                case v
                when Array, Hash
                  tokens = TagHelper.build_tag_values(v)
                  next if tokens.none?

                  v = safe_join(tokens, " ")
                else
                  v = v.to_s
                end

                output << sep
                output << prefix_tag_option(key, k, v, escape)
              end
            elsif type == :boolean
              if value
                output << sep
                output << boolean_tag_option(key)
              end
            elsif !value.nil?
              output << sep
              output << tag_option(key, value, escape)
            end
          end
          output unless output.empty?
        end

        def boolean_tag_option(key)
          %(#{key}="#{key}")
        end

        def tag_option(key, value, escape)
          key = ERB::Util.xml_name_escape(key) if escape

          case value
          when Array, Hash
            value = TagHelper.build_tag_values(value) if key.to_s == "class"
            value = escape ? safe_join(value, " ") : value.join(" ")
          when Regexp
            value = escape ? ERB::Util.unwrapped_html_escape(value.source) : value.source
          else
            value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s
          end
          value = value.gsub('"', "&quot;") if value.include?('"')

          %(#{key}="#{value}")
        end

        private
          def prefix_tag_option(prefix, key, value, escape)
            key = "#{prefix}-#{key.to_s.dasherize}"
            unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(BigDecimal)
              value = value.to_json
            end
            tag_option(key, value, escape)
          end

          def respond_to_missing?(*args)
            true
          end

          def handle_deprecated_escape_options(options)
            # The option :escape_attributes has been merged into the options hash to be
            # able to warn when it is used, so we need to handle default values here.
            escape_option_provided = options.has_key?(:escape)
            escape_attributes_option_provided = options.has_key?(:escape_attributes)

            if escape_attributes_option_provided
              ActiveSupport::Deprecation.warn(<<~MSG)
                Use of the option :escape_attributes is deprecated. It currently \
                escapes both names and values of tags and attributes and it is \
                equivalent to :escape. If any of them are enabled, the escaping \
                is fully enabled.
              MSG
            end

            return true unless escape_option_provided || escape_attributes_option_provided
            escape_option = options.delete(:escape)
            escape_attributes_option = options.delete(:escape_attributes)
            escape_option || escape_attributes_option
          end

          def method_missing(called, *args, **options, &block)
            tag_string(called, *args, **options, &block)
          end
      end

      # Returns an HTML tag.
      #
      # === Building HTML tags
      #
      # Builds HTML5 compliant tags with a tag proxy. Every tag can be built with:
      #
      #   tag.<tag name>(optional content, options)
      #
      # where tag name can be e.g. br, div, section, article, or any tag really.
      #
      # ==== Passing content
      #
      # Tags can pass content to embed within it:
      #
      #   tag.h1 'All titles fit to print' # => <h1>All titles fit to print</h1>
      #
      #   tag.div tag.p('Hello world!')  # => <div><p>Hello world!</p></div>
      #
      # Content can also be captured with a block, which is useful in templates:
      #
      #   <%= tag.p do %>
      #     The next great American novel starts here.
      #   <% end %>
      #   # => <p>The next great American novel starts here.</p>
      #
      # ==== Options
      #
      # Use symbol keyed options to add attributes to the generated tag.
      #
      #   tag.section class: %w( kitties puppies )
      #   # => <section class="kitties puppies"></section>
      #
      #   tag.section id: dom_id(@post)
      #   # => <section id="<generated dom id>"></section>
      #
      # Pass +true+ for any attributes that can render with no values, like +disabled+ and +readonly+.
      #
      #   tag.input type: 'text', disabled: true
      #   # => <input type="text" disabled="disabled">
      #
      # HTML5 <tt>data-*</tt> and <tt>aria-*</tt> attributes can be set with a
      # single +data+ or +aria+ key pointing to a hash of sub-attributes.
      #
      # To play nicely with JavaScript conventions, sub-attributes are dasherized.
      #
      #   tag.article data: { user_id: 123 }
      #   # => <article data-user-id="123"></article>
      #
      # Thus <tt>data-user-id</tt> can be accessed as <tt>dataset.userId</tt>.
      #
      # Data attribute values are encoded to JSON, with the exception of strings, symbols and
      # BigDecimals.
      # This may come in handy when using jQuery's HTML5-aware <tt>.data()</tt>
      # from 1.4.3.
      #
      #   tag.div data: { city_state: %w( Chicago IL ) }
      #   # => <div data-city-state="[&quot;Chicago&quot;,&quot;IL&quot;]"></div>
      #
      # The generated tag names and attributes are escaped by default. This can be disabled using
      # +escape+.
      #
      #   tag.img src: 'open & shut.png'
      #   # => <img src="open &amp; shut.png">
      #
      #   tag.img src: 'open & shut.png', escape: false
      #   # => <img src="open & shut.png">
      #
      # The tag builder respects
      # {HTML5 void elements}[https://www.w3.org/TR/html5/syntax.html#void-elements]
      # if no content is passed, and omits closing tags for those elements.
      #
      #   # A standard element:
      #   tag.div # => <div></div>
      #
      #   # A void element:
      #   tag.br  # => <br>
      #
      # === Building HTML attributes
      #
      # Transforms a Hash into HTML attributes, ready to be interpolated into
      # ERB. Includes or omits boolean attributes based on their truthiness.
      # Transforms keys nested within
      # <tt>aria:</tt> or <tt>data:</tt> objects into `aria-` and `data-`
      # prefixed attributes:
      #
      #   <input <%= tag.attributes(type: :text, aria: { label: "Search" }) %>>
      #   # => <input type="text" aria-label="Search">
      #
      #   <button <%= tag.attributes id: "call-to-action", disabled: false, aria: { expanded: false } %> class="primary">Get Started!</button>
      #   # => <button id="call-to-action" aria-expanded="false" class="primary">Get Started!</button>
      #
      # === Legacy syntax
      #
      # The following format is for legacy syntax support. It will be deprecated in future versions of Rails.
      #
      #   tag(name, options = nil, open = false, escape = true)
      #
      # It returns an empty HTML tag of type +name+ which by default is XHTML
      # compliant. Set +open+ to true to create an open tag compatible
      # with HTML 4.0 and below. Add HTML attributes by passing an attributes
      # hash to +options+. Set +escape+ to false to disable attribute value
      # escaping.
      #
      # ==== Options
      #
      # You can use symbols or strings for the attribute names.
      #
      # Use +true+ with boolean attributes that can render with no value, like
      # +disabled+ and +readonly+.
      #
      # HTML5 <tt>data-*</tt> attributes can be set with a single +data+ key
      # pointing to a hash of sub-attributes.
      #
      # ==== Examples
      #
      #   tag("br")
      #   # => <br />
      #
      #   tag("br", nil, true)
      #   # => <br>
      #
      #   tag("input", type: 'text', disabled: true)
      #   # => <input type="text" disabled="disabled" />
      #
      #   tag("input", type: 'text', class: ["strong", "highlight"])
      #   # => <input class="strong highlight" type="text" />
      #
      #   tag("img", src: "open & shut.png")
      #   # => <img src="open &amp; shut.png" />
      #
      #   tag("img", { src: "open &amp; shut.png" }, false, false)
      #   # => <img src="open &amp; shut.png" />
      #
      #   tag("div", data: { name: 'Stephen', city_state: %w(Chicago IL) })
      #   # => <div data-name="Stephen" data-city-state="[&quot;Chicago&quot;,&quot;IL&quot;]" />
      #
      #   tag("div", class: { highlight: current_user.admin? })
      #   # => <div class="highlight" />
      def tag(name = nil, options = nil, open = false, escape = true)
        if name.nil?
          tag_builder
        else
          name = ERB::Util.xml_name_escape(name) if escape
          "<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ? ">" : " />"}".html_safe
        end
      end

      # Returns an HTML block tag of type +name+ surrounding the +content+. Add
      # HTML attributes by passing an attributes hash to +options+.
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +options+ as the second parameter.
      # Set escape to false to disable escaping.
      # Note: this is legacy syntax, see +tag+ method description for details.
      #
      # ==== Options
      # The +options+ hash can be used with attributes with no value like (<tt>disabled</tt> and
      # <tt>readonly</tt>), which you can give a value of true in the +options+ hash. You can use
      # symbols or strings for the attribute names.
      #
      # ==== Examples
      #   content_tag(:p, "Hello world!")
      #    # => <p>Hello world!</p>
      #   content_tag(:div, content_tag(:p, "Hello world!"), class: "strong")
      #    # => <div class="strong"><p>Hello world!</p></div>
      #   content_tag(:div, "Hello world!", class: ["strong", "highlight"])
      #    # => <div class="strong highlight">Hello world!</div>
      #   content_tag(:div, "Hello world!", class: ["strong", { highlight: current_user.admin? }])
      #    # => <div class="strong highlight">Hello world!</div>
      #   content_tag("select", options, multiple: true)
      #    # => <select multiple="multiple">...options...</select>
      #
      #   <%= content_tag :div, class: "strong" do -%>
      #     Hello world!
      #   <% end -%>
      #    # => <div class="strong">Hello world!</div>
      def content_tag(name, content_or_options_with_block = nil, options = nil, escape = true, &block)
        if block_given?
          options = content_or_options_with_block if content_or_options_with_block.is_a?(Hash)
          tag_builder.content_tag_string(name, capture(&block), options, escape)
        else
          tag_builder.content_tag_string(name, content_or_options_with_block, options, escape)
        end
      end

      # Returns a string of tokens built from +args+.
      #
      # ==== Examples
      #   token_list("foo", "bar")
      #    # => "foo bar"
      #   token_list("foo", "foo bar")
      #    # => "foo bar"
      #   token_list({ foo: true, bar: false })
      #    # => "foo"
      #   token_list(nil, false, 123, "", "foo", { bar: true })
      #    # => "123 foo bar"
      def token_list(*args)
        tokens = build_tag_values(*args).flat_map { |value| value.to_s.split(/\s+/) }.uniq

        safe_join(tokens, " ")
      end
      alias_method :class_names, :token_list

      # Returns a CDATA section with the given +content+. CDATA sections
      # are used to escape blocks of text containing characters which would
      # otherwise be recognized as markup. CDATA sections begin with the string
      # <tt><![CDATA[</tt> and end with (and may not contain) the string <tt>]]></tt>.
      #
      #   cdata_section("<hello world>")
      #   # => <![CDATA[<hello world>]]>
      #
      #   cdata_section(File.read("hello_world.txt"))
      #   # => <![CDATA[<hello from a text file]]>
      #
      #   cdata_section("hello]]>world")
      #   # => <![CDATA[hello]]]]><![CDATA[>world]]>
      def cdata_section(content)
        splitted = content.to_s.gsub(/\]\]>/, "]]]]><![CDATA[>")
        "<![CDATA[#{splitted}]]>".html_safe
      end

      # Returns an escaped version of +html+ without affecting existing escaped entities.
      #
      #   escape_once("1 < 2 &amp; 3")
      #   # => "1 &lt; 2 &amp; 3"
      #
      #   escape_once("&lt;&lt; Accept & Checkout")
      #   # => "&lt;&lt; Accept &amp; Checkout"
      def escape_once(html)
        ERB::Util.html_escape_once(html)
      end

      private
        def build_tag_values(*args)
          tag_values = []

          args.each do |tag_value|
            case tag_value
            when Hash
              tag_value.each do |key, val|
                tag_values << key.to_s if val && key.present?
              end
            when Array
              tag_values.concat build_tag_values(*tag_value)
            else
              tag_values << tag_value.to_s if tag_value.present?
            end
          end

          tag_values
        end
        module_function :build_tag_values

        def tag_builder
          @tag_builder ||= TagBuilder.new(self)
        end
    end
  end
end
