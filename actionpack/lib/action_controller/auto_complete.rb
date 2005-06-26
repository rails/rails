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
      def auto_complete_for(object, method)
        define_method("auto_complete_for_#{object}_#{method}") do
          @items = object.to_s.camelize.constantize.find(
            :all, 
            :conditions => [ "LOWER(#{method}) LIKE ?", '%' + request.raw_post.downcase + '%' ], 
            :order => "#{method} ASC"
          )

          render :inline => "<%= auto_complete_result @items, '#{method}' %>"
        end
      end
    end
  end
end