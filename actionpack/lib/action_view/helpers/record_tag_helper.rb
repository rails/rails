module ActionView
  # = Action View Record Tag Helpers
  module Helpers
    module RecordTagHelper
      include ActionView::RecordIdentifier

      # Produces a wrapper DIV element with id and class parameters that
      # relate to the specified Active Record object. Usage example:
      #
      #    <%= div_for(@person, class: "foo") do %>
      #       <%= @person.name %>
      #    <% end %>
      #
      # produces:
      #
      #    <div id="person_123" class="person foo"> Joe Bloggs </div>
      #
      # You can also pass an array of Active Record objects, which will then
      # get iterated over and yield each record as an argument for the block.
      # For example:
      #
      #    <%= div_for(@people, class: "foo") do |person| %>
      #      <%= person.name %>
      #    <% end %>
      #
      # produces:
      #
      #    <div id="person_123" class="person foo"> Joe Bloggs </div>
      #    <div id="person_124" class="person foo"> Jane Bloggs </div>
      #
      def div_for(record, *args, &block)
        content_tag_for(:div, record, *args, &block)
      end

      # content_tag_for creates an HTML element with id and class parameters
      # that relate to the specified Active Record object. For example:
      #
      #    <%= content_tag_for(:tr, @person) do %>
      #      <td><%= @person.first_name %></td>
      #      <td><%= @person.last_name %></td>
      #    <% end %>
      #
      # would produce the following HTML (assuming @person is an instance of
      # a Person object, with an id value of 123):
      #
      #    <tr id="person_123" class="person">....</tr>
      #
      # If you require the HTML id attribute to have a prefix, you can specify it:
      #
      #    <%= content_tag_for(:tr, @person, :foo) do %> ...
      #
      # produces:
      #
      #    <tr id="foo_person_123" class="person">...
      #
      # You can also pass an array of objects which this method will loop through
      # and yield the current object to the supplied block, reducing the need for
      # having to iterate through the object (using <tt>each</tt>) beforehand.
      # For example (assuming @people is an array of Person objects):
      #
      #    <%= content_tag_for(:tr, @people) do |person| %>
      #      <td><%= person.first_name %></td>
      #      <td><%= person.last_name %></td>
      #    <% end %>
      #
      # produces:
      #
      #    <tr id="person_123" class="person">...</tr>
      #    <tr id="person_124" class="person">...</tr>
      #
      # content_tag_for also accepts a hash of options, which will be converted to
      # additional HTML attributes. If you specify a <tt>:class</tt> value, it will be combined
      # with the default class name for your object. For example:
      #
      #    <%= content_tag_for(:li, @person, class: "bar") %>...
      #
      # produces:
      #
      #    <li id="person_123" class="person bar">...
      #
      def content_tag_for(tag_name, single_or_multiple_records, prefix = nil, options = nil, &block)
        options, prefix = prefix, nil if prefix.is_a?(Hash)

        Array(single_or_multiple_records).map do |single_record|
          content_tag_for_single_record(tag_name, single_record, prefix, options, &block)
        end.join("\n").html_safe
      end

      private

        # Called by <tt>content_tag_for</tt> internally to render a content tag
        # for each record.
        def content_tag_for_single_record(tag_name, record, prefix, options, &block)
          options = options ? options.dup : {}
          options[:class] = [ dom_class(record, prefix), options[:class] ].compact
          options[:id]    = dom_id(record, prefix)

          if block_given?
            content_tag(tag_name, capture(record, &block), options)
          else
            content_tag(tag_name, "", options)
          end
        end
    end
  end
end
