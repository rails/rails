require 'action_view/helpers/tag_helper'
require 'html/document'

module ActionView
  module Helpers #:nodoc:
    # The TextHelper Module provides a set of methods for filtering, formatting 
    # and transforming strings that can reduce the amount of inline Ruby code in 
    # your views. These helper methods extend ActionView making them callable 
    # within your template files as shown in the following example which truncates
    # the title of each post to 10 characters.
    #
    #   <% @posts.each do |post| %>
    #     # post == 'This is my title'
    #     Title: <%= truncate(post.title, 10) %>
    #   <% end %>
    #    => Title: This is my...
    module TextHelper      
      # The preferred method of outputting text in your views is to use the 
      # <%= "text" %> eRuby syntax. The regular _puts_ and _print_ methods 
      # do not operate as expected in an eRuby code block. If you absolutely must 
      # output text within a code block, you can use the concat method.
      #
      #   <% concat "hello", binding %>
      # is equivalent to using:
      #   <%= "hello" %>
      def concat(string, binding)
        eval(ActionView::Base.erb_variable, binding) << string
      end

      # If +text+ is longer than +length+, +text+ will be truncated to the length of 
      # +length+ and the last three characters will be replaced with the +truncate_string+.
      #
      #   truncate("Once upon a time in a world far far away", 14)  
      #    => Once upon a...
      def truncate(text, length = 30, truncate_string = "...")
        if text.nil? then return end
        l = length - truncate_string.chars.length
        (text.chars.length > length ? text.chars[0...l] + truncate_string : text).to_s
      end

      # Highlights one or more +phrases+ everywhere in +text+ by inserting it into
      # a +highlighter+ string. The highlighter can be specialized by passing +highlighter+ 
      # as a single-quoted string with \1 where the phrase is to be inserted.
      #
      #   highlight('You searched for: rails', 'rails')  
      #   # => You searched for: <strong class="highlight">rails</strong>
      #
      #   highlight('You searched for: rails', ['for', 'rails'], '<em>\1</em>')  
      #   # => You searched <em>for</em>: <em>rails</em>
      def highlight(text, phrases, highlighter = '<strong class="highlight">\1</strong>')
        if text.blank? || phrases.blank?
          text
        else
          match = Array(phrases).map { |p| Regexp.escape(p) }.join('|')
          text.gsub(/(#{match})/i, highlighter)
        end
      end

      # Extracts an excerpt from +text+ that matches the first instance of +phrase+. 
      # The +radius+ expands the excerpt on each side of +phrase+ by the number of characters
      # defined in +radius+. If the excerpt radius overflows the beginning or end of the +text+,
      # then the +excerpt_string+ will be prepended/appended accordingly. If the +phrase+ 
      # isn't found, nil is returned.
      #
      #   excerpt('This is an example', 'an', 5) 
      #    => "...s is an examp..."
      #
      #   excerpt('This is an example', 'is', 5) 
      #    => "This is an..."
      def excerpt(text, phrase, radius = 100, excerpt_string = "...")
        if text.nil? || phrase.nil? then return end
        phrase = Regexp.escape(phrase)

        if found_pos = text.chars =~ /(#{phrase})/i
          start_pos = [ found_pos - radius, 0 ].max
          end_pos   = [ found_pos + phrase.chars.length + radius, text.chars.length ].min

          prefix  = start_pos > 0 ? excerpt_string : ""
          postfix = end_pos < text.chars.length ? excerpt_string : ""

          prefix + text.chars[start_pos..end_pos].strip + postfix
        else
          nil
        end
      end

      # Attempts to pluralize the +singular+ word unless +count+ is 1. If +plural+
      # is supplied, it will use that when count is > 1, if the ActiveSupport Inflector 
      # is loaded, it will use the Inflector to determine the plural form, otherwise 
      # it will just add an 's' to the +singular+ word.
      #
      #   pluralize(1, 'person')  => 1 person
      #   pluralize(2, 'person')  => 2 people
      #   pluralize(3, 'person', 'users')  => 3 users
      def pluralize(count, singular, plural = nil)
         "#{count || 0} " + if count == 1 || count == '1'
          singular
        elsif plural
          plural
        elsif Object.const_defined?("Inflector")
          Inflector.pluralize(singular)
        else
          singular + "s"
        end
      end

      # Wraps the +text+ into lines no longer than +line_width+ width. This method
      # breaks on the first whitespace character that does not exceed +line_width+.
      #
      #   word_wrap('Once upon a time', 4)
      #    => Once\nupon\na\ntime
      def word_wrap(text, line_width = 80)
        text.gsub(/\n/, "\n\n").gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip
      end

      begin
        require_library_or_gem "redcloth" unless Object.const_defined?(:RedCloth)

        # Returns the text with all the Textile codes turned into HTML tags.
        # <i>This method is only available if RedCloth[http://whytheluckystiff.net/ruby/redcloth/]
        # is available</i>.
        def textilize(text)
          if text.blank?
            ""
          else
            textilized = RedCloth.new(text, [ :hard_breaks ])
            textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
            textilized.to_html
          end
        end

        # Returns the text with all the Textile codes turned into HTML tags, 
        # but without the bounding <p> tag that RedCloth adds.
        # <i>This method is only available if RedCloth[http://whytheluckystiff.net/ruby/redcloth/]
        # is available</i>.
        def textilize_without_paragraph(text)
          textiled = textilize(text)
          if textiled[0..2] == "<p>" then textiled = textiled[3..-1] end
          if textiled[-4..-1] == "</p>" then textiled = textiled[0..-5] end
          return textiled
        end
      rescue LoadError
        # We can't really help what's not there
      end

      begin
        require_library_or_gem "bluecloth" unless Object.const_defined?(:BlueCloth)

        # Returns the text with all the Markdown codes turned into HTML tags.
        # <i>This method is only available if BlueCloth[http://www.deveiate.org/projects/BlueCloth]
        # is available</i>.
        def markdown(text)
          text.blank? ? "" : BlueCloth.new(text).to_html
        end
      rescue LoadError
        # We can't really help what's not there
      end
      
      # Returns +text+ transformed into HTML using simple formatting rules.
      # Two or more consecutive newlines(<tt>\n\n</tt>) are considered as a 
      # paragraph and wrapped in <tt><p></tt> tags. One newline (<tt>\n</tt>) is
      # considered as a linebreak and a <tt><br /></tt> tag is appended. This
      # method does not remove the newlines from the +text+. 
      def simple_format(text)
        content_tag 'p', text.to_s.
          gsub(/\r\n?/, "\n").                    # \r\n and \r -> \n
          gsub(/\n\n+/, "</p>\n\n<p>").           # 2+ newline  -> paragraph
          gsub(/([^\n]\n)(?=[^\n])/, '\1<br />')  # 1 newline   -> br
      end

      # Turns all urls and email addresses into clickable links. The +link+ parameter 
      # will limit what should be linked. You can add html attributes to the links using
      # +href_options+. Options for +link+ are <tt>:all</tt> (default), 
      # <tt>:email_addresses</tt>, and <tt>:urls</tt>.
      #
      #   auto_link("Go to http://www.rubyonrails.org and say hello to david@loudthinking.com") =>
      #     Go to <a href="http://www.rubyonrails.org">http://www.rubyonrails.org</a> and
      #     say hello to <a href="mailto:david@loudthinking.com">david@loudthinking.com</a>
      #
      # If a block is given, each url and email address is yielded and the
      # result is used as the link text.
      #
      #   auto_link(post.body, :all, :target => '_blank') do |text|
      #     truncate(text, 15)
      #   end
      def auto_link(text, link = :all, href_options = {}, &block)
        return '' if text.blank?
        case link
          when :all             then auto_link_urls(auto_link_email_addresses(text, &block), href_options, &block)
          when :email_addresses then auto_link_email_addresses(text, &block)
          when :urls            then auto_link_urls(text, href_options, &block)
        end
      end

      # Strips link tags from +text+ leaving just the link label.
      #
      #   strip_links('<a href="http://www.rubyonrails.org">Ruby on Rails</a>')
      #    => Ruby on Rails
      def strip_links(text)
        text.gsub(/<a\b.*?>(.*?)<\/a>/mi, '\1')
      end

      VERBOTEN_TAGS = %w(form script plaintext) unless defined?(VERBOTEN_TAGS)
      VERBOTEN_ATTRS = /^on/i unless defined?(VERBOTEN_ATTRS)

      # Sanitizes the +html+ by converting <form> and <script> tags into regular
      # text, and removing all "onxxx" attributes (so that arbitrary Javascript
      # cannot be executed). It also removes href= and src= attributes that start with
      # "javascript:". You can modify what gets sanitized by defining VERBOTEN_TAGS
      # and VERBOTEN_ATTRS before this Module is loaded.
      #
      #   sanitize('<script> do_nasty_stuff() </script>')
      #    => &lt;script> do_nasty_stuff() &lt;/script>
      #   sanitize('<a href="javascript: sucker();">Click here for $100</a>')
      #    => <a>Click here for $100</a>
      def sanitize(html)
        # only do this if absolutely necessary
        if html.index("<")
          tokenizer = HTML::Tokenizer.new(html)
          new_text = ""

          while token = tokenizer.next
            node = HTML::Node.parse(nil, 0, 0, token, false)
            new_text << case node
              when HTML::Tag
                if VERBOTEN_TAGS.include?(node.name)
                  node.to_s.gsub(/</, "&lt;")
                else
                  if node.closing != :close
                    node.attributes.delete_if { |attr,v| attr =~ VERBOTEN_ATTRS }
                    %w(href src).each do |attr|
                      node.attributes.delete attr if node.attributes[attr] =~ /^javascript:/i
                    end
                  end
                  node.to_s
                end
              else
                node.to_s.gsub(/</, "&lt;")
            end
          end

          html = new_text
        end

        html
      end
      
      # Strips all HTML tags from the +html+, including comments.  This uses the 
      # html-scanner tokenizer and so its HTML parsing ability is limited by 
      # that of html-scanner.
      def strip_tags(html)     
        return html if html.blank?
        if html.index("<")
          text = ""
          tokenizer = HTML::Tokenizer.new(html)

          while token = tokenizer.next
            node = HTML::Node.parse(nil, 0, 0, token, false)
            # result is only the content of any Text nodes
            text << node.to_s if node.class == HTML::Text  
          end
          # strip any comments, and if they have a newline at the end (ie. line with
          # only a comment) strip that too
          text.gsub(/<!--(.*?)-->[\n]?/m, "") 
        else
          html # already plain text
        end 
      end
      
      # Creates a Cycle object whose _to_s_ method cycles through elements of an
      # array every time it is called. This can be used for example, to alternate 
      # classes for table rows:
      #
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("even", "odd") -%>">
      #       <td>item</td>
      #     </tr>
      #   <% end %>
      #
      # You can use named cycles to allow nesting in loops.  Passing a Hash as 
      # the last parameter with a <tt>:name</tt> key will create a named cycle.
      # You can manually reset a cycle by calling reset_cycle and passing the 
      # name of the cycle.
      #
      #   <% @items.each do |item| %>
      #     <tr class="<%= cycle("even", "odd", :name => "row_class")
      #       <td>
      #         <% item.values.each do |value| %>
      #           <span style="color:<%= cycle("red", "green", "blue", :name => "colors") -%>">
      #             value
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
      
      # Resets a cycle so that it starts from the first element the next time 
      # it is called. Pass in +name+ to reset a named cycle.
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

        def to_s
          value = @values[@index].to_s
          @index = (@index + 1) % @values.size
          return value
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
                        (                          # leading text
                          <\w+.*?>|                # leading HTML tag, or
                          [^=!:'"/]|               # leading punctuation, or 
                          ^                        # beginning of line
                        )
                        (
                          (?:https?://)|           # protocol spec, or
                          (?:www\.)                # www.*
                        ) 
                        (
                          [-\w]+                   # subdomain or domain
                          (?:\.[-\w]+)*            # remaining subdomains or domain
                          (?::\d+)?                # port
                          (?:/(?:(?:[~\w\+%-]|(?:[,.;:][^\s$]))+)?)* # path
                          (?:\?[\w\+%&=.;-]+)?     # query string
                          (?:\#[\w\-]*)?           # trailing anchor
                        )
                        ([[:punct:]]|\s|<|$)       # trailing text
                       }x unless const_defined?(:AUTO_LINK_RE)

        # Turns all urls into clickable links.  If a block is given, each url
        # is yielded and the result is used as the link text.
        def auto_link_urls(text, href_options = {})
          extra_options = tag_options(href_options.stringify_keys) || ""
          text.gsub(AUTO_LINK_RE) do
            all, a, b, c, d = $&, $1, $2, $3, $4
            if a =~ /<a\s/i # don't replace URL's that are already linked
              all
            else
              text = b + c
              text = yield(text) if block_given?
              %(#{a}<a href="#{b=="www."?"http://www.":b}#{c}"#{extra_options}>#{text}</a>#{d})
            end
          end
        end

        # Turns all email addresses into clickable links.  If a block is given,
        # each email is yielded and the result is used as the link text.
        def auto_link_email_addresses(text)
          text.gsub(/([\w\.!#\$%\-+.]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)/) do
            text = $1
            text = yield(text) if block_given?
            %{<a href="mailto:#{$1}">#{text}</a>}
          end
        end
    end
  end
end
