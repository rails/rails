require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    module JavaScriptHelper
      JS_ESCAPE_MAP = {
        '\\'    => '\\\\',
        '</'    => '<\/',
        "\r\n"  => '\n',
        "\n"    => '\n',
        "\r"    => '\n',
        '"'     => '\\"',
        "'"     => "\\'"
      }

      JS_ESCAPE_MAP["\342\200\250".force_encoding(Encoding::UTF_8).encode!] = '&#x2028;'
      JS_ESCAPE_MAP["\342\200\251".force_encoding(Encoding::UTF_8).encode!] = '&#x2029;'

      # Escapes carriage returns and single and double quotes for JavaScript segments.
      #
      # Also available through the alias j(). This is particularly helpful in JavaScript
      # responses, like:
      #
      #   $('some_element').replaceWith('<%=j render 'some/element_template' %>');
      def escape_javascript(javascript)
        if javascript
          result = javascript.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"'])/u) {|match| JS_ESCAPE_MAP[match] }
          javascript.html_safe? ? result.html_safe : result
        else
          ''
        end
      end

      alias_method :j, :escape_javascript

      # Returns a JavaScript tag with the +content+ inside. Example:
      #   javascript_tag "alert('All is good')"
      #
      # Returns:
      #   <script>
      #   //<![CDATA[
      #   alert('All is good')
      #   //]]>
      #   </script>
      #
      # +html_options+ may be a hash of attributes for the <tt>\<script></tt>
      # tag.
      #
      #   javascript_tag "alert('All is good')", defer: 'defer'
      #   # => <script defer="defer">alert('All is good')</script>
      #
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +html_options+ as the first parameter.
      #
      #   <%= javascript_tag defer: 'defer' do -%>
      #     alert('All is good')
      #   <% end -%>
      def javascript_tag(content_or_options_with_block = nil, html_options = {}, &block)
        content =
          if block_given?
            html_options = content_or_options_with_block if content_or_options_with_block.is_a?(Hash)
            capture(&block)
          else
            content_or_options_with_block
          end

        content_tag(:script, javascript_cdata_section(content), html_options)
      end

      def javascript_cdata_section(content) #:nodoc:
        "\n//#{cdata_section("\n#{content}\n//")}\n".html_safe
      end


      # Creates a javascript tag that adds event listeners to an EventSource.
      # +source_name+ is the URI that should be initialized in a new EventSource
      # object. For example: setting +source_name = "message_server"+ will
      # create javascript code like:
      #
      #   var eventStream = new EventSource("message_server");
      #
      # +event_callbacks+ is a hash of event names to javascript functions
      # (both of which are strings). The javascript functions will be called
      # whenever the event they are keyed on occurs. For example:
      #
      #   event_callbacks = {
      #     "message" => "function(e) { console.log(e.data) }",
      #     "error" => "function(e) { console.log("ERROR") }"
      #   }
      #
      # This will create javascript like the following:
      #
      #   eventStream.addEventListener("message", function(e) { console.log(e.data) }, false);
      #   eventStream.addEventListener("error", function(e) { console.log("ERROR") }, false);
      #
      # The +html_options+ may be a hash of attributes for the
      # <tt>\<script></tt> tag. It uses the same syntax as +javascript_tag+.
      #
      def event_source_tag(source_name, event_callbacks = {}, html_options = {})
        javascript = event_stream_subscription("eventStream", source_name, event_callbacks)
        javascript_tag(javascript, html_options)
      end

      # Returns a string of javscript which creates an EventSource variable
      # and adds listeners to it.
      #
      # The newly created EventSource variable will be named
      # +event_source_variable+. The +source_name+ variable gives the URI
      # of the EventSource variable that is created. For example, if
      # +event_source_variable = "eventSource"+ and +source_name = "sse_server"+,
      # then the following code will initialize an EventSource:
      #
      #   var eventSource = new EventSource('sse_server');
      #
      # +event_callbacks+ is a hash which has event names as keys and
      # strings of javascript functions as values. The values correspond
      # to the callback that will be run each time an event is sent which
      # corresponds to the key. For example:
      #
      #   message_callback = "function(e) { console.log(e.data) }"
      #   event_callbacks = {"message" => message_callback}
      #
      # In the above, the +message_callback+ function will be called whenever
      # whenever a "message" event occurs.
      #
      # Here is a full example:
      #
      #   event_source_variable = "eventSource"
      #   source_name = "sse_server"
      #   event_callbacks = {"message" => "function(e) { console.log(e.data) }"}
      # 
      #   event_source_subscription(event_source_variable, source_name, event_callbacks)
      #
      #   # =>
      #   #
      #   # "if (!!window.EventSource) {
      #   #   var eventSource = new EventSource('sse_server');
      #   #   eventSource.addEventListener('message', function(e) { console.log(e.data) }, false);
      #   # }"
      #   #
      def event_source_subscription(event_source_variable, source_name, event_callbacks = {})
        listeners = event_callbacks.map { |event_name, function|
          event_stream_subscription_javascript(event_source_variable, event_name, function)
        }.join("")

        %{if (!!window.EventSource) {
            var #{event_source_variable} = new EventSource('#{source_name}');
            #{listeners}
          }}
      end

      # Returns a string which is javascript code that adds an EventListener
      # to a variable.
      #
      # The event_source_variable a variable holding an EventSource object.
      # For instance, one could use "source" as the event_source_variable 
      # when in javascript "source" is defined as:
      #
      #   var source = new EventSource("stream_name");
      #
      # The event_name is the event to listen to from the EventSource, and
      # the function should be some javascript function to run as a callback
      # whenever such an event is received from the stream.
      #
      # For example:
      #
      #   event_source_variable = "source"
      #   event_name = "message"
      #   function = "function(e) { console.log(e.data) }"
      #
      #   event_stream_subscription_javascript(event_source_variable,
      #       event_name, function)
      #
      #   # =>
      #   #  "source.addEventListener('message', function(e) { console.log(e.data) }, false);"
      #   #
      def event_stream_subscription_javascript(event_source_variable, event_name, function)
        "#{event_source_variable}.addEventListener('#{event_name}', #{function}, false);"
      end

      # Returns a button whose +onclick+ handler triggers the passed JavaScript.
      #
      # The helper receives a name, JavaScript code, and an optional hash of HTML options. The
      # name is used as button label and the JavaScript code goes into its +onclick+ attribute.
      # If +html_options+ has an <tt>:onclick</tt>, that one is put before +function+.
      #
      #   button_to_function "Greeting", "alert('Hello world!')", class: "ok"
      #   # => <input class="ok" onclick="alert('Hello world!');" type="button" value="Greeting" />
      #
      def button_to_function(name, function=nil, html_options={})
        message = "button_to_function is deprecated and will be removed from Rails 4.1. We recomend to use Unobtrusive JavaScript instead. " +
          "See http://guides.rubyonrails.org/working_with_javascript_in_rails.html#unobtrusive-javascript"
        ActiveSupport::Deprecation.warn message

        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function};"

        tag(:input, html_options.merge(:type => 'button', :value => name, :onclick => onclick))
      end

      # Returns a link whose +onclick+ handler triggers the passed JavaScript.
      #
      # The helper receives a name, JavaScript code, and an optional hash of HTML options. The
      # name is used as the link text and the JavaScript code goes into the +onclick+ attribute.
      # If +html_options+ has an <tt>:onclick</tt>, that one is put before +function+. Once all
      # the JavaScript is set, the helper appends "; return false;".
      #
      # The +href+ attribute of the tag is set to "#" unless +html_options+ has one.
      #
      #   link_to_function "Greeting", "alert('Hello world!')", class: "nav_link"
      #   # => <a class="nav_link" href="#" onclick="alert('Hello world!'); return false;">Greeting</a>
      #
      def link_to_function(name, function, html_options={})
        message = "link_to_function is deprecated and will be removed from Rails 4.1. We recomend to use Unobtrusive JavaScript instead. " +
          "See http://guides.rubyonrails.org/working_with_javascript_in_rails.html#unobtrusive-javascript"
        ActiveSupport::Deprecation.warn message

        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;"
        href = html_options[:href] || '#'

        content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
      end
    end
  end
end
