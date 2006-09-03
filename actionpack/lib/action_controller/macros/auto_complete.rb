module ActionController
  # Macros are class-level calls that add pre-defined actions to the controller based on the parameters passed in.
  # Currently, they're used to bridge the JavaScript macros, like autocompletion and in-place editing, with the controller
  # backing.
  module Macros
    module AutoComplete #:nodoc:
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
      end

      # DEPRECATION WARNING: This method will become a separate plugin when Rails 2.0 ships.
      #
      # Example:
      #
      #   # Controller
      #   class BlogController < ApplicationController
      #     auto_complete_for :post, :title
      #   end
      #
      #   # View
      #   <%= text_field_with_auto_complete :post, title %>
      #
      # By default, auto_complete_for limits the results to 10 entries,
      # and sorts by the given field.
      # 
      # auto_complete_for takes a third parameter, an options hash to
      # the find method used to search for the records:
      #
      #   auto_complete_for :post, :title, :limit => 15, :order => 'created_at DESC'
      #
      # For help on defining text input fields with autocompletion, 
      # see ActionView::Helpers::JavaScriptHelper.
      #
      # For more examples, see script.aculo.us:
      # * http://script.aculo.us/demos/ajax/autocompleter
      # * http://script.aculo.us/demos/ajax/autocompleter_customized
      module ClassMethods
        def auto_complete_for(object, method, options = {})
          define_method("auto_complete_for_#{object}_#{method}") do
            find_options = { 
              :conditions => [ "LOWER(#{method}) LIKE ?", '%' + params[object][method].downcase + '%' ], 
              :order => "#{method} ASC",
              :limit => 10 }.merge!(options)
            
            @items = object.to_s.camelize.constantize.find(:all, find_options)

            render :inline => "<%= auto_complete_result @items, '#{method}' %>"
          end
        end
      end
    end
  end
end