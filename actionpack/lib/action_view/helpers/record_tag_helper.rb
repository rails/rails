module ActionView
  module Helpers
    module RecordTagHelper
      # Produces a wrapper DIV element with id and class parameters that
      # relate to the specified ActiveRecord object. Usage example:
      #
      #    <% div_for(@person, :class => "foo") do %>
      #       <%=h @person.name %>
      #    <% end %>
      #
      # produces:
      #
      #    <div id="person_123" class="person foo"> Joe Bloggs </div>
      #
      def div_for(record, *args, &block)
        content_tag_for(:div, record, *args, &block)
      end
  
      # content_tag_for creates an HTML element with id and class parameters
      # that relate to the specified ActiveRecord object. For example:
      #
      #    <% content_tag_for(:tr, @person) do %>
      #      <td><%=h @person.first_name %></td>
      #      <td><%=h @person.last_name %></td>
      #    <% end %>
      #
      # would produce hthe following HTML (assuming @person is an instance of
      # a Person object, with an id value of 123):
      #
      #    <tr id="person_123" class="person">....</tr>
      #
      # If you require the HTML id attribute to have a prefix, you can specify it:
      #
      #    <% content_tag_for(:tr, @person, :foo) do %> ...
      #
      # produces:
      #    
      #    <tr id="foo_person_123" class="person">...
      #
      # content_tag_for also accepts a hash of options, which will be converted to
      # additional HTML attributes. If you specify a +:class+ value, it will be combined
      # with the default class name for your object. For example:
      #
      #    <% content_tag_for(:li, @person, :class => "bar") %>...
      #
      # produces:
      #
      #    <li id="person_123" class="person bar">...
      #
      def content_tag_for(tag_name, record, *args, &block)
        prefix  = args.first.is_a?(Hash) ? nil : args.shift
        options = args.first.is_a?(Hash) ? args.shift : {}
        concat content_tag(tag_name, capture(&block), 
          options.merge({ :class => "#{dom_class(record)} #{options[:class]}".strip, :id => dom_id(record, prefix) })), 
          block.binding
      end
    end
  end
end