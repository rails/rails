module ActionView
  module Helpers
    # CaptureHelper exposes methods to let you extract generated markup which
    # can be used in other parts of a template or layout file.
    # It provides a method to capture blocks into variables through capture and 
    # a way to capture a block of code for use in a layout through content_for.
    module CaptureHelper
      # The capture method allows you to extract a part of the template into a 
      # variable. You can then use this value anywhere in your templates or layout. 
      # 
      # ==== Examples
      # The capture method can be used in RHTML (ERb) templates...
      # 
      #   <% @greeting = capture do %>
      #     Welcome to my shiny new web page!  The date and time is
      #     <%= Time.now %>
      #   <% end %>
      #
      # ...and Builder (RXML) templates.
      # 
      #   @timestamp = capture do
      #     "The current timestamp is #{Time.now}."
      #   end
      #
      # You can then use the content as a variable anywhere else.  For
      # example:
      #
      #   <html>
      #   <head><title><%= @greeting %></title></head>
      #   <body>
      #   <b><%= @greeting %></b>
      #   </body></html>
      #
      def capture(*args, &block)
        # execute the block
        begin
          buffer = eval(ActionView::Base.erb_variable, block.binding)
        rescue
          buffer = nil
        end
        
        if buffer.nil?
          capture_block(*args, &block).to_s
        else
          capture_erb_with_buffer(buffer, *args, &block).to_s
        end
      end
      
      # Calling content_for stores the block of markup in an identifier for later use.
      # You can make subsequent calls to the stored content in another template or in the layout
      # by calling it by name with <tt>yield</tt>.
      # 
      # ==== Examples
      # 
      #   <% content_for("authorized") do %>
      #     alert('You are not authorized for that!')
      #   <% end %>
      #
      # You can then use <tt>yield :authorized</tt> anywhere in your templates.
      #
      #   <%= yield :authorized if current_user == nil %>
      #
      # You can also use these variables in a layout.  For example:
      #
      #   <!-- This is the layout -->
      #   <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
      #   <head>
      #	    <title>My Website</title>
      #	    <%= yield :script %>
      #   </head>
      #   <body>
      #     <%= yield %>
      #   </body>
      #   </html>
      #
      # And now we'll create a view that has a content_for call that
      # creates the <tt>script</tt> identifier.
      #
      #   <!-- This is our view -->
      #   Please login!
      #
      #   <% content_for("script") do %>
      #     <script type="text/javascript">alert('You are not authorized for this action!')</script>
      #   <% end %>
      #
      # Then in another view you may want to do something like this:
      #
      #   <%= link_to_remote 'Logout', :action => 'logout' %>
      #
      #   <% content_for("script") do %>
      #     <%= javascript_include_tag :defaults %>
      #   <% end %>
      #
      # That will include Prototype and Scriptaculous into the page; this technique
      # is useful if you'll only be using these scripts on a few views.
      #
      # NOTE: Beware that content_for is ignored in caches. So you shouldn't use it
      # for elements that are going to be fragment cached.
      #
      # The deprecated way of accessing a content_for block was to use a instance variable
      # named @@content_for_#{name_of_the_content_block}@. So <tt><%= content_for('footer') %></tt>
      # would be avaiable as <tt><%= @content_for_footer %></tt>. The preferred notation now is
      # <tt><%= yield :footer %></tt>.
      def content_for(name, content = nil, &block)
        eval "@content_for_#{name} = (@content_for_#{name} || '') + capture(&block)"
      end

      private
        def capture_block(*args, &block)
          block.call(*args)
        end
      
        def capture_erb(*args, &block)
          buffer = eval(ActionView::Base.erb_variable, block.binding)
          capture_erb_with_buffer(buffer, *args, &block)
        end
      
        def capture_erb_with_buffer(buffer, *args, &block)
          pos = buffer.length
          block.call(*args)
        
          # extract the block 
          data = buffer[pos..-1]
        
          # replace it in the original with empty string
          buffer[pos..-1] = ''
        
          data
        end
      
        def erb_content_for(name, &block)
          eval "@content_for_#{name} = (@content_for_#{name} || '') + capture_erb(&block)"
        end
      
        def block_content_for(name, &block)
          eval "@content_for_#{name} = (@content_for_#{name} || '') + capture_block(&block)"
        end
    end
  end
end
