module ActionView
  # There's also a convenience method for rendering sub templates within the current controller that depends on a
  # single object (we call this kind of sub templates for partials). It relies on the fact that partials should
  # follow the naming convention of being prefixed with an underscore -- as to separate them from regular
  # templates that could be rendered on their own.
  #
  # In a template for Advertiser#account:
  #
  #  <%= render :partial => "account" %>
  #
  # This would render "advertiser/_account.erb" and pass the instance variable @account in as a local variable
  # +account+ to the template for display.
  #
  # In another template for Advertiser#buy, we could have:
  #
  #   <%= render :partial => "account", :locals => { :account => @buyer } %>
  #
  #   <% for ad in @advertisements %>
  #     <%= render :partial => "ad", :locals => { :ad => ad } %>
  #   <% end %>
  #
  # This would first render "advertiser/_account.erb" with @buyer passed in as the local variable +account+, then
  # render "advertiser/_ad.erb" and pass the local variable +ad+ to the template for display.
  #
  # == Rendering a collection of partials
  #
  # The example of partial use describes a familiar pattern where a template needs to iterate over an array and
  # render a sub template for each of the elements. This pattern has been implemented as a single method that
  # accepts an array and renders a partial by the same name as the elements contained within. So the three-lined
  # example in "Using partials" can be rewritten with a single line:
  #
  #   <%= render :partial => "ad", :collection => @advertisements %>
  #
  # This will render "advertiser/_ad.erb" and pass the local variable +ad+ to the template for display. An
  # iteration counter will automatically be made available to the template with a name of the form
  # +partial_name_counter+. In the case of the example above, the template would be fed +ad_counter+.
  #
  # NOTE: Due to backwards compatibility concerns, the collection can't be one of hashes. Normally you'd also
  # just keep domain objects, like Active Records, in there.
  #
  # == Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render :partial => "advertisement/ad", :locals => { :ad => @advertisement } %>
  #
  # This will render the partial "advertisement/_ad.erb" regardless of which controller this is being called from.
  #
  # == Rendering objects with the RecordIdentifier
  #
  # Instead of explicitly naming the location of a partial, you can also let the RecordIdentifier do the work if
  # you're following its conventions for RecordIdentifier#partial_path. Examples:
  #
  #  # @account is an Account instance, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "accounts/account", :locals => { :account => @buyer } %>
  #  <%= render :partial => @account %>
  #
  #  # @posts is an array of Post instances, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "posts/post", :collection => @posts %>
  #  <%= render :partial => @posts %>
  #
  # == Rendering the default case
  #
  # If you're not going to be using any of the options like collections or layouts, you can also use the short-hand
  # defaults of render to render partials. Examples:
  #
  #  # Instead of <%= render :partial => "account" %>
  #  <%= render "account" %>
  #
  #  # Instead of <%= render :partial => "account", :locals => { :account => @buyer } %>
  #  <%= render "account", :account => @buyer %>
  #
  #  # @account is an Account instance, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "accounts/account", :locals => { :account => @account } %>
  #  <%= render(@account) %>
  #
  #  # @posts is an array of Post instances, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "posts/post", :collection => @posts %>
  #  <%= render(@posts) %>
  #
  # == Rendering partials with layouts
  #
  # Partials can have their own layouts applied to them. These layouts are different than the ones that are
  # specified globally for the entire action, but they work in a similar fashion. Imagine a list with two types
  # of users:
  #
  #   <%# app/views/users/index.html.erb &>
  #   Here's the administrator:
  #   <%= render :partial => "user", :layout => "administrator", :locals => { :user => administrator } %>
  #
  #   Here's the editor:
  #   <%= render :partial => "user", :layout => "editor", :locals => { :user => editor } %>
  #
  #   <%# app/views/users/_user.html.erb &>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/_administrator.html.erb &>
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     <%= yield %>
  #   </div>
  #
  #   <%# app/views/users/_editor.html.erb &>
  #   <div id="editor">
  #     Deadline: <%= user.deadline %>
  #     <%= yield %>
  #   </div>
  #
  # ...this will return:
  #
  #   Here's the administrator:
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     Name: <%= user.name %>
  #   </div>
  #
  #   Here's the editor:
  #   <div id="editor">
  #     Deadline: <%= user.deadline %>
  #     Name: <%= user.name %>
  #   </div>
  #
  # You can also apply a layout to a block within any template:
  #
  #   <%# app/views/users/_chief.html.erb &>
  #   <% render(:layout => "administrator", :locals => { :user => chief }) do %>
  #     Title: <%= chief.title %>
  #   <% end %>
  #
  # ...this will return:
  #
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     Title: <%= chief.name %>
  #   </div>
  #
  # As you can see, the <tt>:locals</tt> hash is shared between both the partial and its layout.
  #
  # If you pass arguments to "yield" then this will be passed to the block. One way to use this is to pass
  # an array to layout and treat it as an enumerable.
  #
  #   <%# app/views/users/_user.html.erb &>
  #   <div class="user">
  #     Budget: $<%= user.budget %>
  #     <%= yield user %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb &>
  #   <% render :layout => @users do |user| %>
  #     Title: <%= user.title %>
  #   <% end %>
  #
  # This will render the layout for each user and yield to the block, passing the user, each time.
  #
  # You can also yield multiple times in one layout and use block arguments to differentiate the sections.
  #
  #   <%# app/views/users/_user.html.erb &>
  #   <div class="user">
  #     <%= yield user, :header %>
  #     Budget: $<%= user.budget %>
  #     <%= yield user, :footer %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb &>
  #   <% render :layout => @users do |user, section| %>
  #     <%- case section when :header -%>
  #       Title: <%= user.title %>
  #     <%- when :footer -%>
  #       Deadline: <%= user.deadline %>
  #     <%- end -%>
  #   <% end %>
  module Partials
    extend ActiveSupport::Memoizable
    extend ActiveSupport::Concern
    
    included do
      attr_accessor :_partial      
    end

    def _render_partial_from_controller(*args)
      @assigns_added = false
      _render_partial(*args)
    end

    def _render_partial(options = {}) #:nodoc:
      options[:locals] ||= {}

      case path = partial = options[:partial]
      when *_array_like_objects
        return _render_partial_collection(partial, options)
      else
        if partial.is_a?(ActionView::Helpers::FormBuilder)
          path = partial.class.to_s.demodulize.underscore.sub(/_builder$/, '')
          options[:locals].merge!(path.to_sym => partial)
        elsif !partial.is_a?(String)
          options[:object] = object = partial
          path = ActionController::RecordIdentifier.partial_path(object, controller_path)
        end
        _, _, prefix, object = parts = partial_parts(path, options)
        parts[1] = {:formats => parts[1]}
        template = find_by_parts(*parts)
        _render_partial_object(template, options, (object unless object == true))
      end
    end

    private
      def partial_parts(name, options)
        segments = name.split("/")
        parts = segments.pop.split(".")

        case parts.size
        when 1
          parts
        when 2, 3
          extension = parts.delete_at(1).to_sym
          if formats.include?(extension)
            self.formats.replace [extension]
          end
          parts.pop if parts.size == 2
        end

        path = parts.join(".")
        prefix = segments[0..-1].join("/")
        prefix = prefix.blank? ? controller_path : prefix
        parts = [path, formats, prefix]
        parts.push options[:object] || true
      end

      def _render_partial_with_block(layout, block, options)
        @_proc_for_layout = block
        concat(_render_partial(options.merge(:partial => layout)))
      ensure
        @_proc_for_layout = nil
      end

      def _render_partial_with_layout(layout, options)
        if layout
          prefix = controller && !layout.include?("/") ? controller.controller_path : nil
          layout = find_by_parts(layout, {:formats => formats}, prefix, true)
        end
        content = _render_partial(options)
        return _render_content_with_layout(content, layout, options[:locals])
      end

      def _array_like_objects
        array_like = [Array]
        if defined?(ActiveRecord)
          array_like.push(ActiveRecord::Associations::AssociationCollection, ActiveRecord::NamedScope::Scope)
        end
        array_like
      end

      def _render_partial_object(template, options, object = nil)
        if options.key?(:collection)
          _render_partial_collection(options.delete(:collection), options, template)
        else
          locals = (options[:locals] ||= {})
          object ||= locals[:object] || locals[template.variable_name]
          
          _set_locals(object, locals, template, options)
          
          self._partial = template
          
          _render_template(template, locals)
        end
      end

      def _set_locals(object, locals, template, options)
        locals[:object] = locals[template.variable_name] = object
        locals[options[:as]] = object if options[:as]
      end

      def _render_partial_collection(collection, options = {}, passed_template = nil) #:nodoc:
        return nil if collection.blank?
        
        spacer = options[:spacer_template] ? _render_partial(:partial => options[:spacer_template]) : ''

        locals = (options[:locals] ||= {})
        index, @_partial_path = 0, nil
        collection.map do |object|
          template = passed_template || begin
            _partial_path = 
              ActionController::RecordIdentifier.partial_path(object, controller_path)
            template = _pick_partial_template(_partial_path)
          end

          _set_locals(object, locals, template, options)
          locals[template.counter_name] = index
          
          index += 1
          
          self._partial = template
          
          _render_template(template, locals)
        end.join(spacer)
      end

      def _pick_partial_template(partial_path) #:nodoc:
        prefix = controller_path unless partial_path.include?('/')
        find_by_parts(partial_path, {:formats => formats}, prefix, true)
      end
      memoize :_pick_partial_template
  end
end
