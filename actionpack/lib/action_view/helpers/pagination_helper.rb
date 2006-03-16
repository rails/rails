module ActionView
  module Helpers
    # Provides methods for linking to ActionController::Pagination objects.
    #
    # You can also build your links manually, like in this example:
    #
    # <%= link_to "Previous page", { :page => paginator.current.previous } if paginator.current.previous %>
    #
    # <%= link_to "Next page", { :page => paginator.current.next } if paginator.current.next %>
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
      # +html_options+ are passed to +link_to+.
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
      def pagination_links(paginator, options={}, html_options={})
        name = options[:name] || DEFAULT_OPTIONS[:name]
        params = (options[:params] || DEFAULT_OPTIONS[:params]).clone
        
        pagination_links_each(paginator, options) do |n|
          params[name] = n
          link_to(n.to_s, params, html_options)
        end
      end

      # Iterate through the pages of a given +paginator+, invoking a
      # block for each page number that needs to be rendered as a link.
      def pagination_links_each(paginator, options)
        options = DEFAULT_OPTIONS.merge(options)
        link_to_current_page = options[:link_to_current_page]
        always_show_anchors = options[:always_show_anchors]

        current_page = paginator.current_page
        window_pages = current_page.window(options[:window_size]).pages
        return if window_pages.length <= 1 unless link_to_current_page
        
        first, last = paginator.first, paginator.last
        
        html = ''
        if always_show_anchors and not (wp_first = window_pages[0]).first?
          html << yield(first.number)
          html << ' ... ' if wp_first.number - first.number > 1
          html << ' '
        end
          
        window_pages.each do |page|
          if current_page == page && !link_to_current_page
            html << page.number.to_s
          else
            html << yield(page.number)
          end
          html << ' '
        end
        
        if always_show_anchors and not (wp_last = window_pages[-1]).last? 
          html << ' ... ' if last.number - wp_last.number > 1
          html << yield(last.number)
        end
        
        html
      end
      
    end # PaginationHelper
  end # Helpers
end # ActionView
