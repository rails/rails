module ActionController
  module Macros
    module InPlaceEditing #:nodoc:
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
      end

      # DEPRECATION WARNING: This method will become a separate plugin when Rails 2.0 ships.
      #
      # Example:
      #
      #   # Controller
      #   class BlogController < ApplicationController
      #     in_place_edit_for :post, :title
      #   end
      #
      #   # View
      #   <%= in_place_editor_field :post, 'title' %>
      #
      # For help on defining an in place editor in the browser,
      # see ActionView::Helpers::JavaScriptHelper.
      module ClassMethods
        def in_place_edit_for(object, attribute, options = {})
          define_method("set_#{object}_#{attribute}") do
            @item = object.to_s.camelize.constantize.find(params[:id])
            @item.update_attribute(attribute, params[:value])
            render :text => @item.send(attribute)
          end
        end
      end
    end
  end
end
