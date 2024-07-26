module ActionView
  # The template helpers serves to relieve the templates from including the same inline code again and again. It's a
  # set of standardized methods for working with forms (FormHelper), dates (DateHelper), texts (TextHelper), and 
  # Active Records (ActiveRecordHelper) that's available to all templates by default.
  #
  # It's also really easy to make your own helpers and it's much encouraged to keep the template files free
  # from complicated logic. It's even encouraged to bundle common compositions of methods from other helpers 
  # (often the common helpers) as they're used by the specific application.
  # 
  # Defining a helper requires you to include a specialized +append_features+ method that makes them capable 
  # of configuring their integration upon inclusion in a controller, like this:
  # 
  #   module MyHelper
  #     def self.append_features(controller)
  #       controller.ancestors.include?(ActionController::Base) ?
  #         controller.add_template_helper(self) : super
  #     end
  #   
  #     def hello_world() "hello world" end
  #   end
  # 
  # MyHelper can now be included in a controller, like this:
  # 
  #   require 'my_helper'
  #   class MyController < ActionController::Base
  #     include MyHelper
  #   end
  # 
  # ...and, same as above, used in any template rendered from MyController, like this:
  # 
  # Let's hear what the helper has to say: <tt><%= hello_world %></tt>
  module Helpers
    # Provides a set of methods for working with text strings that can help unburden the level of inline Ruby code in the
    # templates. In the example below we iterate over a collection of posts provided to the template and prints each title 
    # after making sure it doesn't run longer than 20 characters:
    #   <% for post in @posts %>
    #     Title: <%= truncate(post.title, 20) %>
    #   <% end %>
    module TextHelper
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
        if text.nil? || phrase.nil? then return end
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

      begin
        require "redcloth"

        # Returns the text with all the Textile codes turned into HTML-tags. 
        # <i>This method is only available if RedCloth can be required</i>.
        def textilize(text)
          RedCloth.new(text).to_html
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

      # Turns all links into words, like "<a href="something">else</a>" to "else".
      def strip_links(text)
        text.gsub(/<a.*>(.*)<\/a>/, '\1')
      end
      
      private
        # Returns a version of the text that's safe to use in a regular expression without triggering engine features.
        def escape_regexp(text)
          text.gsub(/([\\|?+*\/\)\(])/) { |m| "\\#{$1}" }
        end
    end
  end
end