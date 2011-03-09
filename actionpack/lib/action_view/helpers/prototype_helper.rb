require 'set'
require 'active_support/json'
require 'active_support/core_ext/object/blank'

module ActionView
  # = Action View Prototype Helpers
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
    #  <%= form_remote_tag :url => '/shipping' do -%>
    #    <div><%= submit_tag 'Recalculate Shipping' %></div>
    #  <% end -%>
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
      CALLBACKS    = Set.new([ :create, :uninitialized, :loading, :loaded,
                       :interactive, :complete, :failure, :success ] +
                       (100..599).to_a)
      AJAX_OPTIONS = Set.new([ :before, :after, :condition, :url,
                       :asynchronous, :method, :insertion, :position,
                       :form, :with, :update, :script, :type ]).merge(CALLBACKS)

      # Returns the JavaScript needed for a remote function.
      # See the link_to_remote documentation at http://github.com/rails/prototype_legacy_helper as it takes the same arguments.
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
        function << "'#{html_escape(escape_javascript(url_for(url_options)))}'"
        function << ", #{javascript_options})"

        function = "#{options[:before]}; #{function}" if options[:before]
        function = "#{function}; #{options[:after]}"  if options[:after]
        function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
        function = "if (confirm('#{escape_javascript(options[:confirm])}')) { #{function}; }" if options[:confirm]

        return function.html_safe
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
        # this in your Ajax response bodies, either in a <tt>\<script></tt> tag or as plain
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
        # <tt>\<script></tt> tag.
        module GeneratorMethods
          def to_s #:nodoc:
            (@lines * $/).tap do |javascript|
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
            ::ActiveSupport::JSON::Variable.new(code.to_s)
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

          private
            def loop_on_multiple_args(method, ids)
              record(ids.size>1 ?
                "#{javascript_object_for(ids)}.each(#{method})" :
                "#{method}(#{javascript_object_for(ids.first)})")
            end

            def page
              self
            end

            def record(line)
              line = "#{line.to_s.chomp.gsub(/\;\z/, '')};"
              self << line
              line
            end

            def render(*options)
              with_formats(:html) do
                case option = options.first
                when Hash
                  @context.render(*options)
                else
                  option.to_s
                end
              end
            end

            def with_formats(*args)
              @context ? @context.update_details(:formats => args) { yield } : yield
            end

            def javascript_object_for(object)
              ::ActiveSupport::JSON.encode(object)
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
        JavaScriptGenerator.new(view_context, &block).to_s.html_safe
      end

      # Works like update_page but wraps the generated JavaScript in a <tt>\<script></tt>
      # tag. Use this to include generated JavaScript in an ERb template.
      # See JavaScriptGenerator for more information.
      #
      # +html_options+ may be a hash of <tt>\<script></tt> attributes to be passed
      # to ActionView::Helpers::JavaScriptHelper#javascript_tag.
      def update_page_tag(html_options = {}, &block)
        javascript_tag update_page(&block), html_options
      end

      protected
        def options_for_javascript(options)
          if options.empty?
            '{}'
          else
            "{#{options.keys.map { |k| "#{k}:#{options[k]}" }.sort.join(', ')}}"
          end
        end

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

      def is_a?(klass)
        klass == JavaScriptProxy
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
        super(generator, "$(#{::ActiveSupport::JSON.encode(id)})")
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
        @variable = ::ActiveSupport::JSON::Variable.new(variable)
        @empty    = true # only record lines if we have to.  gets rid of unnecessary linebreaks
        super(generator)
      end

      # The JSON Encoder calls this to check for the +to_json+ method
      # Since it's a blank slate object, I suppose it responds to anything.
      def respond_to?(*)
        true
      end

      def as_json(options = nil)
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
          append_enumerable_function!("eachSlice(#{::ActiveSupport::JSON.encode(number)});")
        end
      end

      def grep(variable, pattern, &block)
        enumerate :grep, :variable => variable, :return => true, :method_args => [::ActiveSupport::JSON::Variable.new(pattern.inspect)], :yield_args => %w(value index), &block
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
        append_enumerable_function!("pluck(#{::ActiveSupport::JSON.encode(property)});")
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
        super(generator, "$$(#{::ActiveSupport::JSON.encode(pattern)})")
      end
    end
  end
end
