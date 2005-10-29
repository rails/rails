require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # Provides a set of helpers for calling JavaScript functions and, most importantly, to call remote methods using what has 
    # been labelled AJAX[http://www.adaptivepath.com/publications/essays/archives/000385.php]. This means that you can call 
    # actions in your controllers without reloading the page, but still update certain parts of it using injections into the 
    # DOM. The common use case is having a form that adds a new element to a list without reloading the page.
    #
    # To be able to use the JavaScript helpers, you must include the Prototype JavaScript Framework and for some functions
    # script.aculo.us (which both come with Rails) on your pages. Choose one of these options:
    #
    # * Use <tt><%= javascript_include_tag :defaults %></tt> in the HEAD section of your page (recommended):
    #   The function will return references to the JavaScript files created by the +rails+ command in your
    #   <tt>public/javascripts</tt> directory. Using it is recommended as the browser can then cache the libraries
    #   instead of fetching all the functions anew on every request.
    # * Use <tt><%= javascript_include_tag 'prototype' %></tt>: As above, but will only include the Prototype core library,
    #   which means you are able to use all basic AJAX functionality. For the script.aculo.us-based JavaScript helpers,
    #   like visual effects, autocompletion, drag and drop and so on, you should use the method described above.
    # * Use <tt><%= define_javascript_functions %></tt>: this will copy all the JavaScript support functions within a single
    #   script block.
    #
    # For documentation on +javascript_include_tag+ see ActionView::Helpers::AssetTagHelper.
    #
    # If you're the visual type, there's an AJAX movie[http://www.rubyonrails.com/media/video/rails-ajax.mov] demonstrating
    # the use of form_remote_tag.
    module JavaScriptHelper      
      unless const_defined? :CALLBACKS
        CALLBACKS       = 
          [:uninitialized, :loading, :loaded, :interactive, :complete, :failure, :success].push((100..599).to_a).flatten
        AJAX_OPTIONS    = [ :before, :after, :condition, :url, :asynchronous, :method, 
          :insertion, :position, :form, :with, :update, :script ].concat(CALLBACKS)
        JAVASCRIPT_PATH = File.join(File.dirname(__FILE__), 'javascripts')
      end
      
      # Returns a link that'll trigger a javascript +function+ using the 
      # onclick handler and return false after the fact.
      #
      # Examples:
      #   link_to_function "Greeting", "alert('Hello world!')"
      #   link_to_function(image_tag("delete"), "if confirm('Really?'){ do_delete(); }")
      def link_to_function(name, function, html_options = {})
        content_tag(
          "a", name, 
          {:href => "#", :onclick => "#{function}; return false;"}.merge(html_options.symbolize_keys)
        )
      end

      # Returns a link to a remote action defined by <tt>options[:url]</tt> 
      # (using the url_for format) that's called in the background using 
      # XMLHttpRequest. The result of that request can then be inserted into a
      # DOM object whose id can be specified with <tt>options[:update]</tt>. 
      # Usually, the result would be a partial prepared by the controller with
      # either render_partial or render_partial_collection. 
      #
      # Examples:
      #  link_to_remote "Delete this post", :update => "posts", :url => { :action => "destroy", :id => post.id }
      #  link_to_remote(image_tag("refresh"), :update => "emails", :url => { :action => "list_emails" })
      #
      # You can also specify a hash for <tt>options[:update]</tt> to allow for
      # easy redirection of output to an other DOM element if a server-side error occurs:
      #
      # Example:
      #  link_to_remote "Delete this post",
      #      :url => { :action => "destroy", :id => post.id },
      #      :update => { :success => "posts", :failure => "error" }
      #
      # Optionally, you can use the <tt>options[:position]</tt> parameter to influence
      # how the target DOM element is updated. It must be one of 
      # <tt>:before</tt>, <tt>:top</tt>, <tt>:bottom</tt>, or <tt>:after</tt>.
      #
      # By default, these remote requests are processed asynchronous during 
      # which various JavaScript callbacks can be triggered (for progress indicators and
      # the likes). All callbacks get access to the <tt>request</tt> object,
      # which holds the underlying XMLHttpRequest. 
      #
      # To access the server response, use <tt>request.responseText</tt>, to
      # find out the HTTP status, use <tt>request.status</tt>.
      #
      # Example:
      #   link_to_remote word,
      #       :url => { :action => "undo", :n => word_counter },
      #       :complete => "undoRequestCompleted(request)"
      #
      # The callbacks that may be specified are (in order):
      #
      # <tt>:loading</tt>::       Called when the remote document is being 
      #                           loaded with data by the browser.
      # <tt>:loaded</tt>::        Called when the browser has finished loading
      #                           the remote document.
      # <tt>:interactive</tt>::   Called when the user can interact with the 
      #                           remote document, even though it has not 
      #                           finished loading.
      # <tt>:success</tt>::       Called when the XMLHttpRequest is completed,
      #                           and the HTTP status code is in the 2XX range.
      # <tt>:failure</tt>::       Called when the XMLHttpRequest is completed,
      #                           and the HTTP status code is not in the 2XX
      #                           range.
      # <tt>:complete</tt>::      Called when the XMLHttpRequest is complete 
      #                           (fires after success/failure if they are present).,
      #                     
      # You can further refine <tt>:success</tt> and <tt>:failure</tt> by adding additional 
      # callbacks for specific status codes:
      #
      # Example:
      #   link_to_remote word,
      #       :url => { :action => "action" },
      #       404 => "alert('Not found...? Wrong URL...?')",
      #       :failure => "alert('HTTP Error ' + request.status + '!')"
      #
      # A status code callback overrides the success/failure handlers if present.
      #
      # If you for some reason or another need synchronous processing (that'll
      # block the browser while the request is happening), you can specify 
      # <tt>options[:type] = :synchronous</tt>.
      #
      # You can customize further browser side call logic by passing
      # in JavaScript code snippets via some optional parameters. In
      # their order of use these are:
      #
      # <tt>:confirm</tt>::      Adds confirmation dialog.
      # <tt>:condition</tt>::    Perform remote request conditionally
      #                          by this expression. Use this to
      #                          describe browser-side conditions when
      #                          request should not be initiated.
      # <tt>:before</tt>::       Called before request is initiated.
      # <tt>:after</tt>::        Called immediately after request was
      #                          initiated and before <tt>:loading</tt>.
      # <tt>:submit</tt>::       Specifies the DOM element ID that's used
      #                          as the parent of the form elements. By 
      #                          default this is the current form, but
      #                          it could just as well be the ID of a
      #                          table row or any other DOM element.
      def link_to_remote(name, options = {}, html_options = {})  
        link_to_function(name, remote_function(options), html_options)
      end

      # Periodically calls the specified url (<tt>options[:url]</tt>) every <tt>options[:frequency]</tt> seconds (default is 10).
      # Usually used to update a specified div (<tt>options[:update]</tt>) with the results of the remote call.
      # The options for specifying the target with :url and defining callbacks is the same as link_to_remote.
      def periodically_call_remote(options = {})
         frequency = options[:frequency] || 10 # every ten seconds by default
         code = "new PeriodicalExecuter(function() {#{remote_function(options)}}, #{frequency})"
         javascript_tag(code)
      end

      # Returns a form tag that will submit using XMLHttpRequest in the background instead of the regular 
      # reloading POST arrangement. Even though it's using JavaScript to serialize the form elements, the form submission 
      # will work just like a regular submission as viewed by the receiving side (all elements available in @params).
      # The options for specifying the target with :url and defining callbacks is the same as link_to_remote.
      #
      # A "fall-through" target for browsers that doesn't do JavaScript can be specified with the :action/:method options on :html
      #
      #   form_remote_tag :html => { :action => url_for(:controller => "some", :action => "place") }
      # The Hash passed to the :html key is equivalent to the options (2nd) argument in the FormTagHelper.form_tag method.
      #
      # By default the fall-through action is the same as the one specified in the :url (and the default method is :post).
      def form_remote_tag(options = {})
        options[:form] = true

        options[:html] ||= {}
        options[:html][:onsubmit] = "#{remote_function(options)}; return false;"
        options[:html][:action] = options[:html][:action] || url_for(options[:url])
        options[:html][:method] = options[:html][:method] || "post"

        tag("form", options[:html], true)
      end
      
      # Returns a button input tag that will submit form using XMLHttpRequest in the background instead of regular
      # reloading POST arrangement. <tt>options</tt> argument is the same as in <tt>form_remote_tag</tt>
      def submit_to_remote(name, value, options = {})
        options[:with] ||= 'Form.serialize(this.form)'

        options[:html] ||= {}
        options[:html][:type] = 'button'
        options[:html][:onclick] = "#{remote_function(options)}; return false;"
        options[:html][:name] = name
        options[:html][:value] = value

        tag("input", options[:html], false)
      end
      
      # Returns a Javascript function (or expression) that'll update a DOM element according to the options passed.
      #
      # * <tt>:content</tt>: The content to use for updating. Can be left out if using block, see example.
      # * <tt>:action</tt>: Valid options are :update (assumed by default), :empty, :remove
      # * <tt>:position</tt> If the :action is :update, you can optionally specify one of the following positions: :before, :top, :bottom, :after.
      #
      # Examples:
      #   <%= javascript_tag(update_element_function(
      #         "products", :position => :bottom, :content => "<p>New product!</p>")) %>
      #
      #   <% replacement_function = update_element_function("products") do %>
      #     <p>Product 1</p>
      #     <p>Product 2</p>
      #   <% end %>
      #   <%= javascript_tag(replacement_function) %>
      #
      # This method can also be used in combination with remote method call where the result is evaluated afterwards to cause
      # multiple updates on a page. Example:
      #
      #   # Calling view
      #   <%= form_remote_tag :url => { :action => "buy" }, :complete => evaluate_remote_response %>
      #   all the inputs here...
      #
      #   # Controller action
      #   def buy
      #     @product = Product.find(1)
      #   end
      #
      #   # Returning view
      #   <%= update_element_function(
      #         "cart", :action => :update, :position => :bottom, 
      #         :content => "<p>New Product: #{@product.name}</p>")) %>
      #   <% update_element_function("status", :binding => binding) do %>
      #     You've bought a new product!
      #   <% end %>
      #
      # Notice how the second call doesn't need to be in an ERb output block since it uses a block and passes in the binding
      # to render directly. This trick will however only work in ERb (not Builder or other template forms).
      def update_element_function(element_id, options = {}, &block)
        
        content = escape_javascript(options[:content] || '')
        content = escape_javascript(capture(&block)) if block
        
        javascript_function = case (options[:action] || :update)
          when :update
            if options[:position]
              "new Insertion.#{options[:position].to_s.camelize}('#{element_id}','#{content}')"
            else
              "$('#{element_id}').innerHTML = '#{content}'"
            end
          
          when :empty
            "$('#{element_id}').innerHTML = ''"
          
          when :remove
            "Element.remove('#{element_id}')"
          
          else
            raise ArgumentError, "Invalid action, choose one of :update, :remove, :empty"
        end
        
        javascript_function << ";\n"
        options[:binding] ? concat(javascript_function, options[:binding]) : javascript_function
      end
      
      # Returns 'eval(request.responseText)' which is the Javascript function that form_remote_tag can call in :complete to
      # evaluate a multiple update return document using update_element_function calls.
      def evaluate_remote_response
        "eval(request.responseText)"
      end

      # Returns the javascript needed for a remote function.
      # Takes the same arguments as link_to_remote.
      # 
      # Example:
      #   <select id="options" onchange="<%= remote_function(:update => "options", :url => { :action => :update_options }) %>">
      #     <option value="0">Hello</option>
      #     <option value="1">World</option>
      #   </select>
      def remote_function(options)
        javascript_options = options_for_ajax(options)

        update = ''
        if options[:update] and options[:update].is_a?Hash
          update  = []
          update << "success:'#{options[:update][:success]}'" if options[:update][:success]
          update << "failure:'#{options[:update][:failure]}'" if options[:update][:failure]
          update  = '{' + update.join(',') + '}'
        elsif options[:update]
          update << "'#{options[:update]}'"
        end

        function = update.empty? ? 
          "new Ajax.Request(" :
          "new Ajax.Updater(#{update}, "

        function << "'#{url_for(options[:url])}'"
        function << ", #{javascript_options})"

        function = "#{options[:before]}; #{function}" if options[:before]
        function = "#{function}; #{options[:after]}"  if options[:after]
        function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
        function = "if (confirm('#{escape_javascript(options[:confirm])}')) { #{function}; }" if options[:confirm]

        return function
      end

      # Includes the Action Pack JavaScript libraries inside a single <script> 
      # tag. The function first includes prototype.js and then its core extensions,
      # (determined by filenames starting with "prototype").
      # Afterwards, any additional scripts will be included in random order.
      #
      # Note: The recommended approach is to copy the contents of
      # lib/action_view/helpers/javascripts/ into your application's
      # public/javascripts/ directory, and use +javascript_include_tag+ to 
      # create remote <script> links.
      def define_javascript_functions
        javascript = '<script type="text/javascript">'
        
        # load prototype.js and its extensions first 
        prototype_libs = Dir.glob(File.join(JAVASCRIPT_PATH, 'prototype*')).sort.reverse
        prototype_libs.each do |filename| 
          javascript << "\n" << IO.read(filename)
        end
        
        # load other librairies
        (Dir.glob(File.join(JAVASCRIPT_PATH, '*')) - prototype_libs).each do |filename| 
          javascript << "\n" << IO.read(filename)
        end
        javascript << '</script>'
      end

      # Observes the field with the DOM ID specified by +field_id+ and makes
      # an AJAX call when its contents have changed.
      # 
      # Required +options+ are:
      # <tt>:url</tt>::       +url_for+-style options for the action to call
      #                       when the field has changed.
      # 
      # Additional options are:
      # <tt>:frequency</tt>:: The frequency (in seconds) at which changes to
      #                       this field will be detected. Not setting this
      #                       option at all or to a value equal to or less than
      #                       zero will use event based observation instead of
      #                       time based observation.
      # <tt>:update</tt>::    Specifies the DOM ID of the element whose 
      #                       innerHTML should be updated with the
      #                       XMLHttpRequest response text.
      # <tt>:with</tt>::      A JavaScript expression specifying the
      #                       parameters for the XMLHttpRequest. This defaults
      #                       to 'value', which in the evaluated context 
      #                       refers to the new field value.
      #
      # Additionally, you may specify any of the options documented in
      # link_to_remote.
      def observe_field(field_id, options = {})
        if options[:frequency] and options[:frequency] > 0
          build_observer('Form.Element.Observer', field_id, options)
        else
          build_observer('Form.Element.EventObserver', field_id, options)
        end
      end
      
      # Like +observe_field+, but operates on an entire form identified by the
      # DOM ID +form_id+. +options+ are the same as +observe_field+, except 
      # the default value of the <tt>:with</tt> option evaluates to the
      # serialized (request string) value of the form.
      def observe_form(form_id, options = {})
        if options[:frequency]
          build_observer('Form.Observer', form_id, options)
        else
          build_observer('Form.EventObserver', form_id, options)
        end
      end
      
      # Returns a JavaScript snippet to be used on the AJAX callbacks for starting
      # visual effects.
      #
      # This method requires the inclusion of the script.aculo.us JavaScript library.
      #
      # Example:
      #   <%= link_to_remote "Reload", :update => "posts", 
      #         :url => { :action => "reload" }, 
      #         :complete => visual_effect(:highlight, "posts", :duration => 0.5 )
      #
      # If no element_id is given, it assumes "element" which should be a local
      # variable in the generated JavaScript execution context. This can be used
      # for example with drop_receiving_element:
      #
      #   <%= drop_receving_element (...), :loading => visual_effect(:fade) %>
      #
      # This would fade the element that was dropped on the drop receiving element.
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def visual_effect(name, element_id = false, js_options = {})
        element = element_id ? "'#{element_id}'" : "element"
        js_options[:queue] = "'#{js_options[:queue]}'" if js_options[:queue]
        "new Effect.#{name.to_s.camelize}(#{element},#{options_for_javascript(js_options)});"
      end
      
      # Makes the element with the DOM ID specified by +element_id+ sortable
      # by drag-and-drop and make an AJAX call whenever the sort order has
      # changed. By default, the action called gets the serialized sortable
      # element as parameters.
      #
      # This method requires the inclusion of the script.aculo.us JavaScript library.
      #
      # Example:
      #   <%= sortable_element("my_list", :url => { :action => "order" }) %>
      #
      # In the example, the action gets a "my_list" array parameter 
      # containing the values of the ids of elements the sortable consists 
      # of, in the current order.
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def sortable_element(element_id, options = {})
        options[:with]     ||= "Sortable.serialize('#{element_id}')"
        options[:onUpdate] ||= "function(){" + remote_function(options) + "}"
        options.delete_if { |key, value| AJAX_OPTIONS.include?(key) }
        
        [:tag, :overlap, :constraint, :handle].each do |option|
          options[option] = "'#{options[option]}'" if options[option]
        end
        
        options[:containment] = array_or_string_for_javascript(options[:containment]) if options[:containment]
        options[:only] = array_or_string_for_javascript(options[:only]) if options[:only]
        
        javascript_tag("Sortable.create('#{element_id}', #{options_for_javascript(options)})")
      end
      
      # Makes the element with the DOM ID specified by +element_id+ draggable.
      #
      # This method requires the inclusion of the script.aculo.us JavaScript library.
      #
      # Example:
      #   <%= draggable_element("my_image", :revert => true)
      # 
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation. 
      def draggable_element(element_id, options = {})
        javascript_tag("new Draggable('#{element_id}', #{options_for_javascript(options)})")
      end
      
      # Makes the element with the DOM ID specified by +element_id+ receive
      # dropped draggable elements (created by draggable_element).
      # and make an AJAX call  By default, the action called gets the DOM ID of the
      # element as parameter.
      #
      # This method requires the inclusion of the script.aculo.us JavaScript library.
      #
      # Example:
      #   <%= drop_receiving_element("my_cart", :url => { :controller => "cart", :action => "add" }) %>
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def drop_receiving_element(element_id, options = {})
        options[:with]     ||= "'id=' + encodeURIComponent(element.id)"
        options[:onDrop]   ||= "function(element){" + remote_function(options) + "}"
        options.delete_if { |key, value| AJAX_OPTIONS.include?(key) }
        
        options[:accept] = array_or_string_for_javascript(options[:accept]) if options[:accept]    
        options[:hoverclass] = "'#{options[:hoverclass]}'" if options[:hoverclass]
        
        javascript_tag("Droppables.add('#{element_id}', #{options_for_javascript(options)})")
      end

      # Escape carrier returns and single and double quotes for JavaScript segments.
      def escape_javascript(javascript)
        (javascript || '').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
      end

      # Returns a JavaScript tag with the +content+ inside. Example:
      #   javascript_tag "alert('All is good')" # => <script type="text/javascript">alert('All is good')</script>
      def javascript_tag(content)
        content_tag("script", javascript_cdata_section(content), :type => "text/javascript")
      end

      def javascript_cdata_section(content) #:nodoc:
        "\n//#{cdata_section("\n#{content}\n//")}\n"
      end
      
    private
      def options_for_javascript(options)
        '{' + options.map {|k, v| "#{k}:#{v}"}.sort.join(', ') + '}'
      end
      
      def array_or_string_for_javascript(option)
        js_option = if option.kind_of?(Array)
          "['#{option.join('\',\'')}']"
        elsif !option.nil?
          "'#{option}'"
        end
        js_option
      end
      
      def options_for_ajax(options)
        js_options = build_callbacks(options)
        
        js_options['asynchronous'] = options[:type] != :synchronous
        js_options['method']       = method_option_to_s(options[:method]) if options[:method]
        js_options['insertion']    = "Insertion.#{options[:position].to_s.camelize}" if options[:position]
        js_options['evalScripts']  = options[:script].nil? || options[:script]

        if options[:form]
          js_options['parameters'] = 'Form.serialize(this)'
        elsif options[:submit]
          js_options['parameters'] = "Form.serialize(document.getElementById('#{options[:submit]}'))"
        elsif options[:with]
          js_options['parameters'] = options[:with]
        end
        
        options_for_javascript(js_options)
      end

      def method_option_to_s(method) 
        (method.is_a?(String) and !method.index("'").nil?) ? method : "'#{method}'"
      end
      
      def build_observer(klass, name, options = {})
        options[:with] ||= 'value' if options[:update]
        callback = remote_function(options)
        javascript  = "new #{klass}('#{name}', "
        javascript << "#{options[:frequency]}, " if options[:frequency]
        javascript << "function(element, value) {"
        javascript << "#{callback}})"
        javascript_tag(javascript)
      end
            
      def build_callbacks(options)
        callbacks = {}
        options.each do |callback, code|
          if CALLBACKS.include?(callback)
            name = 'on' + callback.to_s.capitalize
            callbacks[name] = "function(request){#{code}}"
          end
        end
        callbacks
      end
      
    end
    
    JavascriptHelper = JavaScriptHelper unless const_defined? :JavascriptHelper
  end
end
