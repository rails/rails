module ActionView
  module Helpers
    # Capture lets you extract parts of code which
    # can be used in other points of the template or even layout file.
    #
    # == Capturing a block into an instance variable
    #
    #   <% @script = capture do %>
    #     [some html...]
    #   <% end %>
    #
    # == Add javascript to header using content_for
    #
    # content_for("name") is a wrapper for capture which will 
    # make the fragment available by name to a yielding layout or template.
    #
    # layout.rhtml:
    #
    #   <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
    #   <head>
    #	    <title>layout with js</title>
    #	    <script type="text/javascript">
    #	      <%= yield :script %>
    #     </script>
    #   </head>
    #   <body>
    #     <%= yield %>
    #   </body>
    #   </html>
    #
    # view.rhtml
    #   
    #   This page shows an alert box!
    #
    #   <% content_for("script") do %>
    #     alert('hello world')
    #   <% end %>
    #
    #   Normal view text
    module CaptureHelper
      # Capture allows you to extract a part of the template into an 
      # instance variable. You can use this instance variable anywhere
      # in your templates and even in your layout. 
      # 
      # Example of capture being used in a .rhtml page:
      # 
      #   <% @greeting = capture do %>
      #     Welcome To my shiny new web page!
      #   <% end %>
      #
      # Example of capture being used in a .rxml page:
      # 
      #   @greeting = capture do
      #     'Welcome To my shiny new web page!'
      #   end
      def capture(*args, &block)
        # execute the block
        begin
          buffer = eval("_erbout", block.binding)
        rescue
          buffer = nil
        end
        
        if buffer.nil?
          capture_block(*args, &block)
        else
          capture_erb_with_buffer(buffer, *args, &block)
        end
      end
      
      # Calling content_for stores the block of markup for later use.
      # Subsequently, you can make calls to it by name with <tt>yield</tt>
      # in another template or in the layout. 
      # 
      # Example:
      # 
      #   <% content_for("header") do %>
      #     alert('hello world')
      #   <% end %>
      #
      # You can use yield :header anywhere in your templates.
      #
      #   <%= yield :header %>
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
          buffer = eval("_erbout", block.binding)
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
