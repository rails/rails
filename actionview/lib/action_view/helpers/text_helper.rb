# frozen_string_literal: true

require "active_support/core_ext/string/filters"
require "active_support/core_ext/string/access"
require "active_support/core_ext/array/extract_options"
require "action_view/helpers/sanitize_helper"
require "action_view/helpers/tag_helper"
require "action_view/helpers/output_safety_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View Text \Helpers
    #
    # The TextHelper module provides a set of methods for filtering, formatting
    # and transforming strings, which can reduce the amount of inline Ruby code in
    # your views. These helper methods extend Action View making them callable
    # within your template files.
    #
    # ==== Sanitization
    #
    # Most text helpers that generate HTML output sanitize the given input by default,
    # but do not escape it. This means HTML tags will appear in the page but all malicious
    # code will be removed. Let's look at some examples using the +simple_format+ method:
    #
    #   simple_format('<a href="http://example.com/">Example</a>')
    #   # => "<p><a href=\"http://example.com/\">Example</a></p>"
    #
    #   simple_format('<a href="javascript:alert(\'no!\')">Example</a>')
    #   # => "<p><a>Example</a></p>"
    #
    # If you want to escape all content, you should invoke the +h+ method before
    # calling the text helper.
    #
    #   simple_format h('<a href="http://example.com/">Example</a>')
    #   # => "<p>&lt;a href=\"http://example.com/\"&gt;Example&lt;/a&gt;</p>"
    module TextHelper
      extend ActiveSupport::Concern

      include SanitizeHelper
      include TagHelper
      include OutputSafetyHelper

      # The preferred method of outputting text in your views is to use the
      # <tt><%= "text" %></tt> eRuby syntax. The regular +puts+ and +print+ methods
      # do not operate as expected in an eRuby code block. If you absolutely must
      # output text within a non-output code block (i.e., <tt><% %></tt>), you
      # can use the +concat+ method.
      #
      #   <% concat "hello" %> is equivalent to <%= "hello" %>
      #
      #   <%
      #      unless signed_in?
      #        concat link_to("Sign In", action: :sign_in)
      #      end
      #   %>
      #
      #   is equivalent to
      #
      #   <% unless signed_in? %>
      #     <%= link_to "Sign In", action: :sign_in %>
      #   <% end %>
      #
      def concat(string)
        output_buffer << string
      end

      def safe_concat(string)
        output_buffer.respond_to?(:safe_concat) ? output_buffer.safe_concat(string) : concat(string)
      end

      # Truncates +text+ if it is longer than a specified +:length+. If +text+
      # is truncated, an omission marker will be appended to the result for a
      # total length not exceeding +:length+.
      #
      # You can also pass a block to render and append extra content after the
      # omission marker when +text+ is truncated. However, this content _can_
      # cause the total length to exceed +:length+ characters.
      #
      # The result will be escaped unless <tt>escape: false</tt> is specified.
      # In any case, the result will be marked HTML-safe. Care should be taken
      # if +text+ might contain HTML tags or entities, because truncation could
      # produce invalid HTML, such as unbalanced or incomplete tags.
      #
      # ==== Options
      #
      # [+:length+]
      #   The maximum number of characters that should be returned, excluding
      #   any extra content from the block. Defaults to 30.
      #
      # [+:omission+]
      #   The string to append after truncating. Defaults to  <tt>"..."</tt>.
      #
      # [+:separator+]
      #   A string or regexp used to find a breaking point at which to truncate.
      #   By default, truncation can occur at any character in +text+.
      #
      # [+:escape+]
      #   Whether to escape the result. Defaults to true.
      #
      # ==== Examples
      #
      #   truncate("Once upon a time in a world far far away")
      #   # => "Once upon a time in a world..."
      #
      #   truncate("Once upon a time in a world far far away", length: 17)
      #   # => "Once upon a ti..."
      #
      #   truncate("Once upon a time in a world far far away", length: 17, separator: ' ')
      #   # => "Once upon a..."
      #
      #   truncate("And they found that many people were sleeping better.", length: 25, omission: '... (continued)')
      #   # => "And they f... (continued)"
      #
      #   truncate("<p>Once upon a time in a world far far away</p>")
      #   # => "&lt;p&gt;Once upon a time in a wo..."
      #
      #   truncate("<p>Once upon a time in a world far far away</p>", escape: false)
      #   # => "<p>Once upon a time in a wo..."
      #
      #   truncate("Once upon a time in a world far far away") { link_to "Continue", "#" }
      #   # => "Once upon a time in a world...<a href=\"#\">Continue</a>"
      def truncate(text, options = {}, &block)
        if text
          length  = options.fetch(:length, 30)

          content = text.truncate(length, options)
          content = options[:escape] == false ? content.html_safe : ERB::Util.html_escape(content)
          content << capture(&block) if block_given? && text.length > length
          content
        end
      end

      # Highlights occurrences of +phrases+ in +text+ by formatting them with a
      # highlighter string. +phrases+ can be one or more strings or regular
      # expressions. The result will be marked HTML safe. By default, +text+ is
      # sanitized before highlighting to prevent possible XSS attacks.
      #
      # If a block is specified, it will be used instead of the highlighter
      # string. Each occurrence of a phrase will be passed to the block, and its
      # return value will be inserted into the final result.
      #
      # ==== Options
      #
      # [+:highlighter+]
      #   The highlighter string. Uses <tt>\1</tt> as the placeholder for a
      #   phrase, similar to +String#sub+. Defaults to <tt>"<mark>\1</mark>"</tt>.
      #   This option is ignored if a block is specified.
      #
      # [+:sanitize+]
      #   Whether to sanitize +text+ before highlighting. Defaults to true.
      #
      # ==== Examples
      #
      #   highlight('You searched for: rails', 'rails')
      #   # => "You searched for: <mark>rails</mark>"
      #
      #   highlight('You searched for: rails', /for|rails/)
      #   # => "You searched <mark>for</mark>: <mark>rails</mark>"
      #
      #   highlight('You searched for: ruby, rails, dhh', 'actionpack')
      #   # => "You searched for: ruby, rails, dhh"
      #
      #   highlight('You searched for: rails', ['for', 'rails'], highlighter: '<em>\1</em>')
      #   # => "You searched <em>for</em>: <em>rails</em>"
      #
      #   highlight('You searched for: rails', 'rails', highlighter: '<a href="search?q=\1">\1</a>')
      #   # => "You searched for: <a href=\"search?q=rails\">rails</a>"
      #
      #   highlight('You searched for: rails', 'rails') { |match| link_to(search_path(q: match)) }
      #   # => "You searched for: <a href=\"search?q=rails\">rails</a>"
      #
      #   highlight('<a href="javascript:alert(\'no!\')">ruby</a> on rails', 'rails', sanitize: false)
      #   # => "<a href=\"javascript:alert('no!')\">ruby</a> on <mark>rails</mark>"
      def highlight(text, phrases, options = {}, &block)
        text = sanitize(text) if options.fetch(:sanitize, true)

        if text.blank? || phrases.blank?
          text || ""
        else
          patterns = Array(phrases).map { |phrase| Regexp === phrase ? phrase : Regexp.escape(phrase) }
          pattern = /(#{patterns.join("|")})/i
          highlighter = options.fetch(:highlighter, '<mark>\1</mark>') unless block

          text.scan(/<[^>]*|[^<]+/).each do |segment|
            if !segment.start_with?("<")
              if block
                segment.gsub!(pattern, &block)
              else
                segment.gsub!(pattern, highlighter)
              end
            end
          end.join
        end.html_safe
      end

      # Extracts the first occurrence of +phrase+ plus surrounding text from
      # +text+. An omission marker is prepended / appended if the start / end of
      # the result does not coincide with the start / end of +text+. The result
      # is always stripped in any case. Returns +nil+ if +phrase+ isn't found.
      #
      # ==== Options
      #
      # [+:radius+]
      #   The number of characters (or tokens — see +:separator+ option) around
      #   +phrase+ to include in the result. Defaults to 100.
      #
      # [+:omission+]
      #   The marker to prepend / append when the start / end of the excerpt
      #   does not coincide with the start / end of +text+. Defaults to
      #   <tt>"..."</tt>.
      #
      # [+:separator+]
      #   The separator between tokens to count for +:radius+. Defaults to
      #   <tt>""</tt>, which treats each character as a token.
      #
      # ==== Examples
      #
      #   excerpt('This is an example', 'an', radius: 5)
      #   # => "...s is an exam..."
      #
      #   excerpt('This is an example', 'is', radius: 5)
      #   # => "This is a..."
      #
      #   excerpt('This is an example', 'is')
      #   # => "This is an example"
      #
      #   excerpt('This next thing is an example', 'ex', radius: 2)
      #   # => "...next..."
      #
      #   excerpt('This is also an example', 'an', radius: 8, omission: '<chop> ')
      #   # => "<chop> is also an example"
      #
      #   excerpt('This is a very beautiful morning', 'very', separator: ' ', radius: 1)
      #   # => "...a very beautiful..."
      def excerpt(text, phrase, options = {})
        return unless text && phrase

        separator = options.fetch(:separator, nil) || ""
        case phrase
        when Regexp
          regex = phrase
        else
          regex = /#{Regexp.escape(phrase)}/i
        end

        return unless matches = text.match(regex)
        phrase = matches[0]

        unless separator.empty?
          text.split(separator).each do |value|
            if value.match?(regex)
              phrase = value
              break
            end
          end
        end

        first_part, second_part = text.split(phrase, 2)

        prefix, first_part   = cut_excerpt_part(:first, first_part, separator, options)
        postfix, second_part = cut_excerpt_part(:second, second_part, separator, options)

        affix = [first_part, separator, phrase, separator, second_part].join.strip
        [prefix, affix, postfix].join
      end

      # Attempts to pluralize the +singular+ word unless +count+ is 1. If
      # +plural+ is supplied, it will use that when count is > 1, otherwise
      # it will use the Inflector to determine the plural form for the given locale,
      # which defaults to +I18n.locale+.
      #
      # The word will be pluralized using rules defined for the locale
      # (you must define your own inflection rules for languages other than English).
      # See ActiveSupport::Inflector.pluralize
      #
      #   pluralize(1, 'person')
      #   # => "1 person"
      #
      #   pluralize(2, 'person')
      #   # => "2 people"
      #
      #   pluralize(3, 'person', plural: 'users')
      #   # => "3 users"
      #
      #   pluralize(0, 'person')
      #   # => "0 people"
      #
      #   pluralize(2, 'Person', locale: :de)
      #   # => "2 Personen"
      def pluralize(count, singular, plural_arg = nil, plural: plural_arg, locale: I18n.locale)
        word = if count == 1 || count.to_s.match?(/^1(\.0+)?$/)
          singular
        else
          plural || singular.pluralize(locale)
        end

        "#{count || 0} #{word}"
      end

      # Wraps the +text+ into lines no longer than +line_width+ width. This method
      # breaks on the first whitespace character that does not exceed +line_width+
      # (which is 80 by default).
      #
      #   word_wrap('Once upon a time')
      #   # => "Once upon a time"
      #
      #   word_wrap('Once upon a time, in a kingdom called Far Far Away, a king fell ill, and finding a successor to the throne turned out to be more trouble than anyone could have imagined...')
      #   # => "Once upon a time, in a kingdom called Far Far Away, a king fell ill, and finding\na successor to the throne turned out to be more trouble than anyone could have\nimagined..."
      #
      #   word_wrap('Once upon a time', line_width: 8)
      #   # => "Once\nupon a\ntime"
      #
      #   word_wrap('Once upon a time', line_width: 1)
      #   # => "Once\nupon\na\ntime"
      #
      # You can also specify a custom +break_sequence+ ("\n" by default):
      #
      #   word_wrap('Once upon a time', line_width: 1, break_sequence: "\r\n")
      #   # => "Once\r\nupon\r\na\r\ntime"
      def word_wrap(text, line_width: 80, break_sequence: "\n")
        return +"" if text.empty?

        # Match up to `line_width` characters, followed by one of
        #   (1) non-newline whitespace plus an optional newline
        #   (2) the end of the string, ignoring any trailing newlines
        #   (3) a newline
        #
        # -OR-
        #
        # Match an empty line
        pattern = /(.{1,#{line_width}})(?:[^\S\n]+\n?|\n*\Z|\n)|\n/

        text.gsub(pattern, "\\1#{break_sequence}").chomp!(break_sequence)
      end

      # Returns +text+ transformed into HTML using simple formatting rules.
      # Two or more consecutive newlines (<tt>\n\n</tt> or <tt>\r\n\r\n</tt>) are
      # considered a paragraph and wrapped in <tt><p></tt> tags. One newline
      # (<tt>\n</tt> or <tt>\r\n</tt>) is considered a linebreak and a
      # <tt><br /></tt> tag is appended. This method does not remove the
      # newlines from the +text+.
      #
      # You can pass any HTML attributes into <tt>html_options</tt>. These
      # will be added to all created paragraphs.
      #
      # ==== Options
      # * <tt>:sanitize</tt> - If +false+, does not sanitize +text+.
      # * <tt>:sanitize_options</tt> - Any extra options you want appended to the sanitize.
      # * <tt>:wrapper_tag</tt> - String representing the wrapper tag, defaults to <tt>"p"</tt>
      #
      # ==== Examples
      #   my_text = "Here is some basic text...\n...with a line break."
      #
      #   simple_format(my_text)
      #   # => "<p>Here is some basic text...\n<br />...with a line break.</p>"
      #
      #   simple_format(my_text, {}, wrapper_tag: "div")
      #   # => "<div>Here is some basic text...\n<br />...with a line break.</div>"
      #
      #   more_text = "We want to put a paragraph...\n\n...right there."
      #
      #   simple_format(more_text)
      #   # => "<p>We want to put a paragraph...</p>\n\n<p>...right there.</p>"
      #
      #   simple_format("Look ma! A class!", class: 'description')
      #   # => "<p class='description'>Look ma! A class!</p>"
      #
      #   simple_format("<blink>Unblinkable.</blink>")
      #   # => "<p>Unblinkable.</p>"
      #
      #   simple_format("<blink>Blinkable!</blink> It's true.", {}, sanitize: false)
      #   # => "<p><blink>Blinkable!</blink> It's true.</p>"
      #
      #   simple_format("<a target=\"_blank\" href=\"http://example.com\">Continue</a>", {}, { sanitize_options: { attributes: %w[target href] } })
      #   # => "<p><a target=\"_blank\" href=\"http://example.com\">Continue</a></p>"
      def simple_format(text, html_options = {}, options = {})
        wrapper_tag = options[:wrapper_tag] || "p"

        text = sanitize(text, options.fetch(:sanitize_options, {})) if options.fetch(:sanitize, true)
        paragraphs = split_paragraphs(text)

        if paragraphs.empty?
          content_tag(wrapper_tag, nil, html_options)
        else
          paragraphs.map! { |paragraph|
            content_tag(wrapper_tag, raw(paragraph), html_options)
          }.join("\n\n").html_safe
        end
      end

      # Creates a Cycle object whose +to_s+ method cycles through elements of an
      # array every time it is called. This can be used for example, to alternate
      # classes for table rows. You can use named cycles to allow nesting in loops.
      # Passing a Hash as the last parameter with a <tt>:name</tt> key will create a
      # named cycle. The default name for a cycle without a +:name+ key is
      # <tt>"default"</tt>. You can manually reset a cycle by calling reset_cycle
      # and passing the name of the cycle. The current cycle string can be obtained
      # anytime using the current_cycle method.
      #
      #   <%# Alternate CSS classes for even and odd numbers... %>
      #   <% @items = [1,2,3,4] %>
      #   <table>
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("odd", "even") -%>">
      #       <td><%= item %></td>
      #     </tr>
      #   <% end %>
      #   </table>
      #
      #
      #   <%# Cycle CSS classes for rows, and text colors for values within each row %>
      #   <% @items = [
      #     { first: "Robert", middle: "Daniel", last: "James" },
      #     { first: "Emily", middle: "Shannon", maiden: "Pike", last: "Hicks" },
      #     { first: "June", middle: "Dae", last: "Jones" },
      #   ] %>
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("odd", "even", name: "row_class") -%>">
      #       <td>
      #         <% item.values.each do |value| %>
      #           <%# Create a named cycle "colors" %>
      #           <span style="color:<%= cycle("red", "green", "blue", name: "colors") -%>">
      #             <%= value %>
      #           </span>
      #         <% end %>
      #         <% reset_cycle("colors") %>
      #       </td>
      #    </tr>
      #  <% end %>
      def cycle(first_value, *values)
        options = values.extract_options!
        name = options.fetch(:name, "default")

        values.unshift(*first_value)

        cycle = get_cycle(name)
        unless cycle && cycle.values == values
          cycle = set_cycle(name, Cycle.new(*values))
        end
        cycle.to_s
      end

      # Returns the current cycle string after a cycle has been started. Useful
      # for complex table highlighting or any other design need which requires
      # the current cycle string in more than one place.
      #
      #   <%# Alternate background colors %>
      #   <% @items = [1,2,3,4] %>
      #   <% @items.each do |item| %>
      #     <div style="background-color:<%= cycle("red","white","blue") %>">
      #       <span style="background-color:<%= current_cycle %>"><%= item %></span>
      #     </div>
      #   <% end %>
      def current_cycle(name = "default")
        cycle = get_cycle(name)
        cycle.current_value if cycle
      end

      # Resets a cycle so that it starts from the first element the next time
      # it is called. Pass in +name+ to reset a named cycle.
      #
      #   <%# Alternate CSS classes for even and odd numbers... %>
      #   <% @items = [[1,2,3,4], [5,6,3], [3,4,5,6,7,4]] %>
      #   <table>
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("even", "odd") -%>">
      #         <% item.each do |value| %>
      #           <span style="color:<%= cycle("#333", "#666", "#999", name: "colors") -%>">
      #             <%= value %>
      #           </span>
      #         <% end %>
      #
      #         <% reset_cycle("colors") %>
      #     </tr>
      #   <% end %>
      #   </table>
      def reset_cycle(name = "default")
        cycle = get_cycle(name)
        cycle.reset if cycle
      end

      class Cycle # :nodoc:
        attr_reader :values

        def initialize(first_value, *values)
          @values = values.unshift(first_value)
          reset
        end

        def reset
          @index = 0
        end

        def current_value
          @values[previous_index].to_s
        end

        def to_s
          value = @values[@index].to_s
          @index = next_index
          value
        end

        private
          def next_index
            step_index(1)
          end

          def previous_index
            step_index(-1)
          end

          def step_index(n)
            (@index + n) % @values.size
          end
      end

      private
        # The cycle helpers need to store the cycles in a place that is
        # guaranteed to be reset every time a page is rendered, so it
        # uses an instance variable of ActionView::Base.
        def get_cycle(name)
          @_cycles = Hash.new unless defined?(@_cycles)
          @_cycles[name]
        end

        def set_cycle(name, cycle_object)
          @_cycles = Hash.new unless defined?(@_cycles)
          @_cycles[name] = cycle_object
        end

        def split_paragraphs(text)
          return [] if text.blank?

          text.to_str.gsub(/\r\n?/, "\n").split(/\n\n+/).map! do |t|
            t.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') || t
          end
        end

        def cut_excerpt_part(part_position, part, separator, options)
          return "", "" unless part

          radius   = options.fetch(:radius, 100)
          omission = options.fetch(:omission, "...")

          if separator != ""
            part = part.split(separator)
            part.delete("")
          end

          affix = part.length > radius ? omission : ""

          part =
            if part_position == :first
              part.last(radius)
            else
              part.first(radius)
            end

          if separator != ""
            part = part.join(separator)
          end

          return affix, part
        end
    end
  end
end
