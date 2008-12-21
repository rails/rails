require 'set'
require 'active_support/json'

module ActionView
  module Helpers
    # Prototype[http://www.prototypejs.org/] is a JavaScript library that provides
    # DOM[http://en.wikipedia.org/wiki/Document_Object_Model] manipulation,
    # Ajax[http://www.adaptivepath.com/publications/essays/archives/000385.php]
    # functionality, and more traditional object-oriented facilities for JavaScript.
    # This module provides a set of helpers to make it more convenient to call
    # functions from Prototype using Rails, including functionality to call remote
    # Rails methods (that is, making a background request to a Rails action) using Ajax.
    # This means that you can call actions in your controllers without
    # reloading the page, but still update certain parts of it using
    # injections into the DOM. A common use case is having a form that adds
    # a new element to a list without reloading the page or updating a shopping
    # cart total when a new item is added.
    #
    # == Usage
    # To be able to use these helpers, you must first include the Prototype
    # JavaScript framework in your pages.
    #
    #  javascript_include_tag 'prototype'
    #
    # (See the documentation for
    # ActionView::Helpers::JavaScriptHelper for more information on including
    # this and other JavaScript files in your Rails templates.)
    #
    # Now you're ready to call a remote action either through a link...
    #
    #  link_to_remote "Add to cart",
    #    :url => { :action => "add", :id => product.id },
    #    :update => { :success => "cart", :failure => "error" }
    #
    # ...through a form...
    #
    #  <% form_remote_tag :url => '/shipping' do -%>
    #    <div><%= submit_tag 'Recalculate Shipping' %></div>
    #  <% end -%>
    #
    # ...periodically...
    #
    #  periodically_call_remote(:url => 'update', :frequency => '5', :update => 'ticker')
    #
    # ...or through an observer (i.e., a form or field that is observed and calls a remote
    # action when changed).
    #
    #  <%= observe_field(:searchbox,
    #       :url => { :action => :live_search }),
    #       :frequency => 0.5,
    #       :update => :hits,
    #       :with => 'query'
    #       %>
    #
    # As you can see, there are numerous ways to use Prototype's Ajax functions (and actually more than
    # are listed here); check out the documentation for each method to find out more about its usage and options.
    #
    # === Common Options
    # See link_to_remote for documentation of options common to all Ajax
    # helpers; any of the options specified by link_to_remote can be used
    # by the other helpers.
    #
    # == Designing your Rails actions for Ajax
    # When building your action handlers (that is, the Rails actions that receive your background requests), it's
    # important to remember a few things.  First, whatever your action would normally return to the browser, it will
    # return to the Ajax call.  As such, you typically don't want to render with a layout.  This call will cause
    # the layout to be transmitted back to your page, and, if you have a full HTML/CSS, will likely mess a lot of things up.
    # You can turn the layout off on particular actions by doing the following:
    #
    #  class SiteController < ActionController::Base
    #    layout "standard", :except => [:ajax_method, :more_ajax, :another_ajax]
    #  end
    #
    # Optionally, you could do this in the method you wish to lack a layout:
    #
    #  render :layout => false
    #
    # You can tell the type of request from within your action using the <tt>request.xhr?</tt> (XmlHttpRequest, the
    # method that Ajax uses to make background requests) method.
    #  def name
    #    # Is this an XmlHttpRequest request?
    #    if (request.xhr?)
    #      render :text => @name.to_s
    #    else
    #      # No?  Then render an action.
    #      render :action => 'view_attribute', :attr => @name
    #    end
    #  end
    #
    # The else clause can be left off and the current action will render with full layout and template. An extension
    # to this solution was posted to Ryan Heneise's blog at ArtOfMission["http://www.artofmission.com/"].
    #
    #  layout proc{ |c| c.request.xhr? ? false : "application" }
    #
    # Dropping this in your ApplicationController turns the layout off for every request that is an "xhr" request.
    #
    # If you are just returning a little data or don't want to build a template for your output, you may opt to simply
    # render text output, like this:
    #
    #  render :text => 'Return this from my method!'
    #
    # Since whatever the method returns is injected into the DOM, this will simply inject some text (or HTML, if you
    # tell it to).  This is usually how small updates, such updating a cart total or a file count, are handled.
    #
    # == Updating multiple elements
    # See JavaScriptGenerator for information on updating multiple elements
    # on the page in an Ajax response.
    module PrototypeHelper
      unless const_defined? :CALLBACKS
        CALLBACKS    = Set.new([ :uninitialized, :loading, :loaded,
                         :interactive, :complete, :failure, :success ] +
                         (100..599).to_a)
        AJAX_OPTIONS = Set.new([ :before, :after, :condition, :url,
                         :asynchronous, :method, :insertion, :position,
                         :form, :with, :update, :script, :type ]).merge(CALLBACKS)
      end

      # Returns a link to a remote action defined by <tt>options[:url]</tt>
      # (using the url_for format) that's called in the background using
      # XMLHttpRequest. The result of that request can then be inserted into a
      # DOM object whose id can be specified with <tt>options[:update]</tt>.
      # Usually, the result would be a partial prepared by the controller with
      # render :partial.
      #
      # Examples:
      #   # Generates: <a href="#" onclick="new Ajax.Updater('posts', '/blog/destroy/3', {asynchronous:true, evalScripts:true});
      #   #            return false;">Delete this post</a>
      #   link_to_remote "Delete this post", :update => "posts",
      #     :url => { :action => "destroy", :id => post.id }
      #
      #   # Generates: <a href="#" onclick="new Ajax.Updater('emails', '/mail/list_emails', {asynchronous:true, evalScripts:true});
      #   #            return false;"><img alt="Refresh" src="/images/refresh.png?" /></a>
      #   link_to_remote(image_tag("refresh"), :update => "emails",
      #     :url => { :action => "list_emails" })
      #
      # You can override the generated HTML options by specifying a hash in
      # <tt>options[:html]</tt>.
      #
      #   link_to_remote "Delete this post", :update => "posts",
      #     :url  => post_url(@post), :method => :delete,
      #     :html => { :class  => "destructive" }
      #
      # You can also specify a hash for <tt>options[:update]</tt> to allow for
      # easy redirection of output to an other DOM element if a server-side
      # error occurs:
      #
      # Example:
      #   # Generates: <a href="#" onclick="new Ajax.Updater({success:'posts',failure:'error'}, '/blog/destroy/5',
      #   #            {asynchronous:true, evalScripts:true}); return false;">Delete this post</a>
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
      #   # Generates: <a href="#" onclick="new Ajax.Request('/person/4', {asynchronous:true, evalScripts:true, method:'delete'});
      #   #            return false;">Destroy</a>
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
      #   # Generates: <a href="#" onclick="new Ajax.Request('/words/undo?n=33', {asynchronous:true, evalScripts:true,
      #   #            onComplete:function(request){undoRequestCompleted(request)}}); return false;">hello</a>
      #   word = 'hello'
      #   link_to_remote word,
      #     :url => { :action => "undo", :n => word_counter },
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
      #   # Generates: <a href="#" onclick="new Ajax.Request('/testing/action', {asynchronous:true, evalScripts:true,
      #   #            on404:function(request){alert('Not found...? Wrong URL...?')},
      #   #            onFailure:function(request){alert('HTTP Error ' + request.status + '!')}}); return false;">hello</a>
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
      #   link_to_remote "Delete this post",
      #     { :update => "posts", :url => { :action => "destroy", :id => post.id } },
      #     :href => url_for(:action => "destroy", :id => post.id)
      def link_to_remote(name, options = {}, html_options = nil)
        link_to_function(name, remote_function(options), html_options || options.delete(:html))
      end

      # Creates a button with an onclick event which calls a remote action
      # via XMLHttpRequest
      # The options for specifying the target with :url
      # and defining callbacks is the same as link_to_remote.
      def button_to_remote(name, options = {}, html_options = {})
        button_to_function(name, remote_function(options), html_options)
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
         frequency = options[:frequency] || 10 # every ten seconds by default
         code = "new PeriodicalExecuter(function() {#{remote_function(options)}}, #{frequency})"
         javascript_tag(code)
      end

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
      #   # Generates:
      #   #      <form action="/some/place" method="post" onsubmit="new Ajax.Request('',
      #   #      {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;">
      #   form_remote_tag :html => { :action =>
      #     url_for(:controller => "some", :action => "place") }
      #
      # The Hash passed to the <tt>:html</tt> key is equivalent to the options (2nd)
      # argument in the FormTagHelper.form_tag method.
      #
      # By default the fall-through action is the same as the one specified in
      # the <tt>:url</tt> (and the default method is <tt>:post</tt>).
      #
      # form_remote_tag also takes a block, like form_tag:
      #   # Generates:
      #   #     <form action="/" method="post" onsubmit="new Ajax.Request('/',
      #   #     {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)});
      #   #     return false;"> <div><input name="commit" type="submit" value="Save" /></div>
      #   #     </form>
      #   <% form_remote_tag :url => '/posts' do -%>
      #     <div><%= submit_tag 'Save' %></div>
      #   <% end -%>
      def form_remote_tag(options = {}, &block)
        options[:form] = true

        options[:html] ||= {}
        options[:html][:onsubmit] =
          (options[:html][:onsubmit] ? options[:html][:onsubmit] + "; " : "") +
          "#{remote_function(options)}; return false;"

        form_tag(options[:html].delete(:action) || url_for(options[:url]), options[:html], &block)
      end

      # Creates a form that will submit using XMLHttpRequest in the background
      # instead of the regular reloading POST arrangement and a scope around a
      # specific resource that is used as a base for questioning about
      # values for the fields.
      #
      # === Resource
      #
      # Example:
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

        case record_or_name_or_array
        when String, Symbol
          object_name = record_or_name_or_array
        when Array
          object = record_or_name_or_array.last
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!(record_or_name_or_array, options)
          args.unshift object
        else
          object      = record_or_name_or_array
          object_name = ActionController::RecordIdentifier.singular_class_name(record_or_name_or_array)
          apply_form_for_options!(object, options)
          args.unshift object
        end

        concat(form_remote_tag(options))
        fields_for(object_name, *(args << options), &proc)
        concat('</form>')
      end
      alias_method :form_remote_for, :remote_form_for

      # Returns a button input tag with the element name of +name+ and a value (i.e., display text) of +value+
      # that will submit form using XMLHttpRequest in the background instead of a regular POST request that
      # reloads the page.
      #
      #  # Create a button that submits to the create action
      #  #
      #  # Generates: <input name="create_btn" onclick="new Ajax.Request('/testing/create',
      #  #     {asynchronous:true, evalScripts:true, parameters:Form.serialize(this.form)});
      #  #     return false;" type="button" value="Create" />
      #  <%= submit_to_remote 'create_btn', 'Create', :url => { :action => 'create' } %>
      #
      #  # Submit to the remote action update and update the DIV succeed or fail based
      #  # on the success or failure of the request
      #  #
      #  # Generates: <input name="update_btn" onclick="new Ajax.Updater({success:'succeed',failure:'fail'},
      #  #      '/testing/update', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this.form)});
      #  #      return false;" type="button" value="Update" />
      #  <%= submit_to_remote 'update_btn', 'Update', :url => { :action => 'update' },
      #     :update => { :success => "succeed", :failure => "fail" }
      #
      # <tt>options</tt> argument is the same as in form_remote_tag.
      def submit_to_remote(name, value, options = {})
        options[:with] ||= 'Form.serialize(this.form)'

        html_options = options.delete(:html) || {}
        html_options[:name] = name

        button_to_remote(value, options, html_options)
      end

      # Returns '<tt>eval(request.responseText)</tt>' which is the JavaScript function
      # that +form_remote_tag+ can call in <tt>:complete</tt> to evaluate a multiple
      # update return document using +update_element_function+ calls.
      def evaluate_remote_response
        "eval(request.responseText)"
      end

      # Returns the JavaScript needed for a remote function.
      # Takes the same arguments as link_to_remote.
      #
      # Example:
      #   # Generates: <select id="options" onchange="new Ajax.Updater('options',
      #   # '/testing/update_options', {asynchronous:true, evalScripts:true})">
      #   <select id="options" onchange="<%= remote_function(:update => "options",
      #       :url => { :action => :update_options }) %>">
      #     <option value="0">Hello</option>
      #     <option value="1">World</option>
      #   </select>
      def remote_function(options)
        javascript_options = options_for_ajax(options)

        update = ''
        if options[:update] && options[:update].is_a?(Hash)
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

        url_options = options[:url]
        url_options = url_options.merge(:escape => false) if url_options.is_a?(Hash)
        function << "'#{escape_javascript(url_for(url_options))}'"
        function << ", #{javascript_options})"

        function = "#{options[:before]}; #{function}" if options[:before]
        function = "#{function}; #{options[:after]}"  if options[:after]
        function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
        function = "if (confirm('#{escape_javascript(options[:confirm])}')) { #{function}; }" if options[:confirm]

        return function
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
      def observe_field(field_id, options = {})
        if options[:frequency] && options[:frequency] > 0
          build_observer('Form.Element.Observer', field_id, options)
        else
          build_observer('Form.Element.EventObserver', field_id, options)
        end
      end

      # Observes the form with the DOM ID specified by +form_id+ and calls a
      # callback when its contents have changed. The default callback is an
      # Ajax call. By default all fields of the observed field are sent as
      # parameters with the Ajax call.
      #
      # The +options+ for +observe_form+ are the same as the options for
      # +observe_field+. The JavaScript variable +value+ available to the
      # <tt>:with</tt> option is set to the serialized form by default.
      def observe_form(form_id, options = {})
        if options[:frequency]
          build_observer('Form.Observer', form_id, options)
        else
          build_observer('Form.EventObserver', form_id, options)
        end
      end

      # All the methods were moved to GeneratorMethods so that
      # #include_helpers_from_context has nothing to overwrite.
      class JavaScriptGenerator #:nodoc:
        def initialize(context, &block) #:nodoc:
          @context, @lines = context, []
          include_helpers_from_context
          @context.with_output_buffer(@lines) do
            @context.instance_exec(self, &block)
          end
        end

        private
          def include_helpers_from_context
            extend @context.helpers if @context.respond_to?(:helpers)
            extend GeneratorMethods
          end

        # JavaScriptGenerator generates blocks of JavaScript code that allow you
        # to change the content and presentation of multiple DOM elements.  Use
        # this in your Ajax response bodies, either in a <script> tag or as plain
        # JavaScript sent with a Content-type of "text/javascript".
        #
        # Create new instances with PrototypeHelper#update_page or with
        # ActionController::Base#render, then call +insert_html+, +replace_html+,
        # +remove+, +show+, +hide+, +visual_effect+, or any other of the built-in
        # methods on the yielded generator in any order you like to modify the
        # content and appearance of the current page.
        #
        # Example:
        #
        #   # Generates:
        #   #     new Element.insert("list", { bottom: "<li>Some item</li>" });
        #   #     new Effect.Highlight("list");
        #   #     ["status-indicator", "cancel-link"].each(Element.hide);
        #   update_page do |page|
        #     page.insert_html :bottom, 'list', "<li>#{@item.name}</li>"
        #     page.visual_effect :highlight, 'list'
        #     page.hide 'status-indicator', 'cancel-link'
        #   end
        #
        #
        # Helper methods can be used in conjunction with JavaScriptGenerator.
        # When a helper method is called inside an update block on the +page+
        # object, that method will also have access to a +page+ object.
        #
        # Example:
        #
        #   module ApplicationHelper
        #     def update_time
        #       page.replace_html 'time', Time.now.to_s(:db)
        #       page.visual_effect :highlight, 'time'
        #     end
        #   end
        #
        #   # Controller action
        #   def poll
        #     render(:update) { |page| page.update_time }
        #   end
        #
        # Calls to JavaScriptGenerator not matching a helper method below
        # generate a proxy to the JavaScript Class named by the method called.
        #
        # Examples:
        #
        #   # Generates:
        #   #     Foo.init();
        #   update_page do |page|
        #     page.foo.init
        #   end
        #
        #   # Generates:
        #   #     Event.observe('one', 'click', function () {
        #   #       $('two').show();
        #   #     });
        #   update_page do |page|
        #     page.event.observe('one', 'click') do |p|
        #      p[:two].show
        #     end
        #   end
        #
        # You can also use PrototypeHelper#update_page_tag instead of
        # PrototypeHelper#update_page to wrap the generated JavaScript in a
        # <script> tag.
        module GeneratorMethods
          def to_s #:nodoc:
            returning javascript = @lines * $/ do
              if ActionView::Base.debug_rjs
                source = javascript.dup
                javascript.replace "try {\n#{source}\n} catch (e) "
                javascript << "{ alert('RJS error:\\n\\n' + e.toString()); alert('#{source.gsub('\\','\0\0').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }}'); throw e }"
              end
            end
          end

          # Returns a element reference by finding it through +id+ in the DOM. This element can then be
          # used for further method calls. Examples:
          #
          #   page['blank_slate']                  # => $('blank_slate');
          #   page['blank_slate'].show             # => $('blank_slate').show();
          #   page['blank_slate'].show('first').up # => $('blank_slate').show('first').up();
          #
          # You can also pass in a record, which will use ActionController::RecordIdentifier.dom_id to lookup
          # the correct id:
          #
          #   page[@post]     # => $('post_45')
          #   page[Post.new]  # => $('new_post')
          def [](id)
            case id
              when String, Symbol, NilClass
                JavaScriptElementProxy.new(self, id)
              else
                JavaScriptElementProxy.new(self, ActionController::RecordIdentifier.dom_id(id))
            end
          end

          # Returns an object whose <tt>to_json</tt> evaluates to +code+. Use this to pass a literal JavaScript
          # expression as an argument to another JavaScriptGenerator method.
          def literal(code)
            ActiveSupport::JSON::Variable.new(code.to_s)
          end

          # Returns a collection reference by finding it through a CSS +pattern+ in the DOM. This collection can then be
          # used for further method calls. Examples:
          #
          #   page.select('p')                      # => $$('p');
          #   page.select('p.welcome b').first      # => $$('p.welcome b').first();
          #   page.select('p.welcome b').first.hide # => $$('p.welcome b').first().hide();
          #
          # You can also use prototype enumerations with the collection.  Observe:
          #
          #   # Generates: $$('#items li').each(function(value) { value.hide(); });
          #   page.select('#items li').each do |value|
          #     value.hide
          #   end
          #
          # Though you can call the block param anything you want, they are always rendered in the
          # javascript as 'value, index.'  Other enumerations, like collect() return the last statement:
          #
          #   # Generates: var hidden = $$('#items li').collect(function(value, index) { return value.hide(); });
          #   page.select('#items li').collect('hidden') do |item|
          #     item.hide
          #   end
          #
          def select(pattern)
            JavaScriptElementCollectionProxy.new(self, pattern)
          end

          # Inserts HTML at the specified +position+ relative to the DOM element
          # identified by the given +id+.
          #
          # +position+ may be one of:
          #
          # <tt>:top</tt>::    HTML is inserted inside the element, before the
          #                    element's existing content.
          # <tt>:bottom</tt>:: HTML is inserted inside the element, after the
          #                    element's existing content.
          # <tt>:before</tt>:: HTML is inserted immediately preceding the element.
          # <tt>:after</tt>::  HTML is inserted immediately following the element.
          #
          # +options_for_render+ may be either a string of HTML to insert, or a hash
          # of options to be passed to ActionView::Base#render.  For example:
          #
          #   # Insert the rendered 'navigation' partial just before the DOM
          #   # element with ID 'content'.
          #   # Generates: Element.insert("content", { before: "-- Contents of 'navigation' partial --" });
          #   page.insert_html :before, 'content', :partial => 'navigation'
          #
          #   # Add a list item to the bottom of the <ul> with ID 'list'.
          #   # Generates: Element.insert("list", { bottom: "<li>Last item</li>" });
          #   page.insert_html :bottom, 'list', '<li>Last item</li>'
          #
          def insert_html(position, id, *options_for_render)
            content = javascript_object_for(render(*options_for_render))
            record "Element.insert(\"#{id}\", { #{position.to_s.downcase}: #{content} });"
          end

          # Replaces the inner HTML of the DOM element with the given +id+.
          #
          # +options_for_render+ may be either a string of HTML to insert, or a hash
          # of options to be passed to ActionView::Base#render.  For example:
          #
          #   # Replace the HTML of the DOM element having ID 'person-45' with the
          #   # 'person' partial for the appropriate object.
          #   # Generates:  Element.update("person-45", "-- Contents of 'person' partial --");
          #   page.replace_html 'person-45', :partial => 'person', :object => @person
          #
          def replace_html(id, *options_for_render)
            call 'Element.update', id, render(*options_for_render)
          end

          # Replaces the "outer HTML" (i.e., the entire element, not just its
          # contents) of the DOM element with the given +id+.
          #
          # +options_for_render+ may be either a string of HTML to insert, or a hash
          # of options to be passed to ActionView::Base#render.  For example:
          #
          #   # Replace the DOM element having ID 'person-45' with the
          #   # 'person' partial for the appropriate object.
          #   page.replace 'person-45', :partial => 'person', :object => @person
          #
          # This allows the same partial that is used for the +insert_html+ to
          # be also used for the input to +replace+ without resorting to
          # the use of wrapper elements.
          #
          # Examples:
          #
          #   <div id="people">
          #     <%= render :partial => 'person', :collection => @people %>
          #   </div>
          #
          #   # Insert a new person
          #   #
          #   # Generates: new Insertion.Bottom({object: "Matz", partial: "person"}, "");
          #   page.insert_html :bottom, :partial => 'person', :object => @person
          #
          #   # Replace an existing person
          #
          #   # Generates: Element.replace("person_45", "-- Contents of partial --");
          #   page.replace 'person_45', :partial => 'person', :object => @person
          #
          def replace(id, *options_for_render)
            call 'Element.replace', id, render(*options_for_render)
          end

          # Removes the DOM elements with the given +ids+ from the page.
          #
          # Example:
          #
          #  # Remove a few people
          #  # Generates: ["person_23", "person_9", "person_2"].each(Element.remove);
          #  page.remove 'person_23', 'person_9', 'person_2'
          #
          def remove(*ids)
            loop_on_multiple_args 'Element.remove', ids
          end

          # Shows hidden DOM elements with the given +ids+.
          #
          # Example:
          #
          #  # Show a few people
          #  # Generates: ["person_6", "person_13", "person_223"].each(Element.show);
          #  page.show 'person_6', 'person_13', 'person_223'
          #
          def show(*ids)
            loop_on_multiple_args 'Element.show', ids
          end

          # Hides the visible DOM elements with the given +ids+.
          #
          # Example:
          #
          #  # Hide a few people
          #  # Generates: ["person_29", "person_9", "person_0"].each(Element.hide);
          #  page.hide 'person_29', 'person_9', 'person_0'
          #
          def hide(*ids)
            loop_on_multiple_args 'Element.hide', ids
          end

          # Toggles the visibility of the DOM elements with the given +ids+.
          # Example:
          #
          #  # Show a few people
          #  # Generates: ["person_14", "person_12", "person_23"].each(Element.toggle);
          #  page.toggle 'person_14', 'person_12', 'person_23'      # Hides the elements
          #  page.toggle 'person_14', 'person_12', 'person_23'      # Shows the previously hidden elements
          #
          def toggle(*ids)
            loop_on_multiple_args 'Element.toggle', ids
          end

          # Displays an alert dialog with the given +message+.
          #
          # Example:
          #
          #   # Generates: alert('This message is from Rails!')
          #   page.alert('This message is from Rails!')
          def alert(message)
            call 'alert', message
          end

          # Redirects the browser to the given +location+ using JavaScript, in the same form as +url_for+.
          #
          # Examples:
          #
          #  # Generates: window.location.href = "/mycontroller";
          #  page.redirect_to(:action => 'index')
          #
          #  # Generates: window.location.href = "/account/signup";
          #  page.redirect_to(:controller => 'account', :action => 'signup')
          def redirect_to(location)
            url = location.is_a?(String) ? location : @context.url_for(location)
            record "window.location.href = #{url.inspect}"
          end

          # Reloads the browser's current +location+ using JavaScript
          #
          # Examples:
          #
          #  # Generates: window.location.reload();
          #  page.reload
          def reload
            record 'window.location.reload()'
          end

          # Calls the JavaScript +function+, optionally with the given +arguments+.
          #
          # If a block is given, the block will be passed to a new JavaScriptGenerator;
          # the resulting JavaScript code will then be wrapped inside <tt>function() { ... }</tt>
          # and passed as the called function's final argument.
          #
          # Examples:
          #
          #   # Generates: Element.replace(my_element, "My content to replace with.")
          #   page.call 'Element.replace', 'my_element', "My content to replace with."
          #
          #   # Generates: alert('My message!')
          #   page.call 'alert', 'My message!'
          #
          #   # Generates:
          #   #     my_method(function() {
          #   #       $("one").show();
          #   #       $("two").hide();
          #   #    });
          #   page.call(:my_method) do |p|
          #      p[:one].show
          #      p[:two].hide
          #   end
          def call(function, *arguments, &block)
            record "#{function}(#{arguments_for_call(arguments, block)})"
          end

          # Assigns the JavaScript +variable+ the given +value+.
          #
          # Examples:
          #
          #  # Generates: my_string = "This is mine!";
          #  page.assign 'my_string', 'This is mine!'
          #
          #  # Generates: record_count = 33;
          #  page.assign 'record_count', 33
          #
          #  # Generates: tabulated_total = 47
          #  page.assign 'tabulated_total', @total_from_cart
          #
          def assign(variable, value)
            record "#{variable} = #{javascript_object_for(value)}"
          end

          # Writes raw JavaScript to the page.
          #
          # Example:
          #
          #  page << "alert('JavaScript with Prototype.');"
          def <<(javascript)
            @lines << javascript
          end

          # Executes the content of the block after a delay of +seconds+. Example:
          #
          #   # Generates:
          #   #     setTimeout(function() {
          #   #     ;
          #   #     new Effect.Fade("notice",{});
          #   #     }, 20000);
          #   page.delay(20) do
          #     page.visual_effect :fade, 'notice'
          #   end
          def delay(seconds = 1)
            record "setTimeout(function() {\n\n"
            yield
            record "}, #{(seconds * 1000).to_i})"
          end

          # Starts a script.aculo.us visual effect. See
          # ActionView::Helpers::ScriptaculousHelper for more information.
          def visual_effect(name, id = nil, options = {})
            record @context.send(:visual_effect, name, id, options)
          end

          # Creates a script.aculo.us sortable element. Useful
          # to recreate sortable elements after items get added
          # or deleted.
          # See ActionView::Helpers::ScriptaculousHelper for more information.
          def sortable(id, options = {})
            record @context.send(:sortable_element_js, id, options)
          end

          # Creates a script.aculo.us draggable element.
          # See ActionView::Helpers::ScriptaculousHelper for more information.
          def draggable(id, options = {})
            record @context.send(:draggable_element_js, id, options)
          end

          # Creates a script.aculo.us drop receiving element.
          # See ActionView::Helpers::ScriptaculousHelper for more information.
          def drop_receiving(id, options = {})
            record @context.send(:drop_receiving_element_js, id, options)
          end

          private
            def loop_on_multiple_args(method, ids)
              record(ids.size>1 ?
                "#{javascript_object_for(ids)}.each(#{method})" :
                "#{method}(#{ids.first.to_json})")
            end

            def page
              self
            end

            def record(line)
              returning line = "#{line.to_s.chomp.gsub(/\;\z/, '')};" do
                self << line
              end
            end

            def render(*options_for_render)
              old_format = @context && @context.template_format
              @context.template_format = :html if @context
              Hash === options_for_render.first ?
                @context.render(*options_for_render) :
                  options_for_render.first.to_s
            ensure
              @context.template_format = old_format if @context
            end

            def javascript_object_for(object)
              object.respond_to?(:to_json) ? object.to_json : object.inspect
            end

            def arguments_for_call(arguments, block = nil)
              arguments << block_to_function(block) if block
              arguments.map { |argument| javascript_object_for(argument) }.join ', '
            end

            def block_to_function(block)
              generator = self.class.new(@context, &block)
              literal("function() { #{generator.to_s} }")
            end

            def method_missing(method, *arguments)
              JavaScriptProxy.new(self, method.to_s.camelize)
            end
        end
      end

      # Yields a JavaScriptGenerator and returns the generated JavaScript code.
      # Use this to update multiple elements on a page in an Ajax response.
      # See JavaScriptGenerator for more information.
      #
      # Example:
      #
      #   update_page do |page|
      #     page.hide 'spinner'
      #   end
      def update_page(&block)
        JavaScriptGenerator.new(@template, &block).to_s
      end

      # Works like update_page but wraps the generated JavaScript in a <script>
      # tag. Use this to include generated JavaScript in an ERb template.
      # See JavaScriptGenerator for more information.
      #
      # +html_options+ may be a hash of <script> attributes to be passed
      # to ActionView::Helpers::JavaScriptHelper#javascript_tag.
      def update_page_tag(html_options = {}, &block)
        javascript_tag update_page(&block), html_options
      end

    protected
      def options_for_ajax(options)
        js_options = build_callbacks(options)

        js_options['asynchronous'] = options[:type] != :synchronous
        js_options['method']       = method_option_to_s(options[:method]) if options[:method]
        js_options['insertion']    = "'#{options[:position].to_s.downcase}'" if options[:position]
        js_options['evalScripts']  = options[:script].nil? || options[:script]

        if options[:form]
          js_options['parameters'] = 'Form.serialize(this)'
        elsif options[:submit]
          js_options['parameters'] = "Form.serialize('#{options[:submit]}')"
        elsif options[:with]
          js_options['parameters'] = options[:with]
        end

        if protect_against_forgery? && !options[:form]
          if js_options['parameters']
            js_options['parameters'] << " + '&"
          else
            js_options['parameters'] = "'"
          end
          js_options['parameters'] << "#{request_forgery_protection_token}=' + encodeURIComponent('#{escape_javascript form_authenticity_token}')"
        end

        options_for_javascript(js_options)
      end

      def method_option_to_s(method)
        (method.is_a?(String) and !method.index("'").nil?) ? method : "'#{method}'"
      end

      def build_observer(klass, name, options = {})
        if options[:with] && (options[:with] !~ /[\{=(.]/)
          options[:with] = "'#{options[:with]}=' + encodeURIComponent(value)"
        else
          options[:with] ||= 'value' unless options[:function]
        end

        callback = options[:function] || remote_function(options)
        javascript  = "new #{klass}('#{name}', "
        javascript << "#{options[:frequency]}, " if options[:frequency]
        javascript << "function(element, value) {"
        javascript << "#{callback}}"
        javascript << ")"
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

    # Converts chained method calls on DOM proxy elements into JavaScript chains
    class JavaScriptProxy < ActiveSupport::BasicObject #:nodoc:

      def initialize(generator, root = nil)
        @generator = generator
        @generator << root if root
      end

      private
        def method_missing(method, *arguments, &block)
          if method.to_s =~ /(.*)=$/
            assign($1, arguments.first)
          else
            call("#{method.to_s.camelize(:lower)}", *arguments, &block)
          end
        end

        def call(function, *arguments, &block)
          append_to_function_chain!("#{function}(#{@generator.send(:arguments_for_call, arguments, block)})")
          self
        end

        def assign(variable, value)
          append_to_function_chain!("#{variable} = #{@generator.send(:javascript_object_for, value)}")
        end

        def function_chain
          @function_chain ||= @generator.instance_variable_get(:@lines)
        end

        def append_to_function_chain!(call)
          function_chain[-1].chomp!(';')
          function_chain[-1] += ".#{call};"
        end
    end

    class JavaScriptElementProxy < JavaScriptProxy #:nodoc:
      def initialize(generator, id)
        @id = id
        super(generator, "$(#{id.to_json})")
      end

      # Allows access of element attributes through +attribute+. Examples:
      #
      #   page['foo']['style']                  # => $('foo').style;
      #   page['foo']['style']['color']         # => $('blank_slate').style.color;
      #   page['foo']['style']['color'] = 'red' # => $('blank_slate').style.color = 'red';
      #   page['foo']['style'].color = 'red'    # => $('blank_slate').style.color = 'red';
      def [](attribute)
        append_to_function_chain!(attribute)
        self
      end

      def []=(variable, value)
        assign(variable, value)
      end

      def replace_html(*options_for_render)
        call 'update', @generator.send(:render, *options_for_render)
      end

      def replace(*options_for_render)
        call 'replace', @generator.send(:render, *options_for_render)
      end

      def reload(options_for_replace = {})
        replace(options_for_replace.merge({ :partial => @id.to_s }))
      end

    end

    class JavaScriptVariableProxy < JavaScriptProxy #:nodoc:
      def initialize(generator, variable)
        @variable = variable
        @empty    = true # only record lines if we have to.  gets rid of unnecessary linebreaks
        super(generator)
      end

      # The JSON Encoder calls this to check for the +to_json+ method
      # Since it's a blank slate object, I suppose it responds to anything.
      def respond_to?(method)
        true
      end

      def to_json(options = nil)
        @variable
      end

      private
        def append_to_function_chain!(call)
          @generator << @variable if @empty
          @empty = false
          super
        end
    end

    class JavaScriptCollectionProxy < JavaScriptProxy #:nodoc:
      ENUMERABLE_METHODS_WITH_RETURN = [:all, :any, :collect, :map, :detect, :find, :find_all, :select, :max, :min, :partition, :reject, :sort_by, :in_groups_of, :each_slice] unless defined? ENUMERABLE_METHODS_WITH_RETURN
      ENUMERABLE_METHODS = ENUMERABLE_METHODS_WITH_RETURN + [:each] unless defined? ENUMERABLE_METHODS
      attr_reader :generator
      delegate :arguments_for_call, :to => :generator

      def initialize(generator, pattern)
        super(generator, @pattern = pattern)
      end

      def each_slice(variable, number, &block)
        if block
          enumerate :eachSlice, :variable => variable, :method_args => [number], :yield_args => %w(value index), :return => true, &block
        else
          add_variable_assignment!(variable)
          append_enumerable_function!("eachSlice(#{number.to_json});")
        end
      end

      def grep(variable, pattern, &block)
        enumerate :grep, :variable => variable, :return => true, :method_args => [pattern], :yield_args => %w(value index), &block
      end

      def in_groups_of(variable, number, fill_with = nil)
        arguments = [number]
        arguments << fill_with unless fill_with.nil?
        add_variable_assignment!(variable)
        append_enumerable_function!("inGroupsOf(#{arguments_for_call arguments});")
      end

      def inject(variable, memo, &block)
        enumerate :inject, :variable => variable, :method_args => [memo], :yield_args => %w(memo value index), :return => true, &block
      end

      def pluck(variable, property)
        add_variable_assignment!(variable)
        append_enumerable_function!("pluck(#{property.to_json});")
      end

      def zip(variable, *arguments, &block)
        add_variable_assignment!(variable)
        append_enumerable_function!("zip(#{arguments_for_call arguments}")
        if block
          function_chain[-1] += ", function(array) {"
          yield ::ActiveSupport::JSON::Variable.new('array')
          add_return_statement!
          @generator << '});'
        else
          function_chain[-1] += ');'
        end
      end

      private
        def method_missing(method, *arguments, &block)
          if ENUMERABLE_METHODS.include?(method)
            returnable = ENUMERABLE_METHODS_WITH_RETURN.include?(method)
            variable   = arguments.first if returnable
            enumerate(method, {:variable => (arguments.first if returnable), :return => returnable, :yield_args => %w(value index)}, &block)
          else
            super
          end
        end

        # Options
        #   * variable - name of the variable to set the result of the enumeration to
        #   * method_args - array of the javascript enumeration method args that occur before the function
        #   * yield_args - array of the javascript yield args
        #   * return - true if the enumeration should return the last statement
        def enumerate(enumerable, options = {}, &block)
          options[:method_args] ||= []
          options[:yield_args]  ||= []
          yield_args  = options[:yield_args] * ', '
          method_args = arguments_for_call options[:method_args] # foo, bar, function
          method_args << ', ' unless method_args.blank?
          add_variable_assignment!(options[:variable]) if options[:variable]
          append_enumerable_function!("#{enumerable.to_s.camelize(:lower)}(#{method_args}function(#{yield_args}) {")
          # only yield as many params as were passed in the block
          yield(*options[:yield_args].collect { |p| JavaScriptVariableProxy.new(@generator, p) }[0..block.arity-1])
          add_return_statement! if options[:return]
          @generator << '});'
        end

        def add_variable_assignment!(variable)
          function_chain.push("var #{variable} = #{function_chain.pop}")
        end

        def add_return_statement!
          unless function_chain.last =~ /return/
            function_chain.push("return #{function_chain.pop.chomp(';')};")
          end
        end

        def append_enumerable_function!(call)
          function_chain[-1].chomp!(';')
          function_chain[-1] += ".#{call}"
        end
    end

    class JavaScriptElementCollectionProxy < JavaScriptCollectionProxy #:nodoc:\
      def initialize(generator, pattern)
        super(generator, "$$(#{pattern.to_json})")
      end
    end
  end
end

require 'action_view/helpers/javascript_helper'
