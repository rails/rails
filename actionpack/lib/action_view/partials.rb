module ActionView
  # There's also a convenience method for rendering sub templates within the current controller that depends on a single object 
  # (we call this kind of sub templates for partials). It relies on the fact that partials should follow the naming convention of being 
  # prefixed with an underscore -- as to separate them from regular templates that could be rendered on their own. In the template for 
  # Advertiser#buy, we could have:
  #
  #   <% for ad in @advertisements %>
  #     <%= render_partial "ad", ad %>
  #   <% end %>
  #
  # This would render "advertiser/_ad.rhtml" and pass the local variable +ad+ to the template for display.
  #
  # == Rendering a collection of partials
  #
  # The example of partial use describes a familar pattern where a template needs to iterate over an array and render a sub
  # template for each of the elements. This pattern has been implemented as a single method that accepts an array and renders
  # a partial by the same name as the elements contained within. So the three-lined example in "Using partials" can be rewritten
  # with a single line:
  #
  #   <%= render_collection_of_partials "ad", @advertisements %>
  #
  # This will render "advertiser/_ad.rhtml" and pass the local variable +ad+ to the template for display. An iteration counter
  # will automatically be made available to the template with a name of the form +partial_name_counter+. In the case of the 
  # example above, the template would be fed +ad_counter+.
  # 
  # == Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render_partial "advertisement/ad", ad %>
  #
  # This will render the partial "advertisement/_ad.rhtml" regardless of which controller this is being called from.
  module Partials
    def render_partial(partial_path, object = nil, local_assigns = {})
      path, partial_name = partial_pieces(partial_path)
      object ||= controller.instance_variable_get("@#{partial_name}")
      counter_name  = partial_counter_name(partial_name)
      local_assigns = local_assigns.merge(counter_name => 1) unless local_assigns.has_key?(counter_name)
      render("#{path}/_#{partial_name}", { partial_name => object }.merge(local_assigns))
    end

    def render_collection_of_partials(partial_name, collection, partial_spacer_template = nil, local_assigns = {})
      collection_of_partials = Array.new
      counter_name = partial_counter_name(partial_name)
      collection.each_with_index do |element, counter|
        collection_of_partials.push(render_partial(partial_name, element, { counter_name => counter }.merge(local_assigns)))
      end

      return nil if collection_of_partials.empty?
      if partial_spacer_template
        spacer_path, spacer_name = partial_pieces(partial_spacer_template)
        collection_of_partials.join(render("#{spacer_path}/_#{spacer_name}"))
      else
        collection_of_partials
      end
    end
    
    private
      def partial_pieces(partial_path)
        if partial_path.include?('/')
          return File.dirname(partial_path), File.basename(partial_path)
        else
          return controller.send(:controller_name), partial_path
        end
      end

      def partial_counter_name(partial_name)
        "#{partial_name.split('/').last}_counter"
      end
  end
end
