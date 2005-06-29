module ActionController
  # Example:
  #
  #   # Controller
  #   class BlogController < ApplicationController
  #     auto_complete_for :post, :title
  #   end
  #
  #   # View
  #   <%= text_field_with_auto_complete :post, title %>
  module AutoComplete
    def self.append_features(base) #:nodoc:
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      def auto_complete_for(object, method, options = {})
        define_method("auto_complete_for_#{object}_#{method}") do
          find_options = { 
            :conditions => [ "LOWER(#{method}) LIKE ?", '%' + request.raw_post.downcase + '%' ], 
            :order => "#{method} ASC",
            :limit => 10 }.merge!(options)
            
          @items = object.to_s.camelize.constantize.find(:all, find_options)

          render :inline => "<%= auto_complete_result @items, '#{method}' %>"
        end
      end
    end
  end
end