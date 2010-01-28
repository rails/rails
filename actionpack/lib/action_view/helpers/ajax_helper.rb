module ActionView
  module Helpers
    module AjaxHelper
      # Included for backwards compatibility / RJS functionality
      # Rails classes should not be aware of individual JS frameworks
      include PrototypeHelper 

      # Returns a form that will allow the unobtrusive JavaScript drivers to submit the 
      # form dynamically. The default driver behaviour is an XMLHttpRequest in the background
      # instead of the regular POST arrangement. Even though it's using JavaScript to serialize 
      # the form elements, the form submission will work just like a regular submission as
      # viewed by the receiving side (all elements available in <tt>params</tt>). The options 
      # for specifying the target with <tt>:url</tt> anddefining callbacks is the same as +link_to_remote+.
      #
      # === Resource
      #
      # Example:
      #
      #   # Generates:
      #   #     <form action='/authors' 
      #   #           data-remote='true'
      #   #           class='new_author' 
      #   #           id='create-author' 
      #   #           method='post'> ... </form>
      #   #
      #   <% remote_form_for(@record, {:html => { :id => 'create-author' }}) do |f| %>
      #     ...
      #   <% end %>
      #
      # This will expand to be the same as:
      #
      #   <% remote_form_for :post, @post, :url => post_path(@post), 
      #                                    :html => { :method => :put, 
      #                                               :class => "edit_post", 
      #                                               :id => "edit_post_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # === Nested Resource
      #
      # Example:
      #   # Generates:
      #   #     <form action='/authors/1/articles' 
      #   #           data-remote="true" 
      #   #           class='new_article' 
      #   #           method='post' 
      #   #           id='new_article'></form>
      #   #
      #   <% remote_form_for([@author, @article]) do |f| %>
      #     ...
      #   <% end %>
      #
      # This will expand to be the same as:
      #
      #   <% remote_form_for :article, @article, :url => author_article_path(@author, @article), 
      #                                          :html => { :method => :put, 
      #                                                     :class  => "new_article", 
      #                                                     :id     => "new_comment" } do |f| %>
      #     ...
      #   <% end %>
      #
      # If you don't need to attach a form to a resource, then check out form_remote_tag.
      #
      # See FormHelper#form_for for additional semantics.
      def remote_form_for(record_or_name_or_array, *args, &proc)
        options = args.extract_options!

        if confirm = options.delete(:confirm)
          add_confirm_to_attributes!(options, confirm)
        end

        object_name = extract_object_name_for_form!(args, options, record_or_name_or_array)

        concat(form_remote_tag(options))
        fields_for(object_name, *(args << options), &proc)
        concat('</form>'.html_safe!)
      end
      alias_method :form_remote_for, :remote_form_for

      # Returns a form tag that will allow the unobtrusive JavaScript drivers to submit the 
      # form dynamically. The default JavaScript driver behaviour is an XMLHttpRequest 
      # in the background instead of the regular POST arrangement. Even though it's using 
      # JavaScript to serialize the form elements, the form submission will work just like
      # a regular submission as viewed by the receiving side (all elements available in 
      # <tt>params</tt>). The options for specifying the target with <tt>:url</tt> and 
      # defining callbacks is the same as +link_to_remote+.
      #
      # A "fall-through" target for browsers that doesn't do JavaScript can be
      # specified with the <tt>:action</tt>/<tt>:method</tt> options on <tt>:html</tt>.
      #
      # Example:
      #
      #   # Generates:
      #   #     <form action="http://www.example.com/fast" 
      #   #           method="post" 
      #   #           data-remote="true" 
      #   #           data-update-success="glass_of_beer"></form>
      #   #
      #   form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }) {}
      #
      # The Hash passed to the <tt>:html</tt> key is equivalent to the options (2nd)
      # argument in the FormTagHelper.form_tag method.
      #
      # By default the fall-through action is the same as the one specified in
      # the <tt>:url</tt> (and the default method is <tt>:post</tt>).
      #
      # form_remote_tag also takes a block, like form_tag:
      #   # Generates:
      #   #     <form action='/posts'
      #   #           method='post'
      #   #           data-remote='true'> 
      #   #       <input name="commit" type="submit" value="Save" />
      #   #     </form>
      #   #
      #   <% form_remote_tag :url => '/posts' do -%>
      #     <%= submit_tag 'Save' %>
      #   <% end -%>
      #
      #   # Generates:
      #   #     <form action="http://www.example.com/fast" 
      #   #           method="post" 
      #   #           data-remote="true" 
      #   #           data-update-success="glass_of_beer">Hello world!</form>
      #   #
      #   <% form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }) do -%>
      #     "Hello world!" 
      #   <% end -%>
      #
      def form_remote_tag(options = {}, &block)
        html_options = options.delete(:callbacks)

        attributes = {}
        attributes.merge!(extract_remote_attributes!(options))
        attributes.merge!(html_options) if html_options
        attributes.merge!(options)
        attributes.delete(:builder)

        form_tag(attributes.delete(:action) || attributes.delete("data-url"), attributes, &block)
      end

      # Returns a link that will allow unobtrusive JavaScript to dynamical adjust its
      # behaviour. The default behaviour is an XMLHttpRequest in the background instead 
      # of the regular GET arrangement. The result of that request  can then be inserted 
      # into a DOM object whose id can be specified with <tt>options[:update]</tt>. Usually, 
      # the result would be a partial prepared by the controller with render :partial.
      #
      # Examples:
      #
      #   # Generates:
      #   #     <a href="#" 
      #   #        data-remote="true" 
      #   #        data-url="http://www.example.com/whatnot" 
      #   #        data-method="delete" 
      #   #        rel="nofollow">Remove Author</a>
      #   #
      #   link_to_remote("Remove Author", { :url    => { :action => "whatnot" }, 
      #                                     :method => "delete"})
      #
      #
      # You can override the generated HTML options by specifying a hash in
      # <tt>options[:html]</tt>.
      #
      #   # Generates:
      #   #     <a class="fine" 
      #   #        href="#" 
      #   #        data-remote="true" 
      #   #        data-url="http://www.example.com/whatnot"
      #   #        data-method="delete"
      #   #        rel="nofollow">Remove Author</a>
      #   #
      #   link_to_remote("Remove Author", { :url    => { :action => "whatnot"  }, 
      #                                     :method => "delete",
      #                                     :html   => { :class  => "fine"    }})
      #
      #
      # You can also specify a hash for <tt>options[:update]</tt> to allow for
      # easy redirection of output to an other DOM element if a server-side
      # error occurs:
      #
      # Example:
      #   # Generates: 
      #   #
      #   #     <a href="#" 
      #   #        data-url="http://www.example.com/destroy" 
      #   #        data-update-success="posts" 
      #   #        data-update-failure="error" 
      #   #        data-remote="true">Delete this Post</a>'
      #   #
      #   link_to_remote "Delete this post",
      #     :url => { :action => "destroy"},
      #     :update => { :success => "posts", :failure => "error" }
      #
      # Optionally, you can use the <tt>options[:position]</tt> parameter to
      # influence how the target DOM element is updated. It must be one of
      # <tt>:before</tt>, <tt>:top</tt>, <tt>:bottom</tt>, or <tt>:after</tt>.
      #
      # Example:
      #   # Generates:
      #   #     <a href="#" 
      #   #        data-remote="true" 
      #   #        data-url="http://www.example.com/whatnot" 
      #   #        data-update-position="bottom">Remove Author</a>
      #   #
      #   link_to_remote("Remove Author", :url => { :action => "whatnot" }, :position => :bottom)
      #
      #
      # The method used is by default POST. You can also specify GET or you
      # can simulate PUT or DELETE over POST. All specified with <tt>options[:method]</tt>
      #
      # Example:
      #   # Generates: 
      #   #     <a href='#'
      #   #        data-url='/person/4' 
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
      #   #
      #   #     <a href='#' 
      #   #        data-url='http://www.example.com/undo?n=5' 
      #   #        data-oncomplete='undoRequestCompleted(request)' 
      #   #        data-remote='true'>undo</a>
      #   #
      #   link_to_remote "undo",
      #     :url => { :controller => "words", :action => "undo", :n => word_counter },
      #     :complete => "undoRequestCompleted(request)"
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
      # You can generate a link that uses the UJS drivers in the general case, while
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
      #     { :update => "posts", :url => { :action => "destroy", :id => post.id } }
      #     
      def link_to_remote(name, options, html_options = {})
        attributes = {}

        attributes.merge!(:rel => "nofollow") if options[:method] && options[:method].to_s.downcase == "delete"
        attributes.merge!(extract_remote_attributes!(options))
        
        if confirm = options.delete(:confirm)
          add_confirm_to_attributes!(attributes, confirm)
        end

        attributes.merge!(html_options)
        href = html_options[:href].nil? ? "#" : html_options[:href]
        attributes.merge!(:href => href)

        content_tag(:a, name, attributes)
      end
  
      # Returns an input of type button, which allows the unobtrusive JavaScript driver 
      # to dynamically adjust its behaviour. The default driver behaviour is to call a
      # remote action via XMLHttpRequest in the background.
      # The options for specifying the target with :url and defining callbacks is the same
      # as link_to_remote.
      #
      # Example:
      #   
      #   # Generates:
      #   #     <input class="fine"
      #   #            type="button" 
      #   #            value="Remote outpost" 
      #   #            data-remote="true" 
      #   #            data-url="http://www.example.com/whatnot" />
      #   #
      #   button_to_remote("Remote outpost", { :url => { :action => "whatnot" }}, { :class => "fine"  })
      #
      def button_to_remote(name, options = {}, html_options = {})
        attributes = html_options.merge!(:type => "button", :value => name)

        if confirm = options.delete(:confirm)
          add_confirm_to_attributes!(attributes, confirm)
        end

        if disable_with = options.delete(:disable_with)
          add_disable_with_to_attributes!(attributes, disable_with)
        end

        attributes.merge!(extract_remote_attributes!(options))

        tag(:input, attributes)
      end

      # Returns an input tag of type button, with the element name of +name+ and a value (i.e., display text) 
      # of +value+  which will allow the unobtrusive JavaScript driver to dynamically adjust its behaviour 
      # The default behaviour is to call a remote action via XMLHttpRequest in the background.
      #
      # request that reloads the page.
      #
      #  # Create a button that submits to the create action
      #  #
      #  # Generates: 
      #  #      <input name='create_btn' 
      #  #             type='button'
      #  #             value='Create'
      #  #             data-remote='true' 
      #  #             data-url='/create' />
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
      #  #           date-remote-submit='true' 
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
        attributes["data-remote-submit"] = true
        attributes.delete("data-remote")

        tag(:input, attributes)
      end

      # Periodically provides the UJS driver with the information to call the specified 
      # url (<tt>options[:url]</tt>) every <tt>options[:frequency]</tt> seconds (default is 10). Usually used to
      # update a specified div (<tt>options[:update]</tt>) with the results
      # of the remote call. The options for specifying the target with <tt>:url</tt>
      # and defining callbacks is the same as link_to_remote.
      # Examples:
      #  # Call get_averages and put its results in 'avg' every 10 seconds
      #  # Generates:
      #  #      <script data-periodical='true' 
      #  #              data-url='/get_averages' 
      #  #              type='application/json' 
      #  #              data-update-success='avg'
      #  #              data-frequency='10'></script>
      #  #
      #  periodically_call_remote(:url => { :action => 'get_averages' }, :update => 'avg')
      #
      #  # Call invoice every 10 seconds with the id of the customer
      #  # If it succeeds, update the invoice DIV; if it fails, update the error DIV
      #  # Generates:
      #  #      <script data-periodical='true' 
      #  #              data-url='/invoice/1' 
      #  #              type='application/json' 
      #  #              data-update-success='invoice' 
      #  #              data-update-failure='error'
      #  #              data-frequency='10'></script>"
      #  #
      #  periodically_call_remote(:url => { :action => 'invoice', :id => 1 },
      #     :update => { :success => "invoice", :failure => "error" }
      #
      #  # Call update every 20 seconds and update the new_block DIV
      #  # Generates:
      #  #      <script data-periodical='true' 
      #  #              data-url='update' 
      #  #              type='application/json' 
      #  #              data-update-success='news_block'
      #  #              data-frequency='20'></script>
      #  #
      #  periodically_call_remote(:url => 'update', :frequency => '20', :update => 'news_block')
      #
      def periodically_call_remote(options = {})
        attributes = extract_observer_attributes!(options)
        attributes["data-periodical"] = true 
        attributes["data-frequency"] ||= 10

        # periodically_call_remote does not need data-observe=true
        attributes.delete('data-observe')

        script_decorator(attributes).html_safe!
      end

      # Observes the field with the DOM ID specified by +field_id+ and calls a
      # callback when its contents have changed. The default callback is an
      # Ajax call. By default the value of the observed field is sent as a
      # parameter with the Ajax call.
      #
      # Example:
      #  # Generates: 
      #  #      "<script type='text/javascript' 
      #  #               data-observe='true' 
      #  #               data-observed='suggest' 
      #  #               data-frequency='0.25' 
      #  #               type='application/json' 
      #  #               data-url='/find_suggestion' 
      #  #               data-update-success='suggest' 
      #  #               data-with='q'></script>"
      #  # 
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
        html_options = options.delete(:callbacks)

        options[:observed] = name
        attributes = extract_observer_attributes!(options)
        attributes.merge!(html_options) if html_options

        script_decorator(attributes).html_safe!
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
        html_options = options.delete(:callbacks)

        options[:observed] = name
        attributes = extract_observer_attributes!(options)
        attributes.merge!(html_options) if html_options

        script_decorator(attributes).html_safe!
      end

      def script_decorator(options)
        attributes = %w(type="application/json")
        attributes += options.map{|k, v| k + '="' + v.to_s + '"'}
        "<script " + attributes.join(" ") + "></script>"
      end

      private

        def extract_remote_attributes!(options)
          attributes = options.delete(:html) || {}

          attributes.merge!(extract_update_attributes!(options))
          attributes.merge!(extract_request_attributes!(options))
          attributes["data-remote"] = true 

          if submit = options.delete(:submit)
            attributes["data-submit"] = submit
          end

          attributes
        end

        def extract_request_attributes!(options)
          attributes = {}
          if method  = options.delete(:method)
            attributes["data-method"] = method.to_s
          end
          
          if type = options.delete(:type)
            attributes["data-remote-type"] = type.to_s 
          end

          url_options = options.delete(:url)
          url_options = url_options.merge(:escape => false) if url_options.is_a?(Hash)
          attributes["data-url"] = escape_javascript(url_for(url_options))  if url_options

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

          if position = options.delete(:position)
            attributes["data-update-position"] = position.to_s 
          end

          purge_unused_attributes!(attributes)
        end

        def extract_observer_attributes!(options)
          callback = options.delete(:function)
          frequency = options.delete(:frequency) || 10


          attributes = extract_remote_attributes!(options)
          attributes["data-observe"] = true
          attributes["data-observed"] = options.delete(:observed)
          attributes["data-onobserve"] = callback if callback
          attributes["data-frequency"] = frequency if frequency && frequency.to_f != 0
          attributes.delete("data-remote")

          purge_unused_attributes!(attributes)
        end

        def purge_unused_attributes!(attributes)
          attributes.delete_if {|key, value| value.nil? }
          attributes
        end
    end

    # TODO: All evaled goes here per wycat
    module AjaxHelperCompat
      include AjaxHelper

      def link_to_remote(name, options, html_options = {})
        set_callbacks(options, html_options)
        set_with_and_condition_attributes(options, html_options)
        super
      end
      
      def button_to_remote(name, options = {}, html_options = {})
        set_callbacks(options, html_options)
        set_with_and_condition_attributes(options, html_options)
        super
      end

      def form_remote_tag(options, &block)
        html = {}
        set_callbacks(options, html)
        set_with_and_condition_attributes(options, html)
        options.merge!(:callbacks => html)
        super
      end

      def observe_field(name, options = {})
        html = {}
        set_with_and_condition_attributes(options, html)
        options.merge!(:callbacks => html)
        super
      end
      
      def observe_form(name, options = {})
        html = {}
        set_with_and_condition_attributes(options, html)
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

        def set_with_and_condition_attributes(options, html)
          if with = options.delete(:with)
            html["data-with"] = with
          end

          if condition = options.delete(:condition)
            html["data-condition"] = condition
          end
        end
    end
  end
end
