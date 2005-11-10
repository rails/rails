require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers #:nodoc:
    # Provides a set of methods for working with text strings that can help unburden the level of inline Ruby code in the
    # templates. In the example below we iterate over a collection of posts provided to the template and print each title
    # after making sure it doesn't run longer than 20 characters:
    #   <% for post in @posts %>
    #     Title: <%= truncate(post.title, 20) %>
    #   <% end %>
    module TextHelper      
      # The regular puts and print are outlawed in eRuby. It's recommended to use the <%= "hello" %> form instead of print "hello".
      # If you absolutely must use a method-based output, you can use concat. It's used like this: <% concat "hello", binding %>. Notice that
      # it doesn't have an equal sign in front. Using <%= concat "hello" %> would result in a double hello.
      def concat(string, binding)
        eval("_erbout", binding).concat(string)
      end

      # Truncates +text+ to the length of +length+ and replaces the last three characters with the +truncate_string+
      # if the +text+ is longer than +length+.
      def truncate(text, length = 30, truncate_string = "...")
        if text.nil? then return end

        if $KCODE == "NONE"
          text.length > length ? text[0..(length - 3)] + truncate_string : text
        else
          chars = text.split(//)
          chars.length > length ? chars[0..(length-3)].join + truncate_string : text
        end
      end

      # Highlights the +phrase+ where it is found in the +text+ by surrounding it like
      # <strong class="highlight">I'm a highlight phrase</strong>. The highlighter can be specialized by
      # passing +highlighter+ as single-quoted string with \1 where the phrase is supposed to be inserted.
      # N.B.: The +phrase+ is sanitized to include only letters, digits, and spaces before use.
      def highlight(text, phrase, highlighter = '<strong class="highlight">\1</strong>')
        if phrase.blank? then return text end
        text.gsub(/(#{Regexp.escape(phrase)})/i, highlighter) unless text.nil?
      end

      # Extracts an excerpt from the +text+ surrounding the +phrase+ with a number of characters on each side determined
      # by +radius+. If the phrase isn't found, nil is returned. Ex:
      #   excerpt("hello my world", "my", 3) => "...lo my wo..."
      def excerpt(text, phrase, radius = 100, excerpt_string = "...")
        if text.nil? || phrase.nil? then return end
        phrase = Regexp.escape(phrase)

        if found_pos = text =~ /(#{phrase})/i
          start_pos = [ found_pos - radius, 0 ].max
          end_pos   = [ found_pos + phrase.length + radius, text.length ].min

          prefix  = start_pos > 0 ? excerpt_string : ""
          postfix = end_pos < text.length ? excerpt_string : ""

          prefix + text[start_pos..end_pos].strip + postfix
        else
          nil
        end
      end

      # Attempts to pluralize the +singular+ word unless +count+ is 1. See source for pluralization rules.
      def pluralize(count, singular, plural = nil)
         "#{count} " + if count == 1
          singular
        elsif plural
          plural
        elsif Object.const_defined?("Inflector")
          Inflector.pluralize(singular)
        else
          singular + "s"
        end
      end

      # Word wrap long lines to line_width.
      def word_wrap(text, line_width = 80)
        text.gsub(/\n/, "\n\n").gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip
      end

      begin
        require "redcloth"

        # Returns the text with all the Textile codes turned into HTML-tags.
        # <i>This method is only available if RedCloth can be required</i>.
        def textilize(text)
          if text.blank?
            ""
          else
            textilized = RedCloth.new(text, [ :hard_breaks ])
            textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
            textilized.to_html
          end
        end

        # Returns the text with all the Textile codes turned into HTML-tags, but without the regular bounding <p> tag.
        # <i>This method is only available if RedCloth can be required</i>.
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
        require "bluecloth"

        # Returns the text with all the Markdown codes turned into HTML-tags.
        # <i>This method is only available if BlueCloth can be required</i>.
        def markdown(text)
          text.blank? ? "" : BlueCloth.new(text).to_html
        end
      rescue LoadError
        # We can't really help what's not there
      end
      
      # Returns +text+ transformed into HTML using very simple formatting rules
      # Surrounds paragraphs with <tt>&lt;p&gt;</tt> tags, and converts line breaks into <tt>&lt;br /&gt;</tt>
      # Two consecutive newlines(<tt>\n\n</tt>) are considered as a paragraph, one newline (<tt>\n</tt>) is
      # considered a linebreak, three or more consecutive newlines are turned into two newlines 
      def simple_format(text)
        text.gsub!(/(\r\n|\n|\r)/, "\n") # lets make them newlines crossplatform
        text.gsub!(/\n\n+/, "\n\n") # zap dupes
        text.gsub!(/\n\n/, '</p>\0<p>') # turn two newlines into paragraph
        text.gsub!(/([^\n])(\n)([^\n])/, '\1\2<br />\3') # turn single newline into <br />
        
        content_tag("p", text)
      end

      # Turns all urls and email addresses into clickable links. The +link+ parameter can limit what should be linked.
      # Options are :all (default), :email_addresses, and :urls.
      #
      # Example:
      #   auto_link("Go to http://www.rubyonrails.com and say hello to david@loudthinking.com") =>
      #     Go to <a href="http://www.rubyonrails.com">http://www.rubyonrails.com</a> and
      #     say hello to <a href="mailto:david@loudthinking.com">david@loudthinking.com</a>
      #
      # If a block is given, each url and email address is yielded and the
      # result is used as the link text.  Example:
      #   auto_link(post.body, :all, :target => '_blank') do |text|
      #     truncate(text, 15)
      #   end
      def auto_link(text, link = :all, href_options = {}, &block)
        case link
          when :all             then auto_link_urls(auto_link_email_addresses(text, &block), href_options, &block)
          when :email_addresses then auto_link_email_addresses(text, &block)
          when :urls            then auto_link_urls(text, href_options, &block)
        end
      end

      # Turns all links into words, like "<a href="something">else</a>" to "else".
      def strip_links(text)
        text.gsub(/<a.*>(.*)<\/a>/m, '\1')
      end

      # Try to require the html-scanner library
      begin
        require 'html/tokenizer'
        require 'html/node'
      rescue LoadError
        # if there isn't a copy installed, use the vendor version in
        # action controller
        $:.unshift File.join(File.dirname(__FILE__), "..", "..",
                      "action_controller", "vendor", "html-scanner")
        require 'html/tokenizer'
        require 'html/node'
      end

      VERBOTEN_TAGS = %w(form script) unless defined?(VERBOTEN_TAGS)
      VERBOTEN_ATTRS = /^on/i unless defined?(VERBOTEN_ATTRS)

      # Sanitizes the given HTML by making form and script tags into regular
      # text, and removing all "onxxx" attributes (so that arbitrary Javascript
      # cannot be executed). Also removes href attributes that start with
      # "javascript:".
      #
      # Returns the sanitized text.
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
                    if node.attributes["href"] =~ /^javascript:/i
                      node.attributes.delete "href"
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
      
      # Strips all HTML tags from the input, including comments.  This uses the html-scanner
      # tokenizer and so it's HTML parsing ability is limited by that of html-scanner.
      #
      # Returns the tag free text.
      def strip_tags(html)
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
      
      # Returns a Cycle object whose to_s value cycles through items of an
      # array every time it is called. This can be used to alternate classes
      # for table rows:
      #
      # <%- for item in @items do -%>
      #   <tr class="<%= cycle("even", "odd") %>">
      #     ... use item ...
      #   </tr>
      # <%- end -%>
      #
      # You can use named cycles to prevent clashes in nested loops.  You'll
      # have to reset the inner cycle, manually:
      #
      # <%- for item in @items do -%>
      #   <tr class="<%= cycle("even", "odd", :name => "row_class")
      #     <td>
      #       <%- for value in item.values do -%>
      #         <span style="color:'<%= cycle("red", "green", "blue"
      #                                       :name => "colors") %>'">
      #           item
      #         </span>
      #       <%- end -%>
      #       <%- reset_cycle("colors") -%>
      #     </td>
      #   </tr>
      # <%- end -%>
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
      
      # Resets a cycle so that it starts from the first element in the array
      # the next time it is used.
      def reset_cycle(name = "default")
        cycle = get_cycle(name)
        return if cycle.nil?
        cycle.reset
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
          @_cycles = Hash.new if @_cycles.nil?
          return @_cycles[name]
        end
        
        def set_cycle(name, cycle_object)
          @_cycles = Hash.new if @_cycles.nil?
          @_cycles[name] = cycle_object
        end
      
        AUTO_LINK_RE = /
                        (                       # leading text
                          <\w+.*?>|             #   leading HTML tag, or
                          [^=!:'"\/]|           #   leading punctuation, or 
                          ^                     #   beginning of line
                        )
                        (
                          (?:http[s]?:\/\/)|    # protocol spec, or
                          (?:www\.)             # www.*
                        ) 
                        (
                          ([\w]+[=?&\/.-]?)*    # url segment
                          \w+[\/]?              # url tail
                          (?:\#\w*)?            # trailing anchor
                        )
                        ([[:punct:]]|\s|<|$)    # trailing text
                       /x unless const_defined?(:AUTO_LINK_RE)

        # Turns all urls into clickable links.  If a block is given, each url
        # is yielded and the result is used as the link text.  Example:
        #   auto_link_urls(post.body, :all, :target => '_blank') do |text|
        #     truncate(text, 15)
        #   end
        def auto_link_urls(text, href_options = {})
          extra_options = tag_options(href_options.stringify_keys) || ""
          text.gsub(AUTO_LINK_RE) do
            all, a, b, c, d = $&, $1, $2, $3, $5
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
        # Example:
        #   auto_link_email_addresses(post.body) do |text|
        #     truncate(text, 15)
        #   end
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
