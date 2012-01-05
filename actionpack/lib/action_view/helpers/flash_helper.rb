module ActionView
  module Helpers
    module FlashHelper
      # Helper to render all messages stored on +flash+ object. You can customize the output with the +options+ hash.
      # 
      # ==== Options
      # * <tt>:with_parent_element</tt> - Sets the parent element that will be used on each message (defaults to :p).
      # * <tt>:using_class</tt>         - Sets the class used on the parent element of each message (defaults to :flash).
      #
      # ==== Examples                 
      # 
      # On Controller:
      #                
      #   class PostsController < ApplicationController
      #     def index
      #       flash[:notice] = "Everything is ok :)"
      #       flash[:alert] =  "Error :("
      #     end
      #   end
      #      
      # Then on the view:
      # 
      #   <%= flash_messages %>
      #   # => <p class="flash flash_notice">Everything is ok :)</p>
      #   #    <p class="flash flash_alert">Error :(</p>
      # 
      #   <%= flash_messages :with_parent_element => :div %>
      #   # => <div class="flash flash_notice">Everything is ok :)</div>
      #   #    <div class="flash flash_alert">Error :(</div>
      # 
      #   <%= flash_messages :using_class => :message %>
      #   # => <p class="message message_notice">Everything is ok :)</p>
      #   #    <p class="message message_alert">Error :(</p>
      # 
      #   <%= flash_messages :with_parent_element => :div, :using_class => :message %>
      #   # => <div class="message message_notice">Everything is ok :)</div>
      #   #    <div class="message message_alert">Error :(</div>   
      # 
      #   <%= flash_messages :using_class => :nil %>
      #   # => <p>Everything is ok :)</p>
      #   #    <p>Error :(</p>   
      def flash_messages(options = {})
        parent_element = options.delete(:with_parent_element) { :p }

        messages = ""
        options.default = "" # This is needed to use the key :using_class with nil value

        flash.each do |key, value|                                                                 
          parent_element_class = class_for_flash_message_parent_element(options.merge(:flash_message_key => key))

          messages << content_tag(parent_element, :class => parent_element_class) { value } + "\n"
        end

        messages.html_safe
      end      

      protected
        def class_for_flash_message_parent_element(options = {})
          if options[:using_class]
            parent_element_class = (options.delete(:using_class) { "flash" }).to_s

            "#{parent_element_class} #{parent_element_class}_#{options[:flash_message_key]}"
          else
            nil
          end
        end
    end
  end
end