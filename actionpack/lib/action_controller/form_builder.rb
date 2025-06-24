# frozen_string_literal: true

# :markup: markdown

module ActionController
  # # Action Controller Form Builder
  #
  # Override the default form builder for all views rendered by this controller
  # and any of its descendants. Accepts a subclass of
  # ActionView::Helpers::FormBuilder.
  #
  # For example, given a form builder:
  #
  #     class AdminFormBuilder < ActionView::Helpers::FormBuilder
  #       def special_field(name)
  #       end
  #     end
  #
  # The controller specifies a form builder as its default:
  #
  #     class AdminAreaController < ApplicationController
  #       default_form_builder AdminFormBuilder
  #     end
  #
  # Then in the view any form using `form_with` or `form_for` will be an
  # instance of the specified form builder:
  #
  #     <%= form_with(model: @instance) do |builder| %>
  #       <%= builder.special_field(:name) %>
  #     <% end %>
  module FormBuilder
    extend ActiveSupport::Concern

    included do
      class_attribute :_default_form_builder, instance_accessor: false
    end

    module ClassMethods
      # Set the form builder to be used as the default for all forms in the views
      # rendered by this controller and its subclasses.
      #
      # #### Parameters
      # *   `builder` - Default form builder. Accepts a subclass of
      #     ActionView::Helpers::FormBuilder
      def default_form_builder(builder)
        self._default_form_builder = builder
      end
    end

    # Default form builder for the controller
    def default_form_builder
      self.class._default_form_builder
    end
  end
end
