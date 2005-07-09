require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers #:nodoc:
    # Provides a set of methods for working with text strings that can help unburden the level of inline Ruby code in the
    # templates. In the example below we iterate over a collection of posts provided to the template and prints each title
    # after making sure it doesn't run longer than 20 characters:
    #   <% for post in @posts %>
    #     Title: <%= truncate(post.title, 20) %>
    #   <% end %>
    module TextHelper
      # The regular puts and print are outlawed in eRuby. It's recommended to use the <%= "hello" %> form instead of print "hello".
      # If you absolutely must use a method-based output, you can use concat. It's use like this <% concat "hello", binding %>. Notice that
      # it doesn't have an equal sign in front. Using <%= concat "hello" %> would result in a double hello.
      def concat(string, binding)
        eval("_erbout", binding).concat(string)
      end

      # Truncates +text+ to the length of +length+ and replaces the last three characters with the +truncate_string+
      # if the +text+ is longer than +length+.
      def truncate(text, length = 30, truncate_string = "...")
        if text.nil? then return end
        if text.length > length then text[0..(length - 3)] + truncate_string else text end
      end

      # Highlights the +phrase+ where it is found in the +text+ by surrounding it like
      # <strong class="highlight">I'm a highlight phrase</strong>. The highlighter can be specialized by
      # passing +highlighter+ as single-quoted string with \1 where the phrase is supposed to be inserted.
      # N.B.: The +phrase+ is sanitized to include only letters, digits, and spaces before use.
      def highlight(text, phrase, highlighter = '<strong class="highlight">\1</strong>')
        if phrase.blank? then return text end
        text.gsub(/(#{escape_regexp(phrase)})/i, highlighter) unless text.nil?
      end

      # Extracts an excerpt from the +text+ surrounding the +phrase+ with a number of characters on each side determined
      # by +radius+. If the phrase isn't found, nil is returned. Ex:
      #   excerpt("hello my world", "my", 3) => "...lo my wo..."
      def excerpt(text, phrase, radius = 100, excerpt_string = "...")
        if text.nil? || phrase.nil? then return end
        phrase = escape_regexp(phrase)

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
          text.blank? ? "" : RedCloth.new(text, [ :hard_breaks ]).to_html
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
      
      # Returns +text+ transformed into html using very simple formatting rules
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
      def auto_link(text, link = :all, href_options = {})
        case link
          when :all             then auto_link_urls(auto_link_email_addresses(text), href_options)
          when :email_addresses then auto_link_email_addresses(text)
          when :urls            then auto_link_urls(text, href_options)
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

      
      private
        # Returns a version of the text that's safe to use in a regular expression without triggering engine features.
        def escape_regexp(text)
          text.gsub(/([\\|?+*\/\)\(])/) { |m| "\\#{$1}" }
        end

        # Turns all urls into clickable links.
        def auto_link_urls(text, href_options = {})
          text.gsub(/(<\w+.*?>|[^=!:'"\/]|^)((?:http[s]?:\/\/)|(?:www\.))([^\s<]+\/?)([[:punct:]]|\s|<|$)/) do
            all, a, b, c, d = $&, $1, $2, $3, $4
            if a =~ /<a\s/i # don't replace URL's that are already linked
              all
            else
              extra_options = tag_options(href_options.stringify_keys) || ""
              %(#{a}<a href="#{b=="www."?"http://www.":b}#{c}"#{extra_options}>#{b}#{c}</a>#{d})
            end
          end
        end

        # Turns all email addresses into clickable links.
        def auto_link_email_addresses(text)
          text.gsub(/([\w\.!#\$%\-+.]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)/, '<a href="mailto:\1">\1</a>')
        end
    end
  end
end
