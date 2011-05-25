require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'
require 'action_view/helpers/tag_helper'

module ActionView
  # = Action View Text Helpers
  module Helpers #:nodoc:
    # The TextHelper module provides a set of methods for filtering, formatting
    # and transforming strings, which can reduce the amount of inline Ruby code in
    # your views. These helper methods extend Action View making them callable
    # within your template files.
    #
    # ==== Sanitization
    #
    # Most text helpers by default sanitize the given content, but do not escape it.
    # This means HTML tags will appear in the page but all malicious code will be removed.
    # Let's look at some examples using the +simple_format+ method:
    #
    #   simple_format('<a href="http://example.com/">Example</a>')
    #   # => "<p><a href=\"http://example.com/\">Example</a></p>"
    #
    #   simple_format('<a href="javascript:alert('no!')">Example</a>')
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
      # The preferred method of outputting text in your views is to use the
      # <%= "text" %> eRuby syntax. The regular _puts_ and _print_ methods
      # do not operate as expected in an eRuby code block. If you absolutely must
      # output text within a non-output code block (i.e., <% %>), you can use the concat method.
      #
      # ==== Examples
      #   <%
      #       concat "hello"
      #       # is the equivalent of <%= "hello" %>
      #
      #       if logged_in
      #         concat "Logged in!"
      #       else
      #         concat link_to('login', :action => login)
      #       end
      #       # will either display "Logged in!" or a login link
      #   %>
      def concat(string)
        output_buffer << string
      end

      def safe_concat(string)
        output_buffer.respond_to?(:safe_concat) ? output_buffer.safe_concat(string) : concat(string)
      end

      # Truncates a given +text+ after a given <tt>:length</tt> if +text+ is longer than <tt>:length</tt>
      # (defaults to 30). The last characters will be replaced with the <tt>:omission</tt> (defaults to "...")
      # for a total length not exceeding <tt>:length</tt>.
      #
      # Pass a <tt>:separator</tt> to truncate +text+ at a natural break.
      #
      # The result is not marked as HTML-safe, so will be subject to the default escaping when
      # used in views, unless wrapped by <tt>raw()</tt>. Care should be taken if +text+ contains HTML tags
      # or entities, because truncation may produce invalid HTML (such as unbalanced or incomplete tags).
      #
      # ==== Examples
      #
      #   truncate("Once upon a time in a world far far away")
      #   # => "Once upon a time in a world..."
      #
      #   truncate("Once upon a time in a world far far away", :length => 17)
      #   # => "Once upon a ti..."
      #
      #   truncate("Once upon a time in a world far far away", :length => 17, :separator => ' ')
      #   # => "Once upon a..."
      #
      #   truncate("And they found that many people were sleeping better.", :length => 25, :omission => '... (continued)')
      #   # => "And they f... (continued)"
      #
      #   truncate("<p>Once upon a time in a world far far away</p>")
      #   # => "<p>Once upon a time in a wo..."
      def truncate(text, options = {})
        options.reverse_merge!(:length => 30)
        text.truncate(options.delete(:length), options) if text
      end

      # Highlights one or more +phrases+ everywhere in +text+ by inserting it into
      # a <tt>:highlighter</tt> string. The highlighter can be specialized by passing <tt>:highlighter</tt>
      # as a single-quoted string with \1 where the phrase is to be inserted (defaults to
      # '<strong class="highlight">\1</strong>')
      #
      # ==== Examples
      #   highlight('You searched for: rails', 'rails')
      #   # => You searched for: <strong class="highlight">rails</strong>
      #
      #   highlight('You searched for: ruby, rails, dhh', 'actionpack')
      #   # => You searched for: ruby, rails, dhh
      #
      #   highlight('You searched for: rails', ['for', 'rails'], :highlighter => '<em>\1</em>')
      #   # => You searched <em>for</em>: <em>rails</em>
      #
      #   highlight('You searched for: rails', 'rails', :highlighter => '<a href="search?q=\1">\1</a>')
      #   # => You searched for: <a href="search?q=rails">rails</a>
      #
      # You can still use <tt>highlight</tt> with the old API that accepts the
      # +highlighter+ as its optional third parameter:
      #   highlight('You searched for: rails', 'rails', '<a href="search?q=\1">\1</a>')     # => You searched for: <a href="search?q=rails">rails</a>
      def highlight(text, phrases, *args)
        options = args.extract_options!
        unless args.empty?
          options[:highlighter] = args[0] || '<strong class="highlight">\1</strong>'
        end
        options.reverse_merge!(:highlighter => '<strong class="highlight">\1</strong>')

        if text.present? && phrases.present?
          match = Array(phrases).map { |p| Regexp.escape(p) }.join('|')
          text = text.to_str.gsub(/(#{match})(?!(?:[^<]*?)(?:["'])[^<>]*>)/i, options[:highlighter])
        end
        text = sanitize(text) unless options[:sanitize] == false
        text
      end

      # Extracts an excerpt from +text+ that matches the first instance of +phrase+.
      # The <tt>:radius</tt> option expands the excerpt on each side of the first occurrence of +phrase+ by the number of characters
      # defined in <tt>:radius</tt> (which defaults to 100). If the excerpt radius overflows the beginning or end of the +text+,
      # then the <tt>:omission</tt> option (which defaults to "...") will be prepended/appended accordingly. The resulting string
      # will be stripped in any case. If the +phrase+ isn't found, nil is returned.
      #
      # ==== Examples
      #   excerpt('This is an example', 'an', :radius => 5)
      #   # => ...s is an exam...
      #
      #   excerpt('This is an example', 'is', :radius => 5)
      #   # => This is a...
      #
      #   excerpt('This is an example', 'is')
      #   # => This is an example
      #
      #   excerpt('This next thing is an example', 'ex', :radius => 2)
      #   # => ...next...
      #
      #   excerpt('This is also an example', 'an', :radius => 8, :omission => '<chop> ')
      #   # => <chop> is also an example
      #
      # You can still use <tt>excerpt</tt> with the old API that accepts the
      # +radius+ as its optional third and the +ellipsis+ as its
      # optional forth parameter:
      #   excerpt('This is an example', 'an', 5)                   # => ...s is an exam...
      #   excerpt('This is also an example', 'an', 8, '<chop> ')   # => <chop> is also an example
      def excerpt(text, phrase, *args)
        options = args.extract_options!
        unless args.empty?
          options[:radius] = args[0] || 100
          options[:omission] = args[1] || "..."
        end
        options.reverse_merge!(:radius => 100, :omission => "...")

        if text && phrase
          phrase = Regexp.escape(phrase)

          if found_pos = text.mb_chars =~ /(#{phrase})/i
            start_pos = [ found_pos - options[:radius], 0 ].max
            end_pos   = [ [ found_pos + phrase.mb_chars.length + options[:radius] - 1, 0].max, text.mb_chars.length ].min

            prefix  = start_pos > 0 ? options[:omission] : ""
            postfix = end_pos < text.mb_chars.length - 1 ? options[:omission] : ""

            prefix + text.mb_chars[start_pos..end_pos].strip + postfix
          else
            nil
          end
        end
      end

      # Attempts to pluralize the +singular+ word unless +count+ is 1. If
      # +plural+ is supplied, it will use that when count is > 1, otherwise
      # it will use the Inflector to determine the plural form
      #
      # ==== Examples
      #   pluralize(1, 'person')
      #   # => 1 person
      #
      #   pluralize(2, 'person')
      #   # => 2 people
      #
      #   pluralize(3, 'person', 'users')
      #   # => 3 users
      #
      #   pluralize(0, 'person')
      #   # => 0 people
      def pluralize(count, singular, plural = nil)
        "#{count || 0} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
      end

      # Wraps the +text+ into lines no longer than +line_width+ width. This method
      # breaks on the first whitespace character that does not exceed +line_width+
      # (which is 80 by default).
      #
      # ==== Examples
      #
      #   word_wrap('Once upon a time')
      #   # => Once upon a time
      #
      #   word_wrap('Once upon a time, in a kingdom called Far Far Away, a king fell ill, and finding a successor to the throne turned out to be more trouble than anyone could have imagined...')
      #   # => Once upon a time, in a kingdom called Far Far Away, a king fell ill, and finding\n a successor to the throne turned out to be more trouble than anyone could have\n imagined...
      #
      #   word_wrap('Once upon a time', :line_width => 8)
      #   # => Once upon\na time
      #
      #   word_wrap('Once upon a time', :line_width => 1)
      #   # => Once\nupon\na\ntime
      #
      # You can still use <tt>word_wrap</tt> with the old API that accepts the
      # +line_width+ as its optional second parameter:
      #   word_wrap('Once upon a time', 8)     # => Once upon\na time
      def word_wrap(text, *args)
        options = args.extract_options!
        unless args.blank?
          options[:line_width] = args[0] || 80
        end
        options.reverse_merge!(:line_width => 80)

        text.split("\n").collect do |line|
          line.length > options[:line_width] ? line.gsub(/(.{1,#{options[:line_width]}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"
      end

      # Returns +text+ transformed into HTML using simple formatting rules.
      # Two or more consecutive newlines(<tt>\n\n</tt>) are considered as a
      # paragraph and wrapped in <tt><p></tt> tags. One newline (<tt>\n</tt>) is
      # considered as a linebreak and a <tt><br /></tt> tag is appended. This
      # method does not remove the newlines from the +text+.
      #
      # You can pass any HTML attributes into <tt>html_options</tt>.  These
      # will be added to all created paragraphs.
      # ==== Examples
      #   my_text = "Here is some basic text...\n...with a line break."
      #
      #   simple_format(my_text)
      #   # => "<p>Here is some basic text...\n<br />...with a line break.</p>"
      #
      #   more_text = "We want to put a paragraph...\n\n...right there."
      #
      #   simple_format(more_text)
      #   # => "<p>We want to put a paragraph...</p>\n\n<p>...right there.</p>"
      #
      #   simple_format("Look ma! A class!", :class => 'description')
      #   # => "<p class='description'>Look ma! A class!</p>"
      def simple_format(text, html_options={}, options={})
        text = text ? text.to_str : ''
        text = text.dup if text.frozen?
        start_tag = tag('p', html_options, true)
        text.gsub!(/\r\n?/, "\n")                    # \r\n and \r -> \n
        text.gsub!(/\n\n+/, "</p>\n\n#{start_tag}")  # 2+ newline  -> paragraph
        text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') # 1 newline   -> br
        text.insert 0, start_tag
        text.concat("</p>")
        text = sanitize(text) unless options[:sanitize] == false
        text
      end

      # Turns all URLs and e-mail addresses into clickable links. The <tt>:link</tt> option
      # will limit what should be linked. You can add HTML attributes to the links using
      # <tt>:html</tt>. Possible values for <tt>:link</tt> are <tt>:all</tt> (default),
      # <tt>:email_addresses</tt>, and <tt>:urls</tt>. If a block is given, each URL and
      # e-mail address is yielded and the result is used as the link text.
      #
      # ==== Examples
      #   auto_link("Go to http://www.rubyonrails.org and say hello to david@loudthinking.com")
      #   # => "Go to <a href=\"http://www.rubyonrails.org\">http://www.rubyonrails.org</a> and
      #   #     say hello to <a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>"
      #
      #   auto_link("Visit http://www.loudthinking.com/ or e-mail david@loudthinking.com", :link => :urls)
      #   # => "Visit <a href=\"http://www.loudthinking.com/\">http://www.loudthinking.com/</a>
      #   #     or e-mail david@loudthinking.com"
      #
      #   auto_link("Visit http://www.loudthinking.com/ or e-mail david@loudthinking.com", :link => :email_addresses)
      #   # => "Visit http://www.loudthinking.com/ or e-mail <a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>"
      #
      #   post_body = "Welcome to my new blog at http://www.myblog.com/.  Please e-mail me at me@email.com."
      #   auto_link(post_body, :html => { :target => '_blank' }) do |text|
      #     truncate(text, 15)
      #   end
      #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\" target=\"_blank\">http://www.m...</a>.
      #         Please e-mail me at <a href=\"mailto:me@email.com\">me@email.com</a>."
      #
      #
      # You can still use <tt>auto_link</tt> with the old API that accepts the
      # +link+ as its optional second parameter and the +html_options+ hash
      # as its optional third parameter:
      #   post_body = "Welcome to my new blog at http://www.myblog.com/. Please e-mail me at me@email.com."
      #   auto_link(post_body, :urls)     # => Once upon\na time
      #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\">http://www.myblog.com</a>.
      #         Please e-mail me at me@email.com."
      #
      #   auto_link(post_body, :all, :target => "_blank")     # => Once upon\na time
      #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\" target=\"_blank\">http://www.myblog.com</a>.
      #         Please e-mail me at <a href=\"mailto:me@email.com\">me@email.com</a>."
      def auto_link(text, *args, &block)#link = :all, html = {}, &block)
        return '' if text.blank?

        options = args.size == 2 ? {} : args.extract_options! # this is necessary because the old auto_link API has a Hash as its last parameter
        unless args.empty?
          options[:link] = args[0] || :all
          options[:html] = args[1] || {}
        end
        options.reverse_merge!(:link => :all, :html => {})

        case options[:link].to_sym
          when :all                         then auto_link_email_addresses(auto_link_urls(text, options[:html], options, &block), options[:html], &block)
          when :email_addresses             then auto_link_email_addresses(text, options[:html], &block)
          when :urls                        then auto_link_urls(text, options[:html], options, &block)
        end
      end

      # Creates a Cycle object whose _to_s_ method cycles through elements of an
      # array every time it is called. This can be used for example, to alternate
      # classes for table rows.  You can use named cycles to allow nesting in loops.
      # Passing a Hash as the last parameter with a <tt>:name</tt> key will create a
      # named cycle. The default name for a cycle without a +:name+ key is
      # <tt>"default"</tt>. You can manually reset a cycle by calling reset_cycle
      # and passing the name of the cycle. The current cycle string can be obtained
      # anytime using the current_cycle method.
      #
      # ==== Examples
      #   # Alternate CSS classes for even and odd numbers...
      #   @items = [1,2,3,4]
      #   <table>
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("even", "odd") -%>">
      #       <td>item</td>
      #     </tr>
      #   <% end %>
      #   </table>
      #
      #
      #   # Cycle CSS classes for rows, and text colors for values within each row
      #   @items = x = [{:first => 'Robert', :middle => 'Daniel', :last => 'James'},
      #                {:first => 'Emily', :middle => 'Shannon', :maiden => 'Pike', :last => 'Hicks'},
      #               {:first => 'June', :middle => 'Dae', :last => 'Jones'}]
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("odd", "even", :name => "row_class") -%>">
      #       <td>
      #         <% item.values.each do |value| %>
      #           <%# Create a named cycle "colors" %>
      #           <span style="color:<%= cycle("red", "green", "blue", :name => "colors") -%>">
      #             <%= value %>
      #           </span>
      #         <% end %>
      #         <% reset_cycle("colors") %>
      #       </td>
      #    </tr>
      #  <% end %>
      def cycle(first_value, *values)
        if (values.last.instance_of? Hash)
          params = values.pop
          name = params[:name]
        else
          name = "default"
        end
        values.unshift(first_value)

        cycle = get_cycle(name)
        if (cycle.nil? || cycle.values != values)
          cycle = set_cycle(name, Cycle.new(*values))
        end
        return cycle.to_s
      end

      # Returns the current cycle string after a cycle has been started. Useful
      # for complex table highlighting or any other design need which requires
      # the current cycle string in more than one place.
      #
      # ==== Example
      #   # Alternate background colors
      #   @items = [1,2,3,4]
      #   <% @items.each do |item| %>
      #     <div style="background-color:<%= cycle("red","white","blue") %>">
      #       <span style="background-color:<%= current_cycle %>"><%= item %></span>
      #     </div>
      #   <% end %>
      def current_cycle(name = "default")
        cycle = get_cycle(name)
        cycle.current_value unless cycle.nil?
      end

      # Resets a cycle so that it starts from the first element the next time
      # it is called. Pass in +name+ to reset a named cycle.
      #
      # ==== Example
      #   # Alternate CSS classes for even and odd numbers...
      #   @items = [[1,2,3,4], [5,6,3], [3,4,5,6,7,4]]
      #   <table>
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("even", "odd") -%>">
      #         <% item.each do |value| %>
      #           <span style="color:<%= cycle("#333", "#666", "#999", :name => "colors") -%>">
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
        cycle.reset unless cycle.nil?
      end

      class Cycle #:nodoc:
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
          return value
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
          return @_cycles[name]
        end

        def set_cycle(name, cycle_object)
          @_cycles = Hash.new unless defined?(@_cycles)
          @_cycles[name] = cycle_object
        end

        AUTO_LINK_RE = %r{
            (?: ([\w+.:-]+:)// | www\. )
            [^\s<]+
          }x

        # regexps for determining context, used high-volume
        AUTO_LINK_CRE = [/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]

        AUTO_EMAIL_RE = /[\w.!#\$%+-]+@[\w-]+(?:\.[\w-]+)+/

        BRACKETS = { ']' => '[', ')' => '(', '}' => '{' }

        # Turns all urls into clickable links.  If a block is given, each url
        # is yielded and the result is used as the link text.
        def auto_link_urls(text, html_options = {}, options = {})
          link_attributes = html_options.stringify_keys
          text.to_str.gsub(AUTO_LINK_RE) do
            scheme, href = $1, $&
            punctuation = []

            if auto_linked?($`, $')
              # do not change string; URL is already linked
              href
            else
              # don't include trailing punctuation character as part of the URL
              while href.sub!(/[^\w\/-]$/, '')
                punctuation.push $&
                if opening = BRACKETS[punctuation.last] and href.scan(opening).size > href.scan(punctuation.last).size
                  href << punctuation.pop
                  break
                end
              end

              link_text = block_given? ? yield(href) : href
              href = 'http://' + href unless scheme

              sanitize = options[:sanitize] != false
              content_tag(:a, link_text, link_attributes.merge('href' => href), sanitize) + punctuation.reverse.join('')
            end
          end
        end

        # Turns all email addresses into clickable links.  If a block is given,
        # each email is yielded and the result is used as the link text.
        def auto_link_email_addresses(text, html_options = {}, options = {})
          text.to_str.gsub(AUTO_EMAIL_RE) do
            text = $&

            if auto_linked?($`, $')
              text.html_safe
            else
              display_text = block_given? ? yield(text) : text
              display_text = sanitize(display_text) unless options[:sanitize] == false
              mail_to text, display_text, html_options
            end
          end
        end

        # Detects already linked context or position in the middle of a tag
        def auto_linked?(left, right)
          (left =~ AUTO_LINK_CRE[0] and right =~ AUTO_LINK_CRE[1]) or
            (left.rindex(AUTO_LINK_CRE[2]) and $' !~ AUTO_LINK_CRE[3])
        end
    end
  end
end
