# frozen_string_literal: true

require "active_support/code_generator"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/string/inflections"
require "action_view/helpers/capture_helper"
require "action_view/helpers/output_safety_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View Tag \Helpers
    #
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
        def self.define_element(name, code_generator:, method_name: name)
          return if method_defined?(name)

          code_generator.class_eval do |batch|
            batch << "\n" <<
              "def #{method_name}(content = nil, escape: true, **options, &block)" <<
              "  tag_string(#{name.inspect}, content, options, escape: escape, &block)" <<
              "end"
          end
        end

        def self.define_void_element(name, code_generator:, method_name: name)
          code_generator.class_eval do |batch|
            batch << "\n" <<
              "def #{method_name}(escape: true, **options, &block)" <<
              "  self_closing_tag_string(#{name.inspect}, options, escape, '>')" <<
              "end"
          end
        end

        def self.define_self_closing_element(name, code_generator:, method_name: name)
          code_generator.class_eval do |batch|
            batch << "\n" <<
              "def #{method_name}(content = nil, escape: true, **options, &block)" <<
              "  if content || block" <<
              "    tag_string(#{name.inspect}, content, options, escape: escape, &block)" <<
              "  else" <<
              "   self_closing_tag_string(#{name.inspect}, options, escape)" <<
              "  end" <<
              "end"
          end
        end

        ActiveSupport::CodeGenerator.batch(self, __FILE__, __LINE__) do |code_generator|
          define_void_element :area, code_generator: code_generator
          define_void_element :base, code_generator: code_generator
          define_void_element :br, code_generator: code_generator
          define_void_element :col, code_generator: code_generator
          define_void_element :embed, code_generator: code_generator
          define_void_element :hr, code_generator: code_generator
          define_void_element :img, code_generator: code_generator
          define_void_element :input, code_generator: code_generator
          define_void_element :keygen, code_generator: code_generator
          define_void_element :link, code_generator: code_generator
          define_void_element :meta, code_generator: code_generator
          define_void_element :source, code_generator: code_generator
          define_void_element :track, code_generator: code_generator
          define_void_element :wbr, code_generator: code_generator

          define_self_closing_element :animate, code_generator: code_generator
          define_self_closing_element :animateMotion, code_generator: code_generator, method_name: :animate_motion
          define_self_closing_element :animateTransform, code_generator: code_generator, method_name: :animate_transform
          define_self_closing_element :circle, code_generator: code_generator
          define_self_closing_element :ellipse, code_generator: code_generator
          define_self_closing_element :line, code_generator: code_generator
          define_self_closing_element :path, code_generator: code_generator
          define_self_closing_element :polygon, code_generator: code_generator
          define_self_closing_element :polyline, code_generator: code_generator
          define_self_closing_element :rect, code_generator: code_generator
          define_self_closing_element :set, code_generator: code_generator
          define_self_closing_element :stop, code_generator: code_generator
          define_self_closing_element :use, code_generator: code_generator
          define_self_closing_element :view, code_generator: code_generator

          define_element :a, code_generator: code_generator
          define_element :abbr, code_generator: code_generator
          define_element :address, code_generator: code_generator
          define_element :article, code_generator: code_generator
          define_element :aside, code_generator: code_generator
          define_element :audio, code_generator: code_generator
          define_element :b, code_generator: code_generator
          define_element :bdi, code_generator: code_generator
          define_element :bdo, code_generator: code_generator
          define_element :blockquote, code_generator: code_generator
          define_element :body, code_generator: code_generator
          define_element :button, code_generator: code_generator
          define_element :canvas, code_generator: code_generator
          define_element :caption, code_generator: code_generator
          define_element :cite, code_generator: code_generator
          define_element :code, code_generator: code_generator
          define_element :colgroup, code_generator: code_generator
          define_element :data, code_generator: code_generator
          define_element :datalist, code_generator: code_generator
          define_element :dd, code_generator: code_generator
          define_element :del, code_generator: code_generator
          define_element :details, code_generator: code_generator
          define_element :dfn, code_generator: code_generator
          define_element :dialog, code_generator: code_generator
          define_element :div, code_generator: code_generator
          define_element :dl, code_generator: code_generator
          define_element :dt, code_generator: code_generator
          define_element :em, code_generator: code_generator
          define_element :fieldset, code_generator: code_generator
          define_element :figcaption, code_generator: code_generator
          define_element :figure, code_generator: code_generator
          define_element :footer, code_generator: code_generator
          define_element :form, code_generator: code_generator
          define_element :h1, code_generator: code_generator
          define_element :h2, code_generator: code_generator
          define_element :h3, code_generator: code_generator
          define_element :h4, code_generator: code_generator
          define_element :h5, code_generator: code_generator
          define_element :h6, code_generator: code_generator
          define_element :head, code_generator: code_generator
          define_element :header, code_generator: code_generator
          define_element :hgroup, code_generator: code_generator
          define_element :html, code_generator: code_generator
          define_element :i, code_generator: code_generator
          define_element :iframe, code_generator: code_generator
          define_element :ins, code_generator: code_generator
          define_element :kbd, code_generator: code_generator
          define_element :label, code_generator: code_generator
          define_element :legend, code_generator: code_generator
          define_element :li, code_generator: code_generator
          define_element :main, code_generator: code_generator
          define_element :map, code_generator: code_generator
          define_element :mark, code_generator: code_generator
          define_element :menu, code_generator: code_generator
          define_element :meter, code_generator: code_generator
          define_element :nav, code_generator: code_generator
          define_element :noscript, code_generator: code_generator
          define_element :object, code_generator: code_generator
          define_element :ol, code_generator: code_generator
          define_element :optgroup, code_generator: code_generator
          define_element :option, code_generator: code_generator
          define_element :output, code_generator: code_generator
          define_element :p, code_generator: code_generator
          define_element :picture, code_generator: code_generator
          define_element :portal, code_generator: code_generator
          define_element :pre, code_generator: code_generator
          define_element :progress, code_generator: code_generator
          define_element :q, code_generator: code_generator
          define_element :rp, code_generator: code_generator
          define_element :rt, code_generator: code_generator
          define_element :ruby, code_generator: code_generator
          define_element :s, code_generator: code_generator
          define_element :samp, code_generator: code_generator
          define_element :script, code_generator: code_generator
          define_element :search, code_generator: code_generator
          define_element :section, code_generator: code_generator
          define_element :select, code_generator: code_generator
          define_element :slot, code_generator: code_generator
          define_element :small, code_generator: code_generator
          define_element :span, code_generator: code_generator
          define_element :strong, code_generator: code_generator
          define_element :style, code_generator: code_generator
          define_element :sub, code_generator: code_generator
          define_element :summary, code_generator: code_generator
          define_element :sup, code_generator: code_generator
          define_element :table, code_generator: code_generator
          define_element :tbody, code_generator: code_generator
          define_element :td, code_generator: code_generator
          define_element :template, code_generator: code_generator
          define_element :textarea, code_generator: code_generator
          define_element :tfoot, code_generator: code_generator
          define_element :th, code_generator: code_generator
          define_element :thead, code_generator: code_generator
          define_element :time, code_generator: code_generator
          define_element :title, code_generator: code_generator
          define_element :tr, code_generator: code_generator
          define_element :u, code_generator: code_generator
          define_element :ul, code_generator: code_generator
          define_element :var, code_generator: code_generator
          define_element :video, code_generator: code_generator
        end

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

        def content_tag_string(name, content, options, escape = true) # :nodoc:
          tag_options = tag_options(options, escape) if options

          if escape && content.present?
            content = ERB::Util.unwrapped_html_escape(content)
          end
          "<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name}>".html_safe
        end

        def tag_options(options, escape = true) # :nodoc:
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

                  v = @view_context.safe_join(tokens, " ")
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

        private
          def tag_string(name, content = nil, options, escape: true, &block)
            content = @view_context.capture(self, &block) if block

            content_tag_string(name, content, options, escape)
          end

          def self_closing_tag_string(name, options, escape = true, tag_suffix = " />")
            "<#{name}#{tag_options(options, escape)}#{tag_suffix}".html_safe
          end

          def boolean_tag_option(key)
            %(#{key}="#{key}")
          end

          def tag_option(key, value, escape)
            key = ERB::Util.xml_name_escape(key) if escape

            case value
            when Array, Hash
              value = TagHelper.build_tag_values(value) if key.to_s == "class"
              value = escape ? @view_context.safe_join(value, " ") : value.join(" ")
            when Regexp
              value = escape ? ERB::Util.unwrapped_html_escape(value.source) : value.source
            else
              value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s
            end
            value = value.gsub('"', "&quot;") if value.include?('"')

            %(#{key}="#{value}")
          end

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

          def method_missing(called, *args, escape: true, **options, &block)
            name = called.name.dasherize

            TagHelper.ensure_valid_html5_tag_name(name)

            tag_string(name, *args, options, escape: escape, &block)
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
      # Data attribute values are encoded to JSON, with the exception of strings, symbols, and
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
      # Note that when using the block form options should be wrapped in
      # parenthesis.
      #
      #   <%= tag.a(href: "/about", class: "font-bold") do %>
      #     About the author
      #   <% end %>
      #   # => <a href="/about" class="font-bold">About the author</a>
      #
      # === Building HTML attributes
      #
      # Transforms a Hash into HTML attributes, ready to be interpolated into
      # ERB. Includes or omits boolean attributes based on their truthiness.
      # Transforms keys nested within
      # <tt>aria:</tt> or <tt>data:</tt> objects into <tt>aria-</tt> and <tt>data-</tt>
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
      # The following format is for legacy syntax support. It will be deprecated in future versions of \Rails.
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
          ensure_valid_html5_tag_name(name)
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
        ensure_valid_html5_tag_name(name)

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
        tokens = build_tag_values(*args).flat_map { |value| CGI.unescape_html(value.to_s).split(/\s+/) }.uniq

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
        def ensure_valid_html5_tag_name(name)
          raise ArgumentError, "Invalid HTML5 tag name: #{name.inspect}" unless /\A[a-zA-Z][^\s\/>]*\z/.match?(name)
        end
        module_function :ensure_valid_html5_tag_name

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
