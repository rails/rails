require 'action_view/helpers/tag_helper'
require 'html/document'

module ActionView
  module Helpers #:nodoc:
    # The TextHelper module provides a set of methods for filtering, formatting 
    # and transforming strings, which can reduce the amount of inline Ruby code in 
    # your views. These helper methods extend ActionView making them callable 
    # within your template files.
    module TextHelper  
      # The preferred method of outputting text in your views is to use the 
      # <%= "text" %> eRuby syntax. The regular _puts_ and _print_ methods 
      # do not operate as expected in an eRuby code block. If you absolutely must 
      # output text within a non-output code block (i.e., <% %>), you can use the concat method.
      #
      # ==== Examples
      #   <% 
      #       concat "hello", binding 
      #       # is the equivalent of <%= "hello" %>
      #
      #       if (logged_in == true):
      #         concat "Logged in!", binding
      #       else
      #         concat link_to('login', :action => login), binding
      #       end
      #       # will either display "Logged in!" or a login link
      #   %>
      def concat(string, binding)
        eval(ActionView::Base.erb_variable, binding) << string
      end

      # If +text+ is longer than +length+, +text+ will be truncated to the length of 
      # +length+ (defaults to 30) and the last characters will be replaced with the +truncate_string+
      # (defaults to "...").
      #
      # ==== Examples
      #   truncate("Once upon a time in a world far far away", 14)  
      #   # => Once upon a...
      #
      #   truncate("Once upon a time in a world far far away")  
      #   # => Once upon a time in a world f...
      #
      #   truncate("And they found that many people were sleeping better.", 25, "(clipped)")
      #   # => And they found that many (clipped)
      #
      #   truncate("And they found that many people were sleeping better.", 15, "... (continued)")
      #   # => And they found... (continued)
      def truncate(text, length = 30, truncate_string = "...")
        if text.nil? then return end
        l = length - truncate_string.chars.length
        (text.chars.length > length ? text.chars[0...l] + truncate_string : text).to_s
      end

      # Highlights one or more +phrases+ everywhere in +text+ by inserting it into
      # a +highlighter+ string. The highlighter can be specialized by passing +highlighter+ 
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
      #   highlight('You searched for: rails', ['for', 'rails'], '<em>\1</em>')  
      #   # => You searched <em>for</em>: <em>rails</em>
      # 
      #   highlight('You searched for: rails', 'rails', "<a href='search?q=\1'>\1</a>")
      #   # => You searched for: <a href='search?q=rails>rails</a>
      def highlight(text, phrases, highlighter = '<strong class="highlight">\1</strong>')
        if text.blank? || phrases.blank?
          text
        else
          match = Array(phrases).map { |p| Regexp.escape(p) }.join('|')
          text.gsub(/(#{match})/i, highlighter)
        end
      end

      # Extracts an excerpt from +text+ that matches the first instance of +phrase+. 
      # The +radius+ expands the excerpt on each side of the first occurrence of +phrase+ by the number of characters
      # defined in +radius+ (which defaults to 100). If the excerpt radius overflows the beginning or end of the +text+,
      # then the +excerpt_string+ will be prepended/appended accordingly. If the +phrase+ 
      # isn't found, nil is returned.
      #
      # ==== Examples
      #   excerpt('This is an example', 'an', 5) 
      #   # => "...s is an examp..."
      #
      #   excerpt('This is an example', 'is', 5) 
      #   # => "This is an..."
      #
      #   excerpt('This is an example', 'is') 
      #   # => "This is an example"
      #
      #   excerpt('This next thing is an example', 'ex', 2) 
      #   # => "...next t..."
      #
      #   excerpt('This is also an example', 'an', 8, '<chop> ')
      #   # => "<chop> is also an example"
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
      # breaks on the first whitespace character that does not exceed +line_width+
      # (which is 80 by default).
      #
      # ==== Examples
      #   word_wrap('Once upon a time', 4)
      #   # => Once\nupon\na\ntime
      #
      #   word_wrap('Once upon a time', 8)
      #   # => Once upon\na time
      #
      #   word_wrap('Once upon a time')
      #   # => Once upon a time
      #
      #   word_wrap('Once upon a time', 1)
      #   # => Once\nupon\na\ntime
      def word_wrap(text, line_width = 80)
        text.split("\n").collect do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"
      end

      begin
        require_library_or_gem "redcloth" unless Object.const_defined?(:RedCloth)

        # Returns the text with all the Textile[http://www.textism.com/tools/textile] codes turned into HTML tags.
        #
        # You can learn more about Textile's syntax at its website[http://www.textism.com/tools/textile].
        # <i>This method is only available if RedCloth[http://whytheluckystiff.net/ruby/redcloth/]
        # is available</i>.
        #
        # ==== Examples
        #   textilize("*This is Textile!*  Rejoice!")
        #   # => "<p><strong>This is Textile!</strong>  Rejoice!</p>"
        #
        #   textilize("I _love_ ROR(Ruby on Rails)!")
        #   # => "<p>I <em>love</em> <acronym title="Ruby on Rails">ROR</acronym>!</p>"
        #
        #   textilize("h2. Textile makes markup -easy- simple!")
        #   # => "<h2>Textile makes markup <del>easy</del> simple!</h2>"
        #
        #   textilize("Visit the Rails website "here":http://www.rubyonrails.org/.)
        #   # => "<p>Visit the Rails website <a href="http://www.rubyonrails.org/">here</a>.</p>"
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
        #
        # You can learn more about Textile's syntax at its website[http://www.textism.com/tools/textile].
        # <i>This method is only available if RedCloth[http://whytheluckystiff.net/ruby/redcloth/]
        # is available</i>.
        #
        # ==== Examples
        #   textilize_without_paragraph("*This is Textile!*  Rejoice!")
        #   # => "<strong>This is Textile!</strong>  Rejoice!"
        #
        #   textilize_without_paragraph("I _love_ ROR(Ruby on Rails)!")
        #   # => "I <em>love</em> <acronym title="Ruby on Rails">ROR</acronym>!"
        #
        #   textilize_without_paragraph("h2. Textile makes markup -easy- simple!")
        #   # => "<h2>Textile makes markup <del>easy</del> simple!</h2>"
        #
        #   textilize_without_paragraph("Visit the Rails website "here":http://www.rubyonrails.org/.)
        #   # => "Visit the Rails website <a href="http://www.rubyonrails.org/">here</a>."
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
        #
        # ==== Examples
        #   markdown("We are using __Markdown__ now!")
        #   # => "<p>We are using <strong>Markdown</strong> now!</p>"
        #
        #   markdown("We like to _write_ `code`, not just _read_ it!")
        #   # => "<p>We like to <em>write</em> <code>code</code>, not just <em>read</em> it!</p>"
        #
        #   markdown("The [Markdown website](http://daringfireball.net/projects/markdown/) has more information.")
        #   # => "<p>The <a href="http://daringfireball.net/projects/markdown/">Markdown website</a> 
        #   #     has more information.</p>"
        #
        #   markdown('![The ROR logo](http://rubyonrails.com/images/rails.png "Ruby on Rails")')
        #   # => '<p><img src="http://rubyonrails.com/images/rails.png" alt="The ROR logo" title="Ruby on Rails" /></p>'     
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
      #
      # ==== Examples
      #   my_text = """Here is some basic text...
      #             ...with a line break."""
      #
      #   simple_format(my_text)
      #   # => "<p>Here is some basic text...<br />...with a line break.</p>"
      #
      #   more_text = """We want to put a paragraph...
      #     
      #               ...right there."""
      #
      #   simple_format(more_text)
      #   # => "<p>We want to put a paragraph...</p><p>...right there.</p>"
      def simple_format(text)
        content_tag 'p', text.to_s.
          gsub(/\r\n?/, "\n").                    # \r\n and \r -> \n
          gsub(/\n\n+/, "</p>\n\n<p>").           # 2+ newline  -> paragraph
          gsub(/([^\n]\n)(?=[^\n])/, '\1<br />')  # 1 newline   -> br
      end

      # Turns all URLs and e-mail addresses into clickable links. The +link+ parameter 
      # will limit what should be linked. You can add HTML attributes to the links using
      # +href_options+. Options for +link+ are <tt>:all</tt> (default), 
      # <tt>:email_addresses</tt>, and <tt>:urls</tt>. If a block is given, each URL and 
      # e-mail address is yielded and the result is used as the link text.
      #
      # ==== Examples
      #   auto_link("Go to http://www.rubyonrails.org and say hello to david@loudthinking.com") 
      #   # => "Go to <a href=\"http://www.rubyonrails.org\">http://www.rubyonrails.org</a> and
      #   #     say hello to <a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>"
      #
      #   auto_link("Visit http://www.loudthinking.com/ or e-mail david@loudthinking.com", :urls)
      #   # => "Visit <a href=\"http://www.loudthinking.com/\">http://www.loudthinking.com/</a> 
      #   #     or e-mail david@loudthinking.com"
      #
      #   auto_link("Visit http://www.loudthinking.com/ or e-mail david@loudthinking.com", :email_addresses)
      #   # => "Visit http://www.loudthinking.com/ or e-mail <a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>"
      #
      #   post_body = "Welcome to my new blog at http://www.myblog.com/.  Please e-mail me at me@email.com."
      #   auto_link(post_body, :all, :target => '_blank') do |text|
      #     truncate(text, 15)
      #   end
      #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\" target=\"_blank\">http://www.m...</a>.  
      #         Please e-mail me at <a href=\"mailto:me@email.com\">me@email.com</a>."
      #   
      def auto_link(text, link = :all, href_options = {}, &block)
        return '' if text.blank?
        case link
          when :all             then auto_link_email_addresses(auto_link_urls(text, href_options, &block), &block)
          when :email_addresses then auto_link_email_addresses(text, &block)
          when :urls            then auto_link_urls(text, href_options, &block)
        end
      end
      
      # Creates a Cycle object whose _to_s_ method cycles through elements of an
      # array every time it is called. This can be used for example, to alternate 
      # classes for table rows.  You can use named cycles to allow nesting in loops.  
      # Passing a Hash as the last parameter with a <tt>:name</tt> key will create a 
      # named cycle.  You can manually reset a cycle by calling reset_cycle and passing the 
      # name of the cycle.
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
      #     <tr class="<%= cycle("even", "odd", :name => "row_class") -%>">
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
                          (?:/(?:(?:[~\w\+@%=-]|(?:[,.;:][^\s$]))+)?)* # path
                          (?:\?[\w\+@%&=.;-]+)?     # query string
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
          body = text.dup
          text.gsub(/([\w\.!#\$%\-+.]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)/) do
            text = $1
            
            if body.match(/<a\b[^>]*>(.*)(#{Regexp.escape(text)})(.*)<\/a>/)
              text
            else
              display_text = (block_given?) ? yield(text) : text
              %{<a href="mailto:#{text}">#{display_text}</a>}
            end
          end
        end
    end
  end
end
