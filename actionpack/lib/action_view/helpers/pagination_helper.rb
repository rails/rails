module ActionView
  module Helpers
    # Provides methods for linking to ActionController::Pagination objects.
    #
    # You can also build your links manually, like in this example:
    #
    # <%= link_to "Previous page", { :page => paginator.current.previous } if paginator.current.previous %>
    #
    # <%= link_to "Next page", { :page => paginator.current.next } if paginator.current.next =%>
    module PaginationHelper
      unless const_defined?(:DEFAULT_OPTIONS)
        DEFAULT_OPTIONS = {
          :name => :page,
          :window_size => 2,
          :always_show_anchors => true,
          :link_to_current_page => false,
          :params => {}
        }
      end

      # Creates a basic HTML link bar for the given +paginator+. 
      #
      # +options+ are:
      # <tt>:name</tt>::                 the routing name for this paginator
      #                                  (defaults to +page+)
      # <tt>:window_size</tt>::          the number of pages to show around 
      #                                  the current page (defaults to +2+)
      # <tt>:always_show_anchors</tt>::  whether or not the first and last
      #                                  pages should always be shown
      #                                  (defaults to +true+)
      # <tt>:link_to_current_page</tt>:: whether or not the current page
      #                                  should be linked to (defaults to
      #                                  +false+)
      # <tt>:params</tt>::               any additional routing parameters
      #                                  for page URLs
      def pagination_links(paginator, options={})
        options.merge!(DEFAULT_OPTIONS) {|key, old, new| old}
        
        window_pages = paginator.current.window(options[:window_size]).pages

        return if window_pages.length <= 1 unless
          options[:link_to_current_page]
        
        first, last = paginator.first, paginator.last
        
        returning html = '' do
          if options[:always_show_anchors] and not window_pages[0].first?
            html << link_to(first.number, { options[:name] => first }.update( options[:params] ))
            html << ' ... ' if window_pages[0].number - first.number > 1
            html << ' '
          end
          
          window_pages.each do |page|
            if paginator.current == page && !options[:link_to_current_page]
              html << page.number.to_s
            else
              html << link_to(page.number, { options[:name] => page }.update( options[:params] ))
            end
            html << ' '
          end
          
          if options[:always_show_anchors] && !window_pages.last.last?
            html << ' ... ' if last.number - window_pages[-1].number > 1
            html << link_to(paginator.last.number, { options[:name] => last }.update( options[:params]))
          end
        end
      end
      
    end
  end
end
