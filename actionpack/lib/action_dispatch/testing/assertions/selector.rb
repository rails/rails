require 'action_view/vendor/html-scanner'
require 'active_support/core_ext/object/inclusion'
require 'loofah'

#--
# Copyright (c) 2006 Assaf Arkin (http://labnotes.org)
# Under MIT and/or CC By license.
#++

module ActionDispatch
  module Assertions
    NO_STRIP = %w{pre script style textarea}

    # Adds the +assert_select+ method for use in Rails functional
    # test cases, which can be used to make assertions on the response HTML of a controller
    # action. You can also call +assert_select+ within another +assert_select+ to
    # make assertions on elements selected by the enclosing assertion.
    #
    # Use +css_select+ to select elements without making an assertions, either
    # from the response HTML or elements selected by the enclosing assertion.
    #
    # In addition to HTML responses, you can make the following assertions:
    #
    # * +assert_select_encoded+ - Assertions on HTML encoded inside XML, for example for dealing with feed item descriptions.
    # * +assert_select_email+ - Assertions on the HTML body of an e-mail.
    #
    # Also see HTML::Selector to learn how to use selectors.
    module SelectorAssertions
      # Select and return all matching elements.
      #
      # If called with a single argument, uses that argument as a selector
      # to match all elements of the current page. Returns an empty array
      # if no match is found.
      #
      # If called with two arguments, uses the first argument as the base
      # element and the second argument as the selector. Attempts to match the
      # base element and any of its children. Returns an empty array if no
      # match is found.
      #
      # The selector may be a CSS selector expression (String), an expression
      # with substitution values (Array) or an HTML::Selector object.
      #
      #   # Selects all div tags
      #   divs = css_select("div")
      #
      #   # Selects all paragraph tags and does something interesting
      #   pars = css_select("p")
      #   pars.each do |par|
      #     # Do something fun with paragraphs here...
      #   end
      #
      #   # Selects all list items in unordered lists
      #   items = css_select("ul>li")
      #
      #   # Selects all form tags and then all inputs inside the form
      #   forms = css_select("form")
      #   forms.each do |form|
      #     inputs = css_select(form, "input")
      #     ...
      #   end
      def css_select(*args)
        # See assert_select to understand what's going on here.

        parser = Selector.new(@selected, args, Proc.new do |css_selector|
          # will only be called if we're a nested select, i.e. @selected is set
          matches = []
          @selected.each do |selected|
            subset = css_select(selected, css_selector)
            subset.each do |match|
              matches << match unless matches.include?(match)
            end
          end
          return matches
        end)

        parser.root.css(parser.css_selector)
      end

      # An assertion that selects elements and makes one or more equality tests.
      #
      # If the first argument is an element, selects all matching elements
      # starting from (and including) that element and all its children in
      # depth-first order.
      #
      # If no element if specified, calling +assert_select+ selects from the
      # response HTML unless +assert_select+ is called from within an +assert_select+ block.
      #
      # When called with a block +assert_select+ passes an array of selected elements
      # to the block. Calling +assert_select+ from the block, with no element specified,
      # runs the assertion on the complete set of elements selected by the enclosing assertion.
      # Alternatively the array may be iterated through so that +assert_select+ can be called
      # separately for each element.
      #
      #
      # ==== Example
      # If the response contains two ordered lists, each with four list elements then:
      #   assert_select "ol" do |elements|
      #     elements.each do |element|
      #       assert_select element, "li", 4
      #     end
      #   end
      #
      # will pass, as will:
      #   assert_select "ol" do
      #     assert_select "li", 8
      #   end
      #
      # The selector may be a CSS selector expression (String), an expression
      # with substitution values, or an HTML::Selector object.
      #
      # === Equality Tests
      #
      # The equality test may be one of the following:
      # * <tt>true</tt> - Assertion is true if at least one element selected.
      # * <tt>false</tt> - Assertion is true if no element selected.
      # * <tt>String/Regexp</tt> - Assertion is true if the text value of at least
      #   one element matches the string or regular expression.
      # * <tt>Integer</tt> - Assertion is true if exactly that number of
      #   elements are selected.
      # * <tt>Range</tt> - Assertion is true if the number of selected
      #   elements fit the range.
      # If no equality test specified, the assertion is true if at least one
      # element selected.
      #
      # To perform more than one equality tests, use a hash with the following keys:
      # * <tt>:text</tt> - Narrow the selection to elements that have this text
      #   value (string or regexp).
      # * <tt>:html</tt> - Narrow the selection to elements that have this HTML
      #   content (string or regexp).
      # * <tt>:count</tt> - Assertion is true if the number of selected elements
      #   is equal to this value.
      # * <tt>:minimum</tt> - Assertion is true if the number of selected
      #   elements is at least this value.
      # * <tt>:maximum</tt> - Assertion is true if the number of selected
      #   elements is at most this value.
      #
      # If the method is called with a block, once all equality tests are
      # evaluated the block is called with an array of all matched elements.
      #
      #   # At least one form element
      #   assert_select "form"
      #
      #   # Form element includes four input fields
      #   assert_select "form input", 4
      #
      #   # Page title is "Welcome"
      #   assert_select "title", "Welcome"
      #
      #   # Page title is "Welcome" and there is only one title element
      #   assert_select "title", {count: 1, text: "Welcome"},
      #       "Wrong title or more than one title element"
      #
      #   # Page contains no forms
      #   assert_select "form", false, "This page must contain no forms"
      #
      #   # Test the content and style
      #   assert_select "body div.header ul.menu"
      #
      #   # Use substitution values
      #   assert_select "ol>li#?", /item-\d+/
      #
      #   # All input fields in the form have a name
      #   assert_select "form input" do
      #     assert_select "[name=?]", /.+/  # Not empty
      #   end
      def assert_select(*args, &block)
        @selected ||= nil

        parser = HTMLSelector.new(@selected, args, Proc.new do
          Loofah.fragment('').tap { |fragment| fragment.add_child @selected }
        end)

        # Start with optional element followed by mandatory selector.
        root = parser.root

        # First or second argument is the selector
        selector = parser.css_selector

        # Next argument is used for equality tests.
        equals = parser.equals

        # Last argument is the message we use if the assertion fails.
        message = parser.message
        #- message = "No match made with selector #{selector.inspect}" unless message

        matches = root.css(selector)
        # If text/html, narrow down to those elements that match it.
        content_mismatch = nil
        if match_with = equals[:text]
          matches.delete_if do |match|
            text = match.text
            text.strip! unless NO_STRIP.include?(match.name)
            text.sub!(/\A\n/, '') if match.name == "textarea"
            content_matches?(match_with, text) do |error_message|
              content_mismatch ||= error_message
            end
          end
        elsif match_with = equals[:html]
          matches.delete_if do |match|
            html = match.to_s
            html.strip! unless NO_STRIP.include?(match.name)
            content_matches?(match_with, html) do |error_message|
              content_mismatch ||= error_message
            end
          end
        end
        # Expecting foo found bar element only if found zero, not if
        # found one but expecting two.
        message ||= content_mismatch if matches.empty?
        # Test minimum/maximum occurrence.
        min, max, count = equals[:minimum], equals[:maximum], equals[:count]

        # FIXME: minitest provides messaging when we use assert_operator,
        # so is this custom message really needed?
        message = message || %(Expected #{count_description(min, max, count)} matching "#{selector.to_s}", found #{matches.size})
        if count
          assert_equal count, matches.size, message
        else
          assert_operator matches.size, :>=, min, message if min
          assert_operator matches.size, :<=, max, message if max
        end

        # If a block is given call that block. Set @selected to allow
        # nested assert_select, which can be nested several levels deep.
        if block_given? && !matches.empty?
          begin
            in_scope, @selected = @selected, matches
            yield matches
          ensure
            @selected = in_scope
          end
        end

        # Returns all matches elements.
        matches
      end

      def count_description(min, max, count) #:nodoc:
        pluralize = lambda {|word, quantity| word << (quantity == 1 ? '' : 's')}

        if min && max && (max != min)
          "between #{min} and #{max} elements"
        elsif min && max && max == min && count
          "exactly #{count} #{pluralize['element', min]}"
        elsif min && !(min == 1 && max == 1)
          "at least #{min} #{pluralize['element', min]}"
        elsif max
          "at most #{max} #{pluralize['element', max]}"
        end
      end

      # Extracts the content of an element, treats it as encoded HTML and runs
      # nested assertion on it.
      #
      # You typically call this method within another assertion to operate on
      # all currently selected elements. You can also pass an element or array
      # of elements.
      #
      # The content of each element is un-encoded, and wrapped in the root
      # element +encoded+. It then calls the block with all un-encoded elements.
      #
      #   # Selects all bold tags from within the title of an Atom feed's entries (perhaps to nab a section name prefix)
      #   assert_select "feed[xmlns='http://www.w3.org/2005/Atom']" do
      #     # Select each entry item and then the title item
      #     assert_select "entry>title" do
      #       # Run assertions on the encoded title elements
      #       assert_select_encoded do
      #         assert_select "b"
      #       end
      #     end
      #   end
      #
      #
      #   # Selects all paragraph tags from within the description of an RSS feed
      #   assert_select "rss[version=2.0]" do
      #     # Select description element of each feed item.
      #     assert_select "channel>item>description" do
      #       # Run assertions on the encoded elements.
      #       assert_select_encoded do
      #         assert_select "p"
      #       end
      #     end
      #   end
      def assert_select_encoded(element = nil, &block)
        case element
          when Array
            elements = element
          when HTML::Node
            elements = [element]
          when nil
            unless elements = @selected
              raise ArgumentError, "First argument is optional, but must be called from a nested assert_select"
            end
          else
            raise ArgumentError, "Argument is optional, and may be node or array of nodes"
        end

        selected = elements.map do |elem|
          root = Loofah.fragment(CGI.unescapeHTML("<encoded>#{elem.text}</encoded>")).root
          css_select(root, "encoded:root", &block)[0]
        end

        begin
          old_selected, @selected = @selected, selected
          assert_select ":root", &block
        ensure
          @selected = old_selected
        end
      end

      # Extracts the body of an email and runs nested assertions on it.
      #
      # You must enable deliveries for this assertion to work, use:
      #   ActionMailer::Base.perform_deliveries = true
      #
      #  assert_select_email do
      #    assert_select "h1", "Email alert"
      #  end
      #
      #  assert_select_email do
      #    items = assert_select "ol>li"
      #    items.each do
      #       # Work with items here...
      #    end
      #  end
      def assert_select_email(&block)
        deliveries = ActionMailer::Base.deliveries
        assert !deliveries.empty?, "No e-mail in delivery list"

        deliveries.each do |delivery|
          (delivery.parts.empty? ? [delivery] : delivery.parts).each do |part|
            if part["Content-Type"].to_s =~ /^text\/html\W/
              root = HTML::Document.new(part.body.to_s).root
              assert_select root, ":root", &block
            end
          end
        end
      end

      protected
        def content_matches?(match_with, content)
          if match_with.is_a?(Regexp)
            content =~ match_with
          else
            content == match_with.to_s
          end
          yield sprintf("<%s> expected but was\n<%s>.", match_with, content) if block_given?
        end

        class Selector #:nodoc:
          attr_accessor :root, :css_selector

          def initialize(selected, *args, &root_for_nested_call_proc)
            raise ArgumentError, "ArgumentsParser expects a block for parsing a nested call's arguments" unless block_given?
            @nested_call = selected

            @args = args

            # see +determine_root_from+
            @css_selector_is_second_argument = false
            @root = determine_root_from(@args.shift)

            arg = @css_selector_is_second_argument ? @args.shift : @args.first
            @css_selector = css_selector(arg)
          end

          def response_from_page
            @html_document ||= if @response.content_type =~ /xml$/
              Loofah.xml_fragment(@response.body)
            else
              Loofah.fragment(@response.body)
            end
            @html_document.root
          end

          def determine_root_from(root_or_selector)
            if root_or_selector.is_a?(Nokogiri::XML::Node)
              # First argument is a node (tag or text, but also HTML root),
              # so we know what we're selecting from,
              # we also know that the second argument is the selector
              @css_selector_is_second_argument = true

              root_or_selector
            elsif root_or_selector == nil
              raise ArgumentError, "First argument is either selector or element to select, but nil found. Perhaps you called assert_select with an element that does not exist?"
            elsif @nested_call
              # root_or_selector is a selector since the first call failed
              root_for_nested_select_proc.call(root_or_selector)
            else
              response_from_page
            end
          end

          def css_selector_from(arg)
            unless arg.is_a? String
              raise ArgumentError, "Expecting a selector as the first argument"
            end
            arg
          end
        end

        class HTMLSelector < Selector
          attr_accessor :equals, :message
          def initialize(*)
            super
            @equals = assign_equals_from(@args.shift)
            @message = @args.shift

            if @args.shift
              raise ArgumentError, "Not expecting that last argument, you either have too many arguments, or they're the wrong type"
            end
          end

          def assign_equals_from(comparator)
              equals = {}
              case comparator
                when Hash
                  equals = comparator
                when String, Regexp
                  equals[:text] = comparator
                when Integer
                  equals[:count] = comparator
                when Range
                  equals[:minimum] = comparator.begin
                  equals[:maximum] = comparator.end
                when FalseClass
                  equals[:count] = 0
                when NilClass, TrueClass
                  equals[:minimum] = 1
                else raise ArgumentError, "I don't understand what you're trying to match"
              end

              # By default we're looking for at least one match.
              if equals[:count]
                equals[:minimum] = equals[:maximum] = equals[:count]
              else
                equals[:minimum] ||= 1
              end
            equals
          end
        end
    end
  end
end
