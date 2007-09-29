require 'action_view/helpers/tag_helper'
require 'html/document'

module ActionView
  module Helpers #:nodoc:
    # The TextHelper module provides a set of methods for filtering, formatting 
    # and transforming strings, which can reduce the amount of inline Ruby code in 
    # your views. These helper methods extend ActionView making them callable 
    # within your template files.
    module TextHelper
      def self.included(base)
        base.extend(ClassMethods)
      end
      
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
      #   # => "Go to <a href="http://www.rubyonrails.org">http://www.rubyonrails.org</a> and
      #   #     say hello to <a href="mailto:david@loudthinking.com">david@loudthinking.com</a>"
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

      # Strips all link tags from +text+ leaving just the link text.
      #
      # ==== Examples
      #   strip_links('<a href="http://www.rubyonrails.org">Ruby on Rails</a>')
      #   # => Ruby on Rails
      #
      #   strip_links('Please e-mail me at <a href="mailto:me@email.com">me@email.com</a>.')
      #   # => Please e-mail me at me@email.com.
      #
      #   strip_links('Blog: <a href="http://www.myblog.com/" class="nav" target=\"_blank\">Visit</a>.')
      #   # => Blog: Visit
      def strip_links(html)
        if !html.blank? && (html.index("<a") || html.index("<href")) && html.index(">")
          tokenizer = HTML::Tokenizer.new(html)
          result = returning [] do |result|
            while token = tokenizer.next 
              node = HTML::Node.parse(nil, 0, 0, token, false) 
              result << node.to_s unless node.is_a?(HTML::Tag) && ["a", "href"].include?(node.name) 
            end 
          end.join
          result == html ? result : strip_links(result) # Recurse - handle all dirty nested links
        else
          html
        end
      end

      # This #sanitize helper will html encode all tags and strip all attributes that aren't specifically allowed.  
      # It also strips href/src tags with invalid protocols, like javascript: especially.  It does its best to counter any
      # tricks that hackers may use, like throwing in unicode/ascii/hex values to get past the javascript: filters.  Check out
      # the extensive test suite.
      #
      #   <%= sanitize @article.body %>
      # 
      # You can add or remove tags/attributes if you want to customize it a bit.  See ActionView::Base for full docs on the
      # available options.  You can add tags/attributes for single uses of #sanitize by passing either the :attributes or :tags options:
      #
      # Normal Use
      #
      #   <%= sanitize @article.body %>
      #
      # Custom Use
      #
      #   <%= sanitize @article.body, :tags => %w(table tr td), :attributes => %w(id class style)
      # 
      # Add table tags
      #   
      #   Rails::Initializer.run do |config|
      #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
      #   end
      # 
      # Remove tags
      #   
      #   Rails::Initializer.run do |config|
      #     config.after_initialize do
      #       ActionView::Base.sanitized_allowed_tags.delete 'div'
      #     end
      #   end
      # 
      # Change allowed attributes
      # 
      #   Rails::Initializer.run do |config|
      #     config.action_view.sanitized_allowed_attributes = 'id', 'class', 'style'
      #   end
      # 
      def sanitize(html, options = {})
        return html if html.blank? || !html.include?('<')
        attrs = options.key?(:attributes) ? Set.new(options[:attributes]).merge(sanitized_allowed_attributes) : sanitized_allowed_attributes
        tags  = options.key?(:tags)       ? Set.new(options[:tags]      ).merge(sanitized_allowed_tags)       : sanitized_allowed_tags
        returning [] do |new_text|
          tokenizer = HTML::Tokenizer.new(html)
          parent    = [] 
          while token = tokenizer.next
            node = HTML::Node.parse(nil, 0, 0, token, false)
            new_text << case node
              when HTML::Tag
                if node.closing == :close
                  parent.shift
                else
                  parent.unshift node.name
                end
                node.attributes.keys.each do |attr_name|
                  value = node.attributes[attr_name].to_s
                  if !attrs.include?(attr_name) || contains_bad_protocols?(attr_name, value)
                    node.attributes.delete(attr_name)
                  else
                    node.attributes[attr_name] = attr_name == 'style' ? sanitize_css(value) : CGI::escapeHTML(value)
                  end
                end if node.attributes
                tags.include?(node.name) ? node : nil
              else
                sanitized_bad_tags.include?(parent.first) ? nil : node.to_s.gsub(/</, "&lt;")
            end
          end
        end.join
      end

      # Sanitizes a block of css code.  Used by #sanitize when it comes across a style attribute
      def sanitize_css(style)
        # disallow urls
        style = style.to_s.gsub(/url\s*\(\s*[^\s)]+?\s*\)\s*/, ' ')

        # gauntlet
        if style !~ /^([:,;#%.\sa-zA-Z0-9!]|\w-\w|\'[\s\w]+\'|\"[\s\w]+\"|\([\d,\s]+\))*$/ ||
            style !~ /^(\s*[-\w]+\s*:\s*[^:;]*(;|$))*$/
          return ''
        end

        returning [] do |clean|
          style.scan(/([-\w]+)\s*:\s*([^:;]*)/) do |prop,val|
            if sanitized_allowed_css_properties.include?(prop.downcase)
              clean <<  prop + ': ' + val + ';'
            elsif sanitized_shorthand_css_properties.include?(prop.split('-')[0].downcase) 
              unless val.split().any? do |keyword|
                !sanitized_allowed_css_keywords.include?(keyword) && 
                  keyword !~ /^(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)$/
              end
                clean << prop + ': ' + val + ';'
              end
            end
          end
        end.join(' ')
      end

      # Strips all HTML tags from the +html+, including comments.  This uses the 
      # html-scanner tokenizer and so its HTML parsing ability is limited by 
      # that of html-scanner.
      #
      # ==== Examples
      #
      #   strip_tags("Strip <i>these</i> tags!")
      #   # => Strip these tags!
      #
      #   strip_tags("<b>Bold</b> no more!  <a href='more.html'>See more here</a>...")
      #   # => Bold no more!  See more here...
      # 
      #   strip_tags("<div id='top-bar'>Welcome to my website!</div>")
      #   # => Welcome to my website!
      def strip_tags(html)     
        return html if html.blank? || !html.index("<")
        tokenizer = HTML::Tokenizer.new(html)

        text = returning [] do |text|
          while token = tokenizer.next
            node = HTML::Node.parse(nil, 0, 0, token, false)
            # result is only the content of any Text nodes
            text << node.to_s if node.class == HTML::Text  
          end
        end
        
        # strip any comments, and if they have a newline at the end (ie. line with
        # only a comment) strip that too
        result = text.join.gsub(/<!--(.*?)-->[\n]?/m, "")
        
        # Recurse - handle all dirty nested tags
        result == html ? result : strip_tags(result)
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
      #     <tr class="<%= cycle("even", "odd", :name => "row_class")
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

      # A regular expression of the valid characters used to separate protocols like
      # the ':' in 'http://foo.com'
      @@sanitized_protocol_separator = /:|(&#0*58)|(&#x70)|(%|&#37;)3A/
      mattr_accessor :sanitized_protocol_separator, :instance_writer => false
      
      # Specifies a Set of HTML attributes that can have URIs.
      @@sanitized_uri_attributes = Set.new(%w(href src cite action longdesc xlink:href lowsrc))
      mattr_reader :sanitized_uri_attributes
      
      # Specifies a Set of 'bad' tags that the #sanitize helper will remove completely, as opposed
      # to just escaping harmless tags like &lt;font&gt;
      @@sanitized_bad_tags = Set.new('script')
      mattr_reader :sanitized_bad_tags
      
      # Specifies the default Set of tags that the #sanitize helper will allow unscathed.
      @@sanitized_allowed_tags = Set.new(%w(strong em b i p code pre tt output samp kbd var sub 
        sup dfn cite big small address hr br div span h1 h2 h3 h4 h5 h6 ul ol li dt dd abbr 
        acronym a img blockquote del ins fieldset legend))
      mattr_reader :sanitized_allowed_tags
      
      # Specifies the default Set of html attributes that the #sanitize helper will leave 
      # in the allowed tag.
      @@sanitized_allowed_attributes = Set.new(%w(href src width height alt cite datetime title class name xml:lang abbr))
      mattr_reader :sanitized_allowed_attributes
      
      # Specifies the default Set of acceptable css properties that #sanitize and #sanitize_css will accept.
      @@sanitized_allowed_css_properties = Set.new(%w(azimuth background-color border-bottom-color border-collapse 
        border-color border-left-color border-right-color border-top-color clear color cursor direction display 
        elevation float font font-family font-size font-style font-variant font-weight height letter-spacing line-height
        overflow pause pause-after pause-before pitch pitch-range richness speak speak-header speak-numeral speak-punctuation
        speech-rate stress text-align text-decoration text-indent unicode-bidi vertical-align voice-family volume white-space
        width))
      mattr_reader :sanitized_allowed_css_properties
      
      # Specifies the default Set of acceptable css keywords that #sanitize and #sanitize_css will accept.
      @@sanitized_allowed_css_keywords = Set.new(%w(auto aqua black block blue bold both bottom brown center
        collapse dashed dotted fuchsia gray green !important italic left lime maroon medium none navy normal
        nowrap olive pointer purple red right solid silver teal top transparent underline white yellow))
      mattr_reader :sanitized_allowed_css_keywords
      
      # Specifies the default Set of allowed shorthand css properties for the #sanitize and #sanitize_css helpers.
      @@sanitized_shorthand_css_properties = Set.new(%w(background border margin padding))
      mattr_reader :sanitized_shorthand_css_properties
      
      # Specifies the default Set of protocols that the #sanitize helper will leave in
      # protocol attributes.
      @@sanitized_allowed_protocols = Set.new(%w(ed2k ftp http https irc mailto news gopher nntp telnet webcal xmpp callto feed svn urn aim rsync tag ssh sftp rtsp afs))
      mattr_reader :sanitized_allowed_protocols

      module ClassMethods #:nodoc:
        def self.extended(base)
          class << base
            # we want these to be class methods on ActionView::Base, they'll get mattr_readers for these below.
            [:sanitized_protocol_separator, :sanitized_uri_attributes, :sanitized_bad_tags, :sanitized_allowed_tags,
                :sanitized_allowed_attributes, :sanitized_allowed_css_properties, :sanitized_allowed_css_keywords,
                :sanitized_shorthand_css_properties, :sanitized_allowed_protocols, :sanitized_protocol_separator=].each do |prop|
              delegate prop, :to => TextHelper
            end
          end
        end

        # Adds valid HTML attributes that the #sanitize helper checks for URIs.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_uri_attributes = 'lowsrc', 'target'
        #   end
        #
        def sanitized_uri_attributes=(attributes)
          Helpers::TextHelper.sanitized_uri_attributes.merge(attributes)
        end

        # Adds to the Set of 'bad' tags for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_bad_tags = 'embed', 'object'
        #   end
        #
        def sanitized_bad_tags=(attributes)
          Helpers::TextHelper.sanitized_bad_tags.merge(attributes)
        end
        # Adds to the Set of allowed tags for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
        #   end
        #
        def sanitized_allowed_tags=(attributes)
          Helpers::TextHelper.sanitized_allowed_tags.merge(attributes)
        end

        # Adds to the Set of allowed html attributes for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_attributes = 'onclick', 'longdesc'
        #   end
        #
        def sanitized_allowed_attributes=(attributes)
          Helpers::TextHelper.sanitized_allowed_attributes.merge(attributes)
        end

        # Adds to the Set of allowed css properties for the #sanitize and #sanitize_css heleprs.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_css_properties = 'expression'
        #   end
        #
        def sanitized_allowed_css_properties=(attributes)
          Helpers::TextHelper.sanitized_allowed_css_properties.merge(attributes)
        end

        # Adds to the Set of allowed css keywords for the #sanitize and #sanitize_css helpers.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_css_keywords = 'expression'
        #   end
        #
        def sanitized_allowed_css_keywords=(attributes)
          Helpers::TextHelper.sanitized_allowed_css_keywords.merge(attributes)
        end

        # Adds to the Set of allowed shorthand css properties for the #sanitize and #sanitize_css helpers.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_shorthand_css_properties = 'expression'
        #   end
        #
        def sanitized_shorthand_css_properties=(attributes)
          Helpers::TextHelper.sanitized_shorthand_css_properties.merge(attributes)
        end

        # Adds to the Set of allowed protocols for the #sanitize helper.
        #
        #   Rails::Initializer.run do |config|
        #     config.action_view.sanitized_allowed_protocols = 'ssh', 'feed'
        #   end
        #
        def sanitized_allowed_protocols=(attributes)
          Helpers::TextHelper.sanitized_allowed_protocols.merge(attributes)
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
                          (?:/(?:(?:[~\w\+@%-]|(?:[,.;:][^\s$]))+)?)* # path
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

        def contains_bad_protocols?(attr_name, value)
          sanitized_uri_attributes.include?(attr_name) && 
          (value =~ /(^[^\/:]*):|(&#0*58)|(&#x70)|(%|&#37;)3A/ && !sanitized_allowed_protocols.include?(value.split(sanitized_protocol_separator).first))
        end
    end
  end
end
