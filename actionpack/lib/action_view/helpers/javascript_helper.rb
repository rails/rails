require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # Provides a set of helpers for calling Javascript functions and, most importantly, to call remote methods using what has 
    # been labelled Ajax[http://www.adaptivepath.com/publications/essays/archives/000385.php]. This means that you can call 
    # actions in your controllers without reloading the page, but still update certain parts of it using injections into the 
    # DOM. The common use case is having a form that adds a new element to a list without reloading the page.
    #
    # To be able to use the Javascript helpers, you must either call <tt><%= define_javascript_functions %></tt> (which returns all
    # the Javascript support functions in a <script> block) or reference the Javascript library using 
    # <tt><%= javascript_include_tag "prototype" %></tt> (which looks for the library in /javascripts/prototype.js). The latter is
    # recommended as the browser can then cache the library instead of fetching all the functions anew on every request.
    #
    # If you're the visual type, there's an Ajax movie[http://www.rubyonrails.com/media/video/rails-ajax.mov] demonstrating
    # the use of form_remote_tag.
    module JavascriptHelper      
      unless const_defined? :CALLBACKS
        CALLBACKS       = [ :uninitialized, :loading, :loaded, :interactive, :complete ]
        AJAX_OPTIONS    = [ :url, :asynchronous, :method, :insertion, :form, :with, :update ].concat(CALLBACKS)
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
      # By default, these remote requests are processed asynchronous during 
      # which various callbacks can be triggered (for progress indicators and
      # the likes).
      #
      # Example:
      #   link_to_remote word,
      #       :url => { :action => "undo", :n => word_counter },
      #       :complete => "undoRequestCompleted(request)"
      #
      # The callbacks that may be specified are:
      #
      # <tt>:loading</tt>::       Called when the remote document is being 
      #                           loaded with data by the browser.
      # <tt>:loaded</tt>::        Called when the browser has finished loading
      #                           the remote document.
      # <tt>:interactive</tt>::   Called when the user can interact with the 
      #                           remote document, even though it has not 
      #                           finished loading.
      # <tt>:complete</tt>::      Called when the XMLHttpRequest is complete.
      #
      # If you for some reason or another need synchronous processing (that'll
      # block the browser while the request is happening), you can specify 
      # <tt>options[:type] = :synchronous</tt>.
      #
      # You can customize further browser side call logic by passing
      # in Javascript code snippets via some optional parameters. In
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
      def link_to_remote(name, options = {}, html_options = {})  
        link_to_function(name, remote_function(options), html_options)
      end

      # Periodically calls the specified url (<tt>options[:url]</tt>) every <tt>options[:frequency]</tt> seconds (default is 10).
      # Usually used to update a specified div (<tt>options[:update]</tt>) with the results of the remote call.
      # The options for specifying the target with :url and defining callbacks is the same as link_to_remote.
      def periodically_call_remote(options = {})
         frequency = options[:frequency] || 10 # every ten seconds by default
         code = "new PeriodicalExecuter(function() {#{remote_function(options)}}, #{frequency})"
         content_tag("script", code, options[:html_options] || {})
      end
      
      # Returns a form tag that will submit using XMLHttpRequest in the background instead of the regular 
      # reloading POST arrangement. Even though it's using Javascript to serialize the form elements, the form submission 
      # will work just like a regular submission as viewed by the receiving side (all elements available in @params).
      # The options for specifying the target with :url and defining callbacks is the same as link_to_remote.
      #
      # A "fall-through" target for browsers that doesn't do Javascript can be specified with the :action/:method options on :html
      #
      #   form_remote_tag :html => { :action => url_for(:controller => "some", :action => "place") }
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
        options[:with] = 'Form.serialize(this.form)'

        options[:html] ||= {}
        options[:html][:type] = 'button'
        options[:html][:onclick] = "#{remote_function(options)}; return false;"
        options[:html][:name] = name
        options[:html][:value] = value

        tag("input", options[:html], false)
      end

      def remote_function(options) #:nodoc: for now
        javascript_options = options_for_ajax(options)

        function = options[:update] ? 
          "new Ajax.Updater('#{options[:update]}', " :
          "new Ajax.Request("

        function << "'#{url_for(options[:url])}'"
        function << ", #{javascript_options})"
        
        function = "#{options[:before]}; #{function}" if options[:before]
        function = "#{function}; #{options[:after]}"  if options[:after]
        function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
        function = "if (confirm('#{escape_javascript(options[:confirm])}')) { #{function}; }" if options[:confirm]
	
        return function
      end

      # Includes the Action Pack Javascript libraries inside a single <script> 
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
      # an Ajax call when its contents have changed.
      # 
      # Required +options+ are:
      # <tt>:frequency</tt>:: The frequency (in seconds) at which changes to
      #                       this field will be detected.
      # <tt>:url</tt>::       +url_for+-style options for the action to call
      #                       when the field has changed.
      # 
      # Additional options are:
      # <tt>:update</tt>::    Specifies the DOM ID of the element whose 
      #                       innerHTML should be updated with the
      #                       XMLHttpRequest response text.
      # <tt>:with</tt>::      A Javascript expression specifying the
      #                       parameters for the XMLHttpRequest. This defaults
      #                       to 'value', which in the evaluated context 
      #                       refers to the new field value.
      #
      # Additionally, you may specify any of the options documented in
      # +link_to_remote.
      def observe_field(field_id, options = {})
        build_observer('Form.Element.Observer', field_id, options)
      end
      
      # Like +observe_field+, but operates on an entire form identified by the
      # DOM ID +form_id+. +options+ are the same as +observe_field+, except 
      # the default value of the <tt>:with</tt> option evaluates to the
      # serialized (request string) value of the form.
      def observe_form(form_id, options = {})
        build_observer('Form.Observer', form_id, options)
      end
      
           
      # Adds Ajax autocomplete functionality to the text input field with the 
      # DOM ID specified by +field_id+.
      #
      # This function expects that the called action returns a HTML <ul> list,
      # or nothing if no entries should be displayed for autocompletion.
      # 
      # Required +options+ are:
      # <tt>:url</tt>::       Specifies the DOM ID of the element whose
      #                       innerHTML should be updated with the autocomplete
      #                       entries returned by XMLHttpRequest.
      # 
      # Addtional +options+ are:
      # <tt>:update</tt>::    Specifies the DOM ID of the element whose 
      #                       innerHTML should be updated with the autocomplete
      #                       entries returned by the Ajax request. 
      #                       Defaults to field_id + '_auto_complete'
      # <tt>:with</tt>::      A Javascript expression specifying the
      #                       parameters for the XMLHttpRequest. This defaults
      #                       to 'value', which in the evaluated context 
      #                       refers to the new field value.
      # <tt>:indicator</tt>:: Specifies the DOM ID of an elment which will be
      #                       displayed while autocomplete is running. 
      def auto_complete_field(field_id, options = {})
        function =  "new Ajax.Autocompleter("
        function << "'#{field_id}', "
        function << "'" + (options[:update] || "#{field_id}_auto_complete") + "', "
        function << "'#{url_for(options[:url])}'"

        js_options = {}
        js_options[:callback] = "function(element, value) { return #{options[:with]} }" if options[:with]
        js_options[:indicator] = "'#{options[:indicator]}'" if options[:indicator]
        function << (', ' + options_for_javascript(js_options) + ')')

        javascript_tag(function)
      end
      
      # Use this method in your view to generate a return for the Ajax automplete requests.
      #
      # Example action:
      #
      #   def auto_complete_for_item_title
      #     @items = Item.find(:all, :conditions => [ 'LOWER(description) LIKE ?', 
      #       '%' + params[:for].downcase + '%' ], 'description ASC')
      #     render :inline => '<%= auto_complete_result(@items, 'description') %>'
      #   end
      #
      # The auto_complete_result can of course also be called from a view belonging to the 
      # auto_complete action if you need to decorate it further.
      def auto_complete_result(entries, field, phrase = nil)
        return unless entries
        items = entries.map { |entry| content_tag("li", phrase ? highlight(entry[field], phrase) : h(entry[field])) }
        content_tag("ul", items)
      end
      
      def text_field_with_auto_complete(object, method, tag_options = {}, completion_options = {})
        (completion_options[:skip_style] ? "" : auto_complete_stylesheet) +
        text_field(object, method, tag_options) +
        content_tag("div", "", :id => "#{object}_#{method}_auto_complete", :class => "auto_complete") +
        auto_complete_field("#{object}_#{method}", { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(completion_options))
      end
      
      # Returns a JavaScript snippet to be used on the Ajax callbacks for starting
      # visual effects.
      #
      # Example:
      #   <%= link_to_remote "Reload", :update => "posts", 
      #         :url => { :action => "reload" }, 
      #         :complete => visual_effect(:highlight, "posts", :duration => 0.5 )
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def visual_effect(name, element_id, js_options = {})
        "new Effect.#{name.to_s.capitalize}('#{element_id}',#{options_for_javascript(js_options)});"
      end
      
      # Makes the element with the DOM ID specified by +element_id+ sortable
      # by drag-and-drop and make an Ajax call whenever the sort order has
      # changed. By default, the action called gets the serialized sortable
      # element as parameters.
      #
      # Example:
      #   <%= remote_sortable("my_list", :url => { :action => "order" }) %>
      #
      # In the example, the action gets a "my_list" array parameter 
      # containing the values of the ids of elements the sortable consists 
      # of, in the current order.
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      #
      def remote_sortable(element_id, options = {})
        options[:with]     ||= "Sortable.serialize('#{element_id}')"
        options[:onUpdate] ||= "function(){" + remote_function(options) + "}"
        options.delete_if { |key, value| AJAX_OPTIONS.include?(key) }
        
        javascript_tag("Sortable.create('#{element_id}', #{options_for_javascript(options)})")
      end

      # Escape carrier returns and single and double quotes for Javascript segments.
      def escape_javascript(javascript)
        (javascript || '').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
      end

      # Returns a Javascript tag with the +content+ inside. Example:
      #   javascript_tag "alert('All is good')" # => <script type="text/javascript">alert('All is good')</script>
      def javascript_tag(content)
        content_tag("script", content, :type => "text/javascript")
      end

    private
      def options_for_javascript(options)
        '{' + options.map {|k, v| "#{k}:#{v}"}.join(', ') + '}'
      end
      
      def options_for_ajax(options)
        js_options = build_callbacks(options)
        
        js_options['asynchronous'] = options[:type] != :synchronous
        js_options['method']       = method_option_to_s(options[:method]) if options[:method]
        js_options['insertion']    = "Insertion.#{options[:position].to_s.camelize}" if options[:position]
	
        if options[:form]
          js_options['parameters'] = 'Form.serialize(this)'
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
        javascript = '<script type="text/javascript">'
        javascript << "new #{klass}('#{name}', "
        javascript << "#{options[:frequency]}, function(element, value) {"
        javascript << "#{callback}})</script>"
      end
            
      def build_callbacks(options)
        CALLBACKS.inject({}) do |callbacks, callback|
          if options[callback]
            name = 'on' + callback.to_s.capitalize
            code = options[callback]
            callbacks[name] = "function(request){#{code}}"
          end
          callbacks
        end
      end
      
      def auto_complete_stylesheet
        content_tag("style", <<-EOT
          div.auto_complete {
            width: 350px;
          }
          div.auto_complete ul {
            border:1px solid #888;
            margin:0;
            padding:0;
            width:100%;
            list-style-type:none;
          }
          div.auto_complete ul li {
            margin:0;
            padding:3px;
          }
          div.auto_complete ul li.selected { 
            background-color: #ffb; 
          }
          div.auto_complete ul strong.highlight { 
            color: #800; 
            margin:0;
            padding:0;
          }
        EOT
        )
      end
    end
  end
end
