require 'active_support/core_ext/object/blank'

module ActionView
  # = Action View Partials
  #
  # There's also a convenience method for rendering sub templates within the current controller that depends on a
  # single object (we call this kind of sub templates for partials). It relies on the fact that partials should
  # follow the naming convention of being prefixed with an underscore -- as to separate them from regular
  # templates that could be rendered on their own.
  #
  # In a template for Advertiser#account:
  #
  #  <%= render :partial => "account" %>
  #
  # This would render "advertiser/_account.html.erb".
  #
  # In another template for Advertiser#buy, we could have:
  #
  #   <%= render :partial => "account", :locals => { :account => @buyer } %>
  #
  #   <% @advertisements.each do |ad| %>
  #     <%= render :partial => "ad", :locals => { :ad => ad } %>
  #   <% end %>
  #
  # This would first render "advertiser/_account.html.erb" with @buyer passed in as the local variable +account+, then
  # render "advertiser/_ad.html.erb" and pass the local variable +ad+ to the template for display.
  #
  # == The :as and :object options
  #
  # By default <tt>ActionView::PartialRenderer</tt> doesn't have any local variables.
  # The <tt>:object</tt> option can be used to pass an object to the partial. For instance:
  #
  #   <%= render :partial => "account", :object => @buyer %>
  #
  # would provide the +@buyer+ object to the partial, available under the local variable +account+ and is
  # equivalent to:
  #
  #   <%= render :partial => "account", :locals => { :account => @buyer } %>
  #
  # With the <tt>:as</tt> option we can specify a different name for said local variable. For example, if we
  # wanted it to be +user+ instead of +account+ we'd do:
  #
  #   <%= render :partial => "account", :object => @buyer, :as => 'user' %>
  #
  # This is equivalent to
  #
  #   <%= render :partial => "account", :locals => { :user => @buyer } %>
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
  # This will render "advertiser/_ad.html.erb" and pass the local variable +ad+ to the template for display. An
  # iteration counter will automatically be made available to the template with a name of the form
  # +partial_name_counter+. In the case of the example above, the template would be fed +ad_counter+.
  #
  # The <tt>:as</tt> option may be used when rendering partials.
  #
  # You can specify a partial to be rendered between elements via the <tt>:spacer_template</tt> option.
  # The following example will render <tt>advertiser/_ad_divider.html.erb</tt> between each ad partial:
  #
  #   <%= render :partial => "ad", :collection => @advertisements, :spacer_template => "ad_divider" %>
  #
  # If the given <tt>:collection</tt> is nil or empty, <tt>render</tt> will return nil. This will allow you
  # to specify a text which will displayed instead by using this form:
  #
  #   <%= render(:partial => "ad", :collection => @advertisements) || "There's no ad to be displayed" %>
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
  # This will render the partial "advertisement/_ad.html.erb" regardless of which controller this is being called from.
  #
  # == Rendering objects that respond to `to_partial_path`
  #
  # Instead of explicitly naming the location of a partial, you can also let PartialRenderer do the work
  # and pick the proper path by checking `to_proper_path` method. If the object passed to render is a collection,
  # all objects must return the same path.
  #
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render :partial => "accounts/account", :locals => { :account => @account} %>
  #  <%= render :partial => @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on `to_partial_path`,
  #  # that's why we can replace:
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
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render :partial => "accounts/account", :locals => { :account => @account} %>
  #  <%= render @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on `to_partial_path`,
  #  # that's why we can replace:
  #  # <%= render :partial => "posts/post", :collection => @posts %>
  #  <%= render @posts %>
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
  #   <%= render(:layout => "administrator", :locals => { :user => chief }) do %>
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
  #   <%= render :layout => @users do |user| %>
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
  #   <%= render :layout => @users do |user, section| %>
  #     <%- case section when :header -%>
  #       Title: <%= user.title %>
  #     <%- when :footer -%>
  #       Deadline: <%= user.deadline %>
  #     <%- end -%>
  #   <% end %>
  class PartialRenderer < AbstractRenderer
    PARTIAL_NAMES = Hash.new { |h,k| h[k] = {} }

    def initialize(*)
      super
      @context_prefix = @lookup_context.prefixes.first
      @partial_names = PARTIAL_NAMES[@context_prefix]
    end

    def render(context, options, block)
      setup(context, options, block)
      identifier = (@template = find_partial) ? @template.identifier : @path

      @lookup_context.rendered_format ||= begin
        if @template && @template.formats.present?
          @template.formats.first
        else
          formats.first
        end
      end

      if @collection
        instrument(:collection, :identifier => identifier || "collection", :count => @collection.size) do
          render_collection
        end
      else
        instrument(:partial, :identifier => identifier) do
          render_partial
        end
      end
    end

    def render_collection
      return nil if @collection.blank?

      if @options.key?(:spacer_template)
        spacer = find_template(@options[:spacer_template]).render(@view, @locals)
      end

      result = @template ? collection_with_template : collection_without_template
      result.join(spacer).html_safe
    end

    def render_partial
      locals, view, block = @locals, @view, @block
      object, as = @object, @variable

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s)
      end

      object ||= locals[as]
      locals[as] = object

      content = @template.render(view, locals) do |*name|
        view._layout_for(*name, &block)
      end

      content = layout.render(view, locals){ content } if layout
      content
    end

    private

    def setup(context, options, block)
      @view   = context
      partial = options[:partial]

      @options = options
      @locals  = options[:locals] || {}
      @block   = block
      @details = extract_details(options)

      prepend_formats(options[:formats])

      if String === partial
        @object     = options[:object]
        @path       = partial
        @collection = collection
      else
        @object = partial

        if @collection = collection_from_object || collection
          paths = @collection_data = @collection.map { |o| partial_path(o) }
          @path = paths.uniq.size == 1 ? paths.first : nil
        else
          @path = partial_path
        end
      end

      if @path
        @variable, @variable_counter = retrieve_variable(@path)
      else
        paths.map! { |path| retrieve_variable(path).unshift(path) }
      end

      if String === partial && @variable.to_s !~ /^[a-z_][a-zA-Z_0-9]*$/
        raise ArgumentError.new("The partial name (#{partial}) is not a valid Ruby identifier; " +
                                "make sure your partial name starts with a letter or underscore, " +
                                "and is followed by any combinations of letters, numbers, or underscores.")
      end

      extract_format(@path, @details)
      self
    end

    def collection
      if @options.key?(:collection)
        collection = @options[:collection]
        collection.respond_to?(:to_ary) ? collection.to_ary : []
      end
    end

    def collection_from_object
      if @object.respond_to?(:to_ary)
        @object.to_ary
      end
    end

    def find_partial
      if path = @path
        locals = @locals.keys
        locals << @variable
        locals << @variable_counter if @collection
        find_template(path, locals)
      end
    end

    def find_template(path=@path, locals=@locals.keys)
      prefixes = path.include?(?/) ? [] : @lookup_context.prefixes
      @lookup_context.find_template(path, prefixes, true, locals, @details)
    end

    def collection_with_template
      segments, locals, template = [], @locals, @template
      as, counter = @variable, @variable_counter

      locals[counter] = -1

      @collection.each do |object|
        locals[counter] += 1
        locals[as] = object
        segments << template.render(@view, locals)
      end

      segments
    end

    def collection_without_template
      segments, locals, collection_data = [], @locals, @collection_data
      index, template, cache = -1, nil, {}
      keys = @locals.keys

      @collection.each_with_index do |object, i|
        path, *data = collection_data[i]
        template = (cache[path] ||= find_template(path, keys + data))
        locals[data[0]] = object
        locals[data[1]] = (index += 1)
        segments << template.render(@view, locals)
      end

      @template = template
      segments
    end

    def partial_path(object = @object)
      object = object.to_model if object.respond_to?(:to_model)

      path = if object.respond_to?(:to_partial_path)
        object.to_partial_path
      else
        klass = object.class
        if klass.respond_to?(:model_name)
          ActiveSupport::Deprecation.warn "ActiveModel-compatible objects whose classes return a #model_name that responds to #partial_path are deprecated. Please respond to #to_partial_path directly instead."
          klass.model_name.partial_path
        else
          raise ArgumentError.new("'#{object.inspect}' is not an ActiveModel-compatible object that returns a valid partial path.")
        end
      end

      @partial_names[path] ||= merge_prefix_into_object_path(@context_prefix, path.dup)
    end

    def merge_prefix_into_object_path(prefix, object_path)
      if prefix.include?(?/) && object_path.include?(?/)
        prefixes = []
        prefix_array = File.dirname(prefix).split('/')
        object_path_array = object_path.split('/')[0..-3] # skip model dir & partial

        prefix_array.each_with_index do |dir, index|
          break if dir == object_path_array[index]
          prefixes << dir
        end

        (prefixes << object_path).join("/")
      else
        object_path
      end
    end

    def retrieve_variable(path)
      variable = @options.fetch(:as) { path[%r'_?(\w+)(\.\w+)*$', 1] }.try(:to_sym)
      variable_counter = :"#{variable}_counter" if @collection
      [variable, variable_counter]
    end
  end
end
