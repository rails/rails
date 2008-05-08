module ActionView
  # There's also a convenience method for rendering sub templates within the current controller that depends on a single object
  # (we call this kind of sub templates for partials). It relies on the fact that partials should follow the naming convention of being
  # prefixed with an underscore -- as to separate them from regular templates that could be rendered on their own.
  #
  # In a template for Advertiser#account:
  #
  #  <%= render :partial => "account" %>
  #
  # This would render "advertiser/_account.erb" and pass the instance variable @account in as a local variable +account+ to
  # the template for display.
  #
  # In another template for Advertiser#buy, we could have:
  #
  #   <%= render :partial => "account", :locals => { :account => @buyer } %>
  #
  #   <% for ad in @advertisements %>
  #     <%= render :partial => "ad", :locals => { :ad => ad } %>
  #   <% end %>
  #
  # This would first render "advertiser/_account.erb" with @buyer passed in as the local variable +account+, then render
  # "advertiser/_ad.erb" and pass the local variable +ad+ to the template for display.
  #
  # == Rendering a collection of partials
  #
  # The example of partial use describes a familiar pattern where a template needs to iterate over an array and render a sub
  # template for each of the elements. This pattern has been implemented as a single method that accepts an array and renders
  # a partial by the same name as the elements contained within. So the three-lined example in "Using partials" can be rewritten
  # with a single line:
  #
  #   <%= render :partial => "ad", :collection => @advertisements %>
  #
  # This will render "advertiser/_ad.erb" and pass the local variable +ad+ to the template for display. An iteration counter
  # will automatically be made available to the template with a name of the form +partial_name_counter+. In the case of the
  # example above, the template would be fed +ad_counter+.
  #
  # NOTE: Due to backwards compatibility concerns, the collection can't be one of hashes. Normally you'd also just keep domain objects,
  # like Active Records, in there.
  #
  # == Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render :partial => "advertisement/ad", :locals => { :ad => @advertisement } %>
  #
  # This will render the partial "advertisement/_ad.erb" regardless of which controller this is being called from.
  #
  # == Rendering partials with layouts
  #
  # Partials can have their own layouts applied to them. These layouts are different than the ones that are specified globally
  # for the entire action, but they work in a similar fashion. Imagine a list with two types of users:
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
  #     Deadline: $<%= user.deadline %>
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
  #     Deadline: $<%= user.deadline %>
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
  module Partials
    private
      def render_partial(partial_path, object_assigns = nil, local_assigns = {}) #:nodoc:
        case partial_path
        when String, Symbol, NilClass
          # Render the template
          ActionView::PartialTemplate.new(self, partial_path, object_assigns, local_assigns).render_template
        when ActionView::Helpers::FormBuilder
          builder_partial_path = partial_path.class.to_s.demodulize.underscore.sub(/_builder$/, '')
          render_partial(builder_partial_path, object_assigns, (local_assigns || {}).merge(builder_partial_path.to_sym => partial_path))
        when Array, ActiveRecord::Associations::AssociationCollection, ActiveRecord::NamedScope::Scope
          if partial_path.any?
            collection = partial_path
            render_partial_collection(nil, collection, nil, local_assigns)
          else
            ""
          end
        else
          render_partial(ActionController::RecordIdentifier.partial_path(partial_path, controller.class.controller_path), partial_path, local_assigns)
        end
      end

      def render_partial_collection(partial_path, collection, partial_spacer_template = nil, local_assigns = {}) #:nodoc:
        return " " if collection.empty?

        local_assigns = local_assigns ? local_assigns.clone : {}
        spacer = partial_spacer_template ? render(:partial => partial_spacer_template) : ''

        if partial_path.nil?
          render_partial_collection_with_unknown_partial_path(collection, local_assigns)
        else
          render_partial_collection_with_known_partial_path(collection, partial_path, local_assigns)
        end.join(spacer)
      end

      def render_partial_collection_with_known_partial_path(collection, partial_path, local_assigns)
        template = ActionView::PartialTemplate.new(self, partial_path, nil, local_assigns)
        collection.map do |element|
          template.render_member(element)
        end
      end

      def render_partial_collection_with_unknown_partial_path(collection, local_assigns)
        templates = Hash.new
        i = 0
        collection.map do |element|
          partial_path = ActionController::RecordIdentifier.partial_path(element, controller.class.controller_path)
          template = templates[partial_path] ||= ActionView::PartialTemplate.new(self, partial_path, nil, local_assigns)
          template.counter = i
          i += 1
          template.render_member(element)
        end
      end
  end
end
