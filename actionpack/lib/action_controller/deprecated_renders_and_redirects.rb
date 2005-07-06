module ActionController
  class Base
    protected
      # Works like render, but instead of requiring a full template name, you can get by with specifying the action name. So calling
      # <tt>render_action "show_many"</tt> in WeblogController#display will render "#{template_root}/weblog/show_many.rhtml" or 
      # "#{template_root}/weblog/show_many.rxml".
      def render_action(action_name, status = nil)
        render :action => action_name, :status => status
      end

      # Works like render, but disregards the template_root and requires a full path to the template that needs to be rendered. Can be
      # used like <tt>render_file "/Users/david/Code/Ruby/template"</tt> to render "/Users/david/Code/Ruby/template.rhtml" or
      # "/Users/david/Code/Ruby/template.rxml".
      def render_file(template_path, status = nil, use_full_path = false)
        render :file => template_path, :status => status, :use_full_path => use_full_path
      end

      # Renders the +template+ string, which is useful for rendering short templates you don't want to bother having a file for. So
      # you'd call <tt>render_template "Hello, <%= @user.name %>"</tt> to greet the current user. Or if you want to render as Builder
      # template, you could do <tt>render_template "xml.h1 @user.name", nil, "rxml"</tt>.
      def render_template(template, status = nil, type = "rhtml")
        render :inline => template, :status => status, :type => type
      end

      # Renders the +text+ string without parsing it through any template engine. Useful for rendering static information as it's
      # considerably faster than rendering through the template engine.
      # Use block for response body if provided (useful for deferred rendering or streaming output).
      def render_text(text = nil, status = nil)
        render :text => text, :status => status
      end

      # Renders an empty response that can be used when the request is only interested in triggering an effect. Do note that good
      # HTTP manners mandate that you don't use GET requests to trigger data changes.
      def render_nothing(status = nil)
        render :nothing => true, :status => status
      end

      # Renders the partial specified by <tt>partial_path</tt>, which by default is the name of the action itself. Example:
      #
      #   class WeblogController < ActionController::Base
      #     def show
      #       render_partial # renders "weblog/_show.r(xml|html)"
      #     end
      #   end
      def render_partial(partial_path = default_template_name, object = nil, local_assigns = {})
        render :partial => partial_path, :object => object, :locals => local_assigns
      end

      # Renders a collection of partials using <tt>partial_name</tt> to iterate over the +collection+.
      def render_partial_collection(partial_name, collection, partial_spacer_template = nil, local_assigns = {})
        render :partial => partial_name, :collection => collection, :spacer_template => partial_spacer_template, :locals => local_assigns
      end

      def render_with_layout(template_name = default_template_name, status = nil, layout = nil)
        render :template => template_name, :status => status, :layout => layout
      end

      def render_without_layout(template_name = default_template_name, status = nil)
        render :template => template_name, :status => status, :layout => false
      end


      # Deprecated in favor of calling redirect_to directly with the path.
      def redirect_to_path(path)
        redirect_to(path)
      end

      # Deprecated in favor of calling redirect_to directly with the url. If the resource has moved permanently, it's possible to pass
      # true as the second parameter and the browser will get "301 Moved Permanently" instead of "302 Found". This can also be done through
      # just setting the headers["Status"] to "301 Moved Permanently" before using the redirect_to.
      def redirect_to_url(url, permanently = false)
        headers["Status"] = "301 Moved Permanently" if permanently
        redirect_to(url)
      end
  end
end