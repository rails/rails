#--
# Copyright (c) 2006 Assaf Arkin (http://labnotes.org)
# Under MIT and/or CC By license.
#++

require 'rexml/document'
require 'html/document'

module ActionController
  module Assertions
    unless const_defined?(:NO_STRIP)
      NO_STRIP = %w{pre script style textarea}
    end

    # Adds the #assert_select method for use in Rails functional
    # test cases.
    #
    # Use #assert_select to make assertions on the response HTML of a controller
    # action. You can also call #assert_select within another #assert_select to
    # make assertions on elements selected by the enclosing assertion.
    #
    # Use #css_select to select elements without making an assertions, either
    # from the response HTML or elements selected by the enclosing assertion.
    #
    # In addition to HTML responses, you can make the following assertions:
    # * #assert_select_rjs    -- Assertions on HTML content of RJS update and
    #     insertion operations.
    # * #assert_select_encoded  -- Assertions on HTML encoded inside XML,
    #     for example for dealing with feed item descriptions.
    # * #assert_select_email    -- Assertions on the HTML body of an e-mail.
    #
    # Also see HTML::Selector for learning how to use selectors.
    module SelectorAssertions
      # :call-seq:
      #   css_select(selector) => array
      #   css_select(element, selector) => array
      #
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
      # The selector may be a CSS selector expression (+String+), an expression
      # with substitution values (+Array+) or an HTML::Selector object.
      #
      # For example:
      #   forms = css_select("form")
      #   forms.each do |form|
      #     inputs = css_select(form, "input")
      #     ...
      #   end
      def css_select(*args)
        # See assert_select to understand what's going on here.
        arg = args.shift

        if arg.is_a?(HTML::Node)
          root = arg
          arg = args.shift
        elsif arg == nil
          raise ArgumentError, "First argument is either selector or element to select, but nil found. Perhaps you called assert_select with an element that does not exist?"
        elsif @selected
          matches = []
          @selected.each do |selected|
            subset = css_select(selected, HTML::Selector.new(arg.dup, args.dup))
            subset.each do |match|
              matches << match unless matches.any? { |m| m.equal?(match) }
            end
          end

          return matches
        else
          root = response_from_page_or_rjs
        end

        case arg
          when String
            selector = HTML::Selector.new(arg, args)
          when Array
            selector = HTML::Selector.new(*arg)
          when HTML::Selector
            selector = arg
          else raise ArgumentError, "Expecting a selector as the first argument"
        end

        selector.select(root)
      end

      # :call-seq:
      #   assert_select(selector, equality?, message?)
      #   assert_select(element, selector, equality?, message?)
      #
      # An assertion that selects elements and makes one or more equality tests.
      #
      # If the first argument is an element, selects all matching elements
      # starting from (and including) that element and all its children in
      # depth-first order.
      #
      # If no element if specified, calling #assert_select will select from the
      # response HTML. Calling #assert_select inside an #assert_select block will
      # run the assertion for each element selected by the enclosing assertion.
      #
      # For example:
      #   assert_select "ol>li" do |elements|
      #     elements.each do |element|
      #       assert_select element, "li"
      #     end
      #   end
      # Or for short:
      #   assert_select "ol>li" do
      #     assert_select "li"
      #   end
      #
      # The selector may be a CSS selector expression (+String+), an expression
      # with substitution values, or an HTML::Selector object.
      #
      # === Equality Tests
      #
      # The equality test may be one of the following:
      # * <tt>true</tt> -- Assertion is true if at least one element selected.
      # * <tt>false</tt> -- Assertion is true if no element selected.
      # * <tt>String/Regexp</tt> -- Assertion is true if the text value of at least
      #   one element matches the string or regular expression.
      # * <tt>Integer</tt> -- Assertion is true if exactly that number of
      #   elements are selected.
      # * <tt>Range</tt> -- Assertion is true if the number of selected
      #   elements fit the range.
      # If no equality test specified, the assertion is true if at least one
      # element selected.
      #
      # To perform more than one equality tests, use a hash with the following keys:
      # * <tt>:text</tt> -- Narrow the selection to elements that have this text
      #   value (string or regexp).
      # * <tt>:html</tt> -- Narrow the selection to elements that have this HTML
      #   content (string or regexp).
      # * <tt>:count</tt> -- Assertion is true if the number of selected elements
      #   is equal to this value.
      # * <tt>:minimum</tt> -- Assertion is true if the number of selected
      #   elements is at least this value.
      # * <tt>:maximum</tt> -- Assertion is true if the number of selected
      #   elements is at most this value.
      #
      # If the method is called with a block, once all equality tests are
      # evaluated the block is called with an array of all matched elements.
      #
      # === Examples
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
      #   assert_select "title", {:count=>1, :text=>"Welcome"},
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
        # Start with optional element followed by mandatory selector.
        arg = args.shift

        if arg.is_a?(HTML::Node)
          # First argument is a node (tag or text, but also HTML root),
          # so we know what we're selecting from.
          root = arg
          arg = args.shift
        elsif arg == nil
          # This usually happens when passing a node/element that
          # happens to be nil.
          raise ArgumentError, "First argument is either selector or element to select, but nil found. Perhaps you called assert_select with an element that does not exist?"
        elsif @selected
          root = HTML::Node.new(nil)
          root.children.concat @selected
        else
          # Otherwise just operate on the response document.
          root = response_from_page_or_rjs
        end
        
        # First or second argument is the selector: string and we pass
        # all remaining arguments. Array and we pass the argument. Also
        # accepts selector itself.
        case arg
          when String
            selector = HTML::Selector.new(arg, args)
          when Array
            selector = HTML::Selector.new(*arg)
          when HTML::Selector
            selector = arg
          else raise ArgumentError, "Expecting a selector as the first argument"
        end
        
        # Next argument is used for equality tests.
        equals = {}
        case arg = args.shift
          when Hash
            equals = arg
          when String, Regexp
            equals[:text] = arg
          when Integer
            equals[:count] = arg
          when Range
            equals[:minimum] = arg.begin
            equals[:maximum] = arg.end
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
          equals[:minimum] = 1 unless equals[:minimum]
        end

        # Last argument is the message we use if the assertion fails.
        message = args.shift
        #- message = "No match made with selector #{selector.inspect}" unless message
        if args.shift
          raise ArgumentError, "Not expecting that last argument, you either have too many arguments, or they're the wrong type"
        end

        matches = selector.select(root)
        # If text/html, narrow down to those elements that match it.
        content_mismatch = nil
        if match_with = equals[:text]
          matches.delete_if do |match|
            text = ""
            stack = match.children.reverse
            while node = stack.pop
              if node.tag?
                stack.concat node.children.reverse
              else
                text << node.content
              end
            end
            text.strip! unless NO_STRIP.include?(match.name)
            unless match_with.is_a?(Regexp) ? (text =~ match_with) : (text == match_with.to_s)
              content_mismatch ||= build_message(message, "<?> expected but was\n<?>.", match_with, text)
              true
            end
          end
        elsif match_with = equals[:html]
          matches.delete_if do |match|
            html = match.children.map(&:to_s).join
            html.strip! unless NO_STRIP.include?(match.name)
            unless match_with.is_a?(Regexp) ? (html =~ match_with) : (html == match_with.to_s)
              content_mismatch ||= build_message(message, "<?> expected but was\n<?>.", match_with, html)
              true
            end
          end
        end
        # Expecting foo found bar element only if found zero, not if
        # found one but expecting two.
        message ||= content_mismatch if matches.empty?
        # Test minimum/maximum occurrence.
        min, max = equals[:minimum], equals[:maximum]
        message = message || %(Expected #{count_description(min, max)} matching "#{selector.to_s}", found #{matches.size}.)
        assert matches.size >= min, message if min
        assert matches.size <= max, message if max

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
      
      def count_description(min, max) #:nodoc:
        pluralize = lambda {|word, quantity| word << (quantity == 1 ? '' : 's')}
        
        if min && max && (max != min)
          "between #{min} and #{max} elements"
        elsif min && !(min == 1 && max == 1)
          "at least #{min} #{pluralize['element', min]}"
        elsif max
          "at most #{max} #{pluralize['element', max]}"
        end
      end
      
      # :call-seq:
      #   assert_select_rjs(id?) { |elements| ... }
      #   assert_select_rjs(statement, id?) { |elements| ... }
      #   assert_select_rjs(:insert, position, id?) { |elements| ... }
      #
      # Selects content from the RJS response.
      #
      # === Narrowing down
      #
      # With no arguments, asserts that one or more elements are updated or
      # inserted by RJS statements.
      #
      # Use the +id+ argument to narrow down the assertion to only statements
      # that update or insert an element with that identifier.
      #
      # Use the first argument to narrow down assertions to only statements
      # of that type. Possible values are +:replace+, +:replace_html+, +:show+,
      # +:hide+, +:toggle+, +:remove+ and +:insert_html+.
      #
      # Use the argument +:insert+ followed by an insertion position to narrow
      # down the assertion to only statements that insert elements in that
      # position. Possible values are +:top+, +:bottom+, +:before+ and +:after+.
      #
      # Using the +:remove+ statement, you will be able to pass a block, but it will
      # be ignored as there is no HTML passed for this statement.
      #
      # === Using blocks
      #
      # Without a block, #assert_select_rjs merely asserts that the response
      # contains one or more RJS statements that replace or update content.
      #
      # With a block, #assert_select_rjs also selects all elements used in
      # these statements and passes them to the block. Nested assertions are
      # supported.
      #
      # Calling #assert_select_rjs with no arguments and using nested asserts
      # asserts that the HTML content is returned by one or more RJS statements.
      # Using #assert_select directly makes the same assertion on the content,
      # but without distinguishing whether the content is returned in an HTML
      # or JavaScript.
      #
      # === Examples
      #
      #   # Replacing the element foo.
      #   # page.replace 'foo', ...
      #   assert_select_rjs :replace, "foo"
      #
      #   # Replacing with the chained RJS proxy.
      #   # page[:foo].replace ...
      #   assert_select_rjs :chained_replace, 'foo'
      #
      #   # Inserting into the element bar, top position.
      #   assert_select_rjs :insert, :top, "bar"
      #
      #   # Remove the element bar
      #   assert_select_rjs :remove, "bar"
      #
      #   # Changing the element foo, with an image.
      #   assert_select_rjs "foo" do
      #     assert_select "img[src=/images/logo.gif""
      #   end
      #
      #   # RJS inserts or updates a list with four items.
      #   assert_select_rjs do
      #     assert_select "ol>li", 4
      #   end
      #
      #   # The same, but shorter.
      #   assert_select "ol>li", 4
      def assert_select_rjs(*args, &block)
        rjs_type = nil
        arg      = args.shift

        # If the first argument is a symbol, it's the type of RJS statement we're looking
        # for (update, replace, insertion, etc). Otherwise, we're looking for just about
        # any RJS statement.
        if arg.is_a?(Symbol)
          rjs_type = arg
          if rjs_type == :insert
            arg = args.shift
            insertion = "insert_#{arg}".to_sym
            raise ArgumentError, "Unknown RJS insertion type #{arg}" unless RJS_STATEMENTS[insertion]
            statement = "(#{RJS_STATEMENTS[insertion]})"
          else
            raise ArgumentError, "Unknown RJS statement type #{rjs_type}" unless RJS_STATEMENTS[rjs_type]
            statement = "(#{RJS_STATEMENTS[rjs_type]})"
          end
          arg = args.shift
        else
          statement = "#{RJS_STATEMENTS[:any]}"
        end

        # Next argument we're looking for is the element identifier. If missing, we pick
        # any element.
        if arg.is_a?(String)
          id = Regexp.quote(arg)
          arg = args.shift
        else
          id = "[^\"]*"
        end

        pattern =
          case rjs_type
            when :chained_replace, :chained_replace_html
              Regexp.new("\\$\\(\"#{id}\"\\)#{statement}\\(#{RJS_PATTERN_HTML}\\)", Regexp::MULTILINE)
            when :remove, :show, :hide, :toggle
              Regexp.new("#{statement}\\(\"#{id}\"\\)")
            else
              Regexp.new("#{statement}\\(\"#{id}\", #{RJS_PATTERN_HTML}\\)", Regexp::MULTILINE)
          end

        # Duplicate the body since the next step involves destroying it.
        matches = nil
        case rjs_type
          when :remove, :show, :hide, :toggle
            matches = @response.body.match(pattern)
          else
            @response.body.gsub(pattern) do |match|
              html = unescape_rjs($2)
              matches ||= []
              matches.concat HTML::Document.new(html).root.children.select { |n| n.tag? }
              ""
            end
        end
        if matches
          if block_given? && !([:remove, :show, :hide, :toggle].include? rjs_type)
            begin
              in_scope, @selected = @selected, matches
              yield matches
            ensure
              @selected = in_scope
            end
          end
          matches
        else
          # RJS statement not found.
          flunk args.shift || "No RJS statement that replaces or inserts HTML content."
        end
      end

      # :call-seq:
      #   assert_select_encoded(element?) { |elements| ... }
      #
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
      # === Example
      #
      #   assert_select_feed :rss, 2.0 do
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

        fix_content = lambda do |node|
          # Gets around a bug in the Rails 1.1 HTML parser.
          node.content.gsub(/<!\[CDATA\[(.*)(\]\]>)?/m) { CGI.escapeHTML($1) }
        end

        selected = elements.map do |element|
          text = element.children.select{ |c| not c.tag? }.map{ |c| fix_content[c] }.join
          root = HTML::Document.new(CGI.unescapeHTML("<encoded>#{text}</encoded>")).root
          css_select(root, "encoded:root", &block)[0]
        end

        begin
          old_selected, @selected = @selected, selected
          assert_select ":root", &block
        ensure
          @selected = old_selected
        end
      end

      # :call-seq:
      #   assert_select_email { }
      #
      # Extracts the body of an email and runs nested assertions on it.
      #
      # You must enable deliveries for this assertion to work, use:
      #   ActionMailer::Base.perform_deliveries = true
      #
      # === Example
      #
      # assert_select_email do
      #   assert_select "h1", "Email alert"
      # end
      def assert_select_email(&block)
        deliveries = ActionMailer::Base.deliveries
        assert !deliveries.empty?, "No e-mail in delivery list"

        for delivery in deliveries
          for part in delivery.parts
            if part["Content-Type"].to_s =~ /^text\/html\W/
              root = HTML::Document.new(part.body).root
              assert_select root, ":root", &block
            end
          end
        end
      end

      protected
        unless const_defined?(:RJS_STATEMENTS)
          RJS_STATEMENTS = {
            :replace              => /Element\.replace/,
            :replace_html         => /Element\.update/,
            :chained_replace      => /\.replace/,
            :chained_replace_html => /\.update/,
            :remove               => /Element\.remove/,
            :show                 => /Element\.show/,
            :hide                 => /Element\.hide/,
            :toggle                 => /Element\.toggle/
          }
          RJS_INSERTIONS = [:top, :bottom, :before, :after]
          RJS_INSERTIONS.each do |insertion|
            RJS_STATEMENTS["insert_#{insertion}".to_sym] = Regexp.new(Regexp.quote("new Insertion.#{insertion.to_s.camelize}"))
          end
          RJS_STATEMENTS[:any] = Regexp.new("(#{RJS_STATEMENTS.values.join('|')})")
          RJS_STATEMENTS[:insert_html] = Regexp.new(RJS_INSERTIONS.collect do |insertion|
            Regexp.quote("new Insertion.#{insertion.to_s.camelize}")
          end.join('|'))
          RJS_PATTERN_HTML = /"((\\"|[^"])*)"/
          RJS_PATTERN_EVERYTHING = Regexp.new("#{RJS_STATEMENTS[:any]}\\(\"([^\"]*)\", #{RJS_PATTERN_HTML}\\)",
                                              Regexp::MULTILINE)
          RJS_PATTERN_UNICODE_ESCAPED_CHAR = /\\u([0-9a-zA-Z]{4})/
        end

        # #assert_select and #css_select call this to obtain the content in the HTML
        # page, or from all the RJS statements, depending on the type of response.
        def response_from_page_or_rjs()
          content_type = @response.content_type
          if content_type && content_type =~ /text\/javascript/
            body = @response.body.dup
            root = HTML::Node.new(nil)
            while true
              next if body.sub!(RJS_PATTERN_EVERYTHING) do |match|
                html = unescape_rjs($3)
                matches = HTML::Document.new(html).root.children.select { |n| n.tag? }
                root.children.concat matches
                ""
              end
              break
            end
            root
          else
            html_document.root
          end
        end

        # Unescapes a RJS string.
        def unescape_rjs(rjs_string)
          # RJS encodes double quotes and line breaks.
          unescaped= rjs_string.gsub('\"', '"')
          unescaped.gsub!('\n', "\n")
          unescaped.gsub!('\076', '>')
          unescaped.gsub!('\074', '<')
          # RJS encodes non-ascii characters.
          unescaped.gsub!(RJS_PATTERN_UNICODE_ESCAPED_CHAR) {|u| [$1.hex].pack('U*')}
          unescaped
        end

    end
  end
end
