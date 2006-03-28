module ActionView
  # There's also a convenience method for rendering sub templates within the current controller that depends on a single object 
  # (we call this kind of sub templates for partials). It relies on the fact that partials should follow the naming convention of being 
  # prefixed with an underscore -- as to separate them from regular templates that could be rendered on their own. 
  #
  # In a template for Advertiser#account:
  #
  #  <%= render :partial => "account" %>
  #
  # This would render "advertiser/_account.rhtml" and pass the instance variable @account in as a local variable +account+ to 
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
  # This would first render "advertiser/_account.rhtml" with @buyer passed in as the local variable +account+, then render 
  # "advertiser/_ad.rhtml" and pass the local variable +ad+ to the template for display.
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
  # This will render "advertiser/_ad.rhtml" and pass the local variable +ad+ to the template for display. An iteration counter
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
  # This will render the partial "advertisement/_ad.rhtml" regardless of which controller this is being called from.
  module Partials
    # Deprecated, use render :partial
    def render_partial(partial_path, local_assigns = nil, deprecated_local_assigns = nil) #:nodoc:
      path, partial_name = partial_pieces(partial_path)
      object = extracting_object(partial_name, local_assigns, deprecated_local_assigns)
      local_assigns = extract_local_assigns(local_assigns, deprecated_local_assigns)
      local_assigns = local_assigns ? local_assigns.clone : {}
      add_counter_to_local_assigns!(partial_name, local_assigns)
      add_object_to_local_assigns!(partial_name, local_assigns, object)

      if logger
        ActionController::Base.benchmark("Rendered #{path}/_#{partial_name}", Logger::DEBUG, false) do
          render("#{path}/_#{partial_name}", local_assigns)
        end
      else
        render("#{path}/_#{partial_name}", local_assigns)
      end
    end

    # Deprecated, use render :partial, :collection
    def render_partial_collection(partial_name, collection, partial_spacer_template = nil, local_assigns = nil) #:nodoc:
      collection_of_partials = Array.new
      counter_name = partial_counter_name(partial_name)
      local_assigns = local_assigns ? local_assigns.clone : {}
      collection.each_with_index do |element, counter|
        local_assigns[counter_name] = counter
        collection_of_partials.push(render_partial(partial_name, element, local_assigns))
      end

      return " " if collection_of_partials.empty?

      if partial_spacer_template
        spacer_path, spacer_name = partial_pieces(partial_spacer_template)
        collection_of_partials.join(render("#{spacer_path}/_#{spacer_name}"))
      else
        collection_of_partials.join
      end
    end
    
    alias_method :render_collection_of_partials, :render_partial_collection
    
    private
      def partial_pieces(partial_path)
        if partial_path.include?('/')
          return File.dirname(partial_path), File.basename(partial_path)
        else
          return controller.class.controller_path, partial_path
        end
      end

      def partial_counter_name(partial_name)
        "#{partial_name.split('/').last}_counter".intern
      end
      
      def extracting_object(partial_name, local_assigns, deprecated_local_assigns)
        if local_assigns.is_a?(Hash) || local_assigns.nil?
          controller.instance_variable_get("@#{partial_name}")
        else
          # deprecated form where object could be passed in as second parameter
          local_assigns
        end
      end
      
      def extract_local_assigns(local_assigns, deprecated_local_assigns)
        local_assigns.is_a?(Hash) ? local_assigns : deprecated_local_assigns
      end
      
      def add_counter_to_local_assigns!(partial_name, local_assigns)
        counter_name = partial_counter_name(partial_name)
        local_assigns[counter_name] = 1 unless local_assigns.has_key?(counter_name)
      end

      def add_object_to_local_assigns!(partial_name, local_assigns, object)
        local_assigns[partial_name.intern] ||=
          if object.is_a?(ActionView::Base::ObjectWrapper)
            object.value
          else
            object
          end || controller.instance_variable_get("@#{partial_name}")
      end
  end
end
