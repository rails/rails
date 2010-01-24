module ActionView
  module Helpers
    module AjaxHelper
      # Included for backwards compatibility / RJS functionality
      # Rails classes should not be aware of individual JS frameworks
      include PrototypeHelper 

      # Creates a form that will submit using XMLHttpRequest in the background
      # instead of the regular reloading POST arrangement and a scope around a
      # specific resource that is used as a base for questioning about
      # values for the fields.
      #
      # === Resource
      #
      # Example:
      #
      #   # Generates:
      #   #     <form class='edit_post' 
      #   #           id='edit_post_1' 
      #   #           action='/posts/1/edit' 
      #   #           method='post'
      #   #           data-remote='true'>...</div>
      #   #
      #   <% remote_form_for(@post) do |f| %>
      #     ...
      #   <% end %>
      #
      # This will expand to be the same as:
      #
      #   <% remote_form_for :post, @post, :url => post_path(@post), :html => { :method => :put, :class => "edit_post", :id => "edit_post_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # === Nested Resource
      #
      # Example:
      #   # Generates:
      #   #     <form class='edit_post_comment' 
      #   #           id='edit_comment_1' 
      #   #           action='/posts/1/comments/1/edit' 
      #   #           method='post' 
      #   #           data-remote='true'>...</div>
      #   #
      #   <% remote_form_for([@post, @comment]) do |f| %>
      #     ...
      #   <% end %>
      #
      # This will expand to be the same as:
      #
      #   <% remote_form_for :comment, @comment, :url => post_comment_path(@post, @comment), :html => { :method => :put, :class => "edit_comment", :id => "edit_comment_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # If you don't need to attach a form to a resource, then check out form_remote_tag.
      #
      # See FormHelper#form_for for additional semantics.
      def remote_form_for(record_or_name_or_array, *args, &proc)
        options = args.extract_options!
        object_name = extract_object_name_for_form!(args, options, record_or_name_or_array)

        concat(form_remote_tag(options))
        fields_for(object_name, *(args << options), &proc)
        concat('</form>'.html_safe!)
      end
      alias_method :form_remote_for, :remote_form_for

      # Returns a form tag that will submit using XMLHttpRequest in the
      # background instead of the regular reloading POST arrangement. Even
      # though it's using JavaScript to serialize the form elements, the form
      # submission will work just like a regular submission as viewed by the
      # receiving side (all elements available in <tt>params</tt>). The options for
      # specifying the target with <tt>:url</tt> and defining callbacks is the same as
      # +link_to_remote+.
      #
      # A "fall-through" target for browsers that doesn't do JavaScript can be
      # specified with the <tt>:action</tt>/<tt>:method</tt> options on <tt>:html</tt>.
      #
      # Example:
      #
      #   # Generates:
      #   #      <form action='/some/place'
      #   #            method='post'
      #   #            data-remote='true'>...</div>
      #   #
      #   form_remote_tag :html => { :action =>
      #     url_for(:controller => "some", :action => "place") }
      #     < form data-remote action="/some/place" method="post" >
      #
      # The Hash passed to the <tt>:html</tt> key is equivalent to the options (2nd)
      # argument in the FormTagHelper.form_tag method.
      #
      # By default the fall-through action is the same as the one specified in
      # the <tt>:url</tt> (and the default method is <tt>:post</tt>).
      #
      # form_remote_tag also takes a block, like form_tag:
      #   # Generates:
      #   #     <form action='/'
      #   #           method='post'
      #   #           data-remote='true'> 
      #   #       <div><input name="commit" type="submit" value="Save" /></div>
      #   #     </form>
      #   #
      #   <% form_remote_tag :url => '/posts' do -%>
      #     <div><%= submit_tag 'Save' %></div>
      #   <% end -%>

      def form_remote_tag(options = {}, &block)
        html_options = options.delete(:callbacks)

        attributes = {}
        attributes.merge!(extract_remote_attributes!(options))
        attributes.merge!(html_options) if html_options
        attributes.merge!(options)
        attributes.delete(:builder)

        form_tag(attributes.delete(:action) || attributes.delete("data-url"), attributes, &block)
      end

      # Returns a link to a remote action defined by <tt>options[:url]</tt>
      # (using the url_for format) that's called in the background using
      # XMLHttpRequest. The result of that request can then be inserted into a
      # DOM object whose id can be specified with <tt>options[:update]</tt>.
      # Usually, the result would be a partial prepared by the controller with
      # render :partial.
      #
      # Examples:
      #
      #   # Generates: 
      #   #     <a href='/blog/3'
      #   #        rel='nofollow'
      #   #        data-remote='true'
      #   #        data-method='delete' >Delete this post</ a>
      #   #
      #   link_to_remote "Delete this post", :update => "posts",
      #     :url => { :action => "destroy", :id => post.id }
      #
      #   # Generates:  
      #   #   <a data-remote='true' href="/mail/list_emails" rel="nofollow" >
      #   #     <img src='/images/refresh.png'/>
      #   #   </ a>
      #   link_to_remote(image_tag("refresh"), :update => "emails",
      #     :url => { :action => "list_emails" })
      #
      # You can override the generated HTML options by specifying a hash in
      # <tt>options[:html]</tt>.
      #
      #   # Generates:  
      #   #     <a class='destructive' 
      #   #        href='/mail/list_emails' 
      #   #        rel="nofollow" 
      #   #        data-remote='true'>Delete this post</a>
      #   #
      #   link_to_remote "Delete this post", :update => "posts",
      #     :url  => post_url(@post), :method => :delete,
      #     :html => { :class  => "destructive" }
      #
      # You can also specify a hash for <tt>options[:update]</tt> to allow for
      # easy redirection of output to an other DOM element if a server-side
      # error occurs:
      #
      # Example:
      #   # Generates: 
      #   #     <a href='/blog/5' 
      #   #        rel='nofollow'
      #   #        data-remote='true' 
      #   #        data-method='delete' 
      #   #        data-success='posts' 
      #   #        data-failure='error' >Delete this post</a>
      #   #
      #   link_to_remote "Delete this post",
      #     :url => { :action => "destroy", :id => post.id },
      #     :update => { :success => "posts", :failure => "error" }
      #
      # Optionally, you can use the <tt>options[:position]</tt> parameter to
      # influence how the target DOM element is updated. It must be one of
      # <tt>:before</tt>, <tt>:top</tt>, <tt>:bottom</tt>, or <tt>:after</tt>.
      #
      # The method used is by default POST. You can also specify GET or you
      # can simulate PUT or DELETE over POST. All specified with <tt>options[:method]</tt>
      #
      # Example:
      #   # Generates: 
      #   #     <a href='/person/4' 
      #   #        rel='nofollow' 
      #   #        data-remote='true' 
      #   #        data-method='delete'>Destroy</a>
      #   #
      #   link_to_remote "Destroy", :url => person_url(:id => person), :method => :delete
      #
      # By default, these remote requests are processed asynchronous during
      # which various JavaScript callbacks can be triggered (for progress
      # indicators and the likes). All callbacks get access to the
      # <tt>request</tt> object, which holds the underlying XMLHttpRequest.
      #
      # To access the server response, use <tt>request.responseText</tt>, to
      # find out the HTTP status, use <tt>request.status</tt>.
      #
      # Example:
      #   # Generates: 
      #   #     <a href='/words/undo?n=33'
      #   #        data-remote='true' >hello</a>
      #   #
      #   word = 'hello'
      #   link_to_remote word,
      #     :url => { :action => "undo", :n => word_counter },
      #     :complete => "undoRequestCompleted(request)"
      #
      # The callbacks that may be specified are (in order): (deprecated)
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
      #                           (fires after success/failure if they are
      #                           present).
      #
      # You can further refine <tt>:success</tt> and <tt>:failure</tt> by
      # adding additional callbacks for specific status codes.
      #
      # Example:
      #
      #   # Generates:  
      #   #     <a href='/testing/action'
      #   #        date-remote='true'
      #   #        data-failure="function(request){alert('HTTP Error '+ request.status +'+!');return false}"
      #   #        data-404="function(request){alert('Not found...? Wrong URL...?')}"> Hello</a>
      #   #
      #   link_to_remote word,
      #     :url => { :action => "action" },
      #     404 => "alert('Not found...? Wrong URL...?')",
      #     :failure => "alert('HTTP Error ' + request.status + '!')"
      #
      # A status code callback overrides the success/failure handlers if
      # present.
      #
      # If you for some reason or another need synchronous processing (that'll
      # block the browser while the request is happening), you can specify
      # <tt>options[:type] = :synchronous</tt>.
      #
      # You can customize further browser side call logic by passing in
      # JavaScript code snippets via some optional parameters. In their order
      # of use these are:
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
      # <tt>:with</tt>::         A JavaScript expression specifying
      #                          the parameters for the XMLHttpRequest.
      #                          Any expressions should return a valid
      #                          URL query string.
      #
      #                          Example:
      #
      #                            :with => "'name=' + $('name').value"
      #
      # You can generate a link that uses AJAX in the general case, while
      # degrading gracefully to plain link behavior in the absence of
      # JavaScript by setting <tt>html_options[:href]</tt> to an alternate URL.
      # Note the extra curly braces around the <tt>options</tt> hash separate
      # it as the second parameter from <tt>html_options</tt>, the third.
      #
      # Example:
      #
      #   # Generates:
      #   #     <a href='/posts/1' 
      #   #        rel='nofollow' 
      #   #        data-remote='true' 
      #   #        data-method='delete'> Delete this post</a>
      #   #
      #   link_to_remote "Delete this post",
      #     { :update => "posts", :url => { :action => "destroy", :id => post.id } },
      #     :href => url_for(:action => "destroy", :id => post.id)
      def link_to_remote(name, options, html_options = {})
        attributes = {}
        attributes.merge!(:rel => "nofollow") if options[:method] && options[:method].downcase == "delete"
        attributes.merge!(extract_remote_attributes!(options))
        
        if confirm = options.delete(:confirm)
          add_confirm_to_attributes!(attributes, confirm)
        end

        attributes.merge!(html_options)

        content_tag(:a, name, attributes.merge(:href => "#"))
      end
  
      # Creates a button with an onclick event which calls a remote action
      # via XMLHttpRequest
      # The options for specifying the target with :url
      # and defining callbacks is the same as link_to_remote.
      def button_to_remote(name, options = {}, html_options = {})
        attributes = html_options.merge!(:type => "button", :value => name)

        if confirm = options.delete(:confirm)
          add_confirm_to_attributes!(attributes, confirm)
        end

        attributes.merge!(extract_remote_attributes!(options))

        tag(:input, attributes)
      end

      # Returns a button input tag with the element name of +name+ and a value (i.e., display text) of +value+
      # that will submit form using XMLHttpRequest in the background instead of a regular POST request that
      # reloads the page.
      #
      #  # Create a button that submits to the create action
      #  #
      #  # Generates: 
      #  #      <input name='create_btn' 
      #  #             type='button'
      #  #             value='Create'
      #  #             data-remote='true' 
      #  #             data-url='/testing/create' />
      #  #
      #  <%= submit_to_remote 'create_btn', 'Create', :url => { :action => 'create' } %>
      #
      #  # Submit to the remote action update and update the DIV succeed or fail based
      #  # on the success or failure of the request
      #  #
      #  # Generates: 
      #  #    <input name='update_btn'
      #  #           type='button'
      #  #           value='Update'
      #  #           date-remote='true' 
      #  #           data-url='/testing/update' 
      #  #           data-success='succeed' 
      #  #           data-failure='fail' />
      #  #
      #  <%= submit_to_remote 'update_btn', 'Update', :url => { :action => 'update' },
      #     :update => { :success => "succeed", :failure => "fail" }
      #
      # <tt>options</tt> argument is the same as in form_remote_tag.
      def submit_to_remote(name, value, options = {})
        html_options = options.delete(:html) || {}
        html_options.merge!(:name => name, :value => value, :type => "button")

        attributes = extract_remote_attributes!(options)
        attributes.merge!(html_options)
        attributes["data-submit"] = true
        attributes.delete("data-remote")

        tag(:input, attributes)
      end

      # Periodically calls the specified url (<tt>options[:url]</tt>) every
      # <tt>options[:frequency]</tt> seconds (default is 10). Usually used to
      # update a specified div (<tt>options[:update]</tt>) with the results
      # of the remote call. The options for specifying the target with <tt>:url</tt>
      # and defining callbacks is the same as link_to_remote.
      # Examples:
      #  # Call get_averages and put its results in 'avg' every 10 seconds
      #  # Generates:
      #  #      new PeriodicalExecuter(function() {new Ajax.Updater('avg', '/grades/get_averages',
      #  #      {asynchronous:true, evalScripts:true})}, 10)
      #  periodically_call_remote(:url => { :action => 'get_averages' }, :update => 'avg')
      #
      #  # Call invoice every 10 seconds with the id of the customer
      #  # If it succeeds, update the invoice DIV; if it fails, update the error DIV
      #  # Generates:
      #  #      new PeriodicalExecuter(function() {new Ajax.Updater({success:'invoice',failure:'error'},
      #  #      '/testing/invoice/16', {asynchronous:true, evalScripts:true})}, 10)
      #  periodically_call_remote(:url => { :action => 'invoice', :id => customer.id },
      #     :update => { :success => "invoice", :failure => "error" }
      #
      #  # Call update every 20 seconds and update the new_block DIV
      #  # Generates:
      #  # new PeriodicalExecuter(function() {new Ajax.Updater('news_block', 'update', {asynchronous:true, evalScripts:true})}, 20)
      #  periodically_call_remote(:url => 'update', :frequency => '20', :update => 'news_block')
      #
      def periodically_call_remote(options = {})
        attributes = extract_observer_attributes!(options)
        attributes["data-periodical"] = true 

        script_decorator(attributes)
      end

      # Observes the field with the DOM ID specified by +field_id+ and calls a
      # callback when its contents have changed. The default callback is an
      # Ajax call. By default the value of the observed field is sent as a
      # parameter with the Ajax call.
      #
      # Example:
      #  # Generates: new Form.Element.Observer('suggest', 0.25, function(element, value) {new Ajax.Updater('suggest',
      #  #         '/testing/find_suggestion', {asynchronous:true, evalScripts:true, parameters:'q=' + value})})
      #  <%= observe_field :suggest, :url => { :action => :find_suggestion },
      #       :frequency => 0.25,
      #       :update => :suggest,
      #       :with => 'q'
      #       %>
      #
      # Required +options+ are either of:
      # <tt>:url</tt>::       +url_for+-style options for the action to call
      #                       when the field has changed.
      # <tt>:function</tt>::  Instead of making a remote call to a URL, you
      #                       can specify javascript code to be called instead.
      #                       Note that the value of this option is used as the
      #                       *body* of the javascript function, a function definition
      #                       with parameters named element and value will be generated for you
      #                       for example:
      #                         observe_field("glass", :frequency => 1, :function => "alert('Element changed')")
      #                       will generate:
      #                         new Form.Element.Observer('glass', 1, function(element, value) {alert('Element changed')})
      #                       The element parameter is the DOM element being observed, and the value is its value at the
      #                       time the observer is triggered.
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
      # <tt>:with</tt>::      A JavaScript expression specifying the parameters
      #                       for the XMLHttpRequest. The default is to send the
      #                       key and value of the observed field. Any custom
      #                       expressions should return a valid URL query string.
      #                       The value of the field is stored in the JavaScript
      #                       variable +value+.
      #
      #                       Examples
      #
      #                         :with => "'my_custom_key=' + value"
      #                         :with => "'person[name]=' + prompt('New name')"
      #                         :with => "Form.Element.serialize('other-field')"
      #
      #                       Finally
      #                         :with => 'name'
      #                       is shorthand for
      #                         :with => "'name=' + value"
      #                       This essentially just changes the key of the parameter.
      #
      # Additionally, you may specify any of the options documented in the
      # <em>Common options</em> section at the top of this document.
      #
      # Example:
      #
      #   # Sends params: {:title => 'Title of the book'} when the book_title input
      #   # field is changed.
      #   observe_field 'book_title',
      #     :url => 'http://example.com/books/edit/1',
      #     :with => 'title'
      #
      #
      def observe_field(name, options = {})
        options[:observed] = name
        attributes = extract_observer_attributes!(options)

        script_decorator(attributes)
      end
  
      # Observes the form with the DOM ID specified by +form_id+ and calls a
      # callback when its contents have changed. The default callback is an
      # Ajax call. By default all fields of the observed field are sent as
      # parameters with the Ajax call.
      #
      # The +options+ for +observe_form+ are the same as the options for
      # +observe_field+. The JavaScript variable +value+ available to the
      # <tt>:with</tt> option is set to the serialized form by default.
      def observe_form(name, options = {})
        options[:observed] = name
        attributes = extract_observer_attributes!(options)

        script_decorator(attributes)
      end

      def script_decorator(options)
        attributes = %w(type="application/json")
        attributes += options.map{|k, v| k + '="' + v.to_s + '"'}
        "<script " + attributes.join(" ") + "></script>"
      end

      private

        def extract_confirm_attributes!(options)
          attributes = {}

          if options && options[:confirm] 
            attributes["data-confirm"] = options.delete(:confirm)
          end

          attributes
        end

        def extract_remote_attributes!(options)
          attributes = options.delete(:html) || {}

          attributes.merge!(extract_update_attributes!(options))
          attributes.merge!(extract_request_attributes!(options))
          attributes["data-remote"] = true 

          attributes
        end

        def extract_request_attributes!(options)
          attributes = {}
          attributes["data-method"] = options.delete(:method)
          attributes["data-remote-type"] = options.delete(:type)

          url_options = options.delete(:url)
          url_options = url_options.merge(:escape => false) if url_options.is_a?(Hash)
          attributes["data-url"] = escape_javascript(url_for(url_options)) 

          #TODO: Remove all references to prototype - BR
          if options.delete(:form)
            attributes["data-parameters"] = 'Form.serialize(this)'
          elsif submit = options.delete(:submit)
            attributes["data-parameters"] = "Form.serialize('#{submit}')"
          elsif with = options.delete(:with)
            if with !~ /[\{=(.]/
              attributes["data-with"] = "'#{with}=' + encodeURIComponent(value)"
            else
              attributes["data-with"] = with
            end
          end

          purge_unused_attributes!(attributes)
        end

        def extract_update_attributes!(options)
          attributes = {}
          update = options.delete(:update)
          if update.is_a?(Hash)
            attributes["data-update-success"] = update[:success]
            attributes["data-update-failure"] = update[:failure]
          else
            attributes["data-update-success"] = update
          end
          attributes["data-update-position"] = options.delete(:position)

          purge_unused_attributes!(attributes)
        end

        def extract_observer_attributes!(options)
          callback = options.delete(:function)
          frequency = options.delete(:frequency)


          attributes = extract_remote_attributes!(options)
          attributes["data-observe"] = true
          attributes["data-observed"] = options.delete(:observed)
          attributes["data-onobserve"] = create_js_function(callback, "element", "value") if callback
          attributes["data-frequency"] = frequency.to_i if frequency && frequency != 0
          attributes.delete("data-remote")

          purge_unused_attributes!(attributes)
        end

        def purge_unused_attributes!(attributes)
          attributes.delete_if {|key, value| value.nil? }
          attributes
        end

        def create_js_function(statements, *arguments)
          "function(#{arguments.join(", ")}) {#{statements}}"
        end
    end

    # TODO: All evaled goes here per wycat
    module AjaxHelperCompat
      include AjaxHelper

      def link_to_remote(name, options, html_options = {})
        set_callbacks(options, html_options)
        super
      end
      
      def button_to_remote(name, options = {}, html_options = {})
        set_callbacks(options, html_options)
        super
      end

      def form_remote_tag(options, &block)
        html = {}
        set_callbacks(options, html)
        options.merge!(:callbacks => html)
        super
      end

      private
        def set_callbacks(options, html)
          [:before, :after, :uninitialized, :complete, :failure, :success, :interactive, :loaded, :loading].each do |type|
            html["data-on#{type}"]  = options.delete(type.to_sym)
          end

          options.each do |option, value|
            if option.is_a?(Integer)
              html["data-on#{option}"] = options.delete(option)
            end
          end
        end
    end
  end
end
