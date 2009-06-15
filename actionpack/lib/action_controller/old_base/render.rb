require 'action_controller/abstract/renderer'

module ActionController
  DEFAULT_RENDER_STATUS_CODE = "200 OK"
  
  class DoubleRenderError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end
  
  module Renderer
    
    protected
    # Renders the content that will be returned to the browser as the response body.
    #
    # === Rendering an action
    #
    # Action rendering is the most common form and the type used automatically by Action Controller when nothing else is
    # specified. By default, actions are rendered within the current layout (if one exists).
    #
    #   # Renders the template for the action "goal" within the current controller
    #   render :action => "goal"
    #
    #   # Renders the template for the action "short_goal" within the current controller,
    #   # but without the current active layout
    #   render :action => "short_goal", :layout => false
    #
    #   # Renders the template for the action "long_goal" within the current controller,
    #   # but with a custom layout
    #   render :action => "long_goal", :layout => "spectacular"
    #
    # === Rendering partials
    #
    # Partial rendering in a controller is most commonly used together with Ajax calls that only update one or a few elements on a page
    # without reloading. Rendering of partials from the controller makes it possible to use the same partial template in
    # both the full-page rendering (by calling it from within the template) and when sub-page updates happen (from the
    # controller action responding to Ajax calls). By default, the current layout is not used.
    #
    #   # Renders the same partial with a local variable.
    #   render :partial => "person", :locals => { :name => "david" }
    #
    #   # Renders the partial, making @new_person available through
    #   # the local variable 'person'
    #   render :partial => "person", :object => @new_person
    #
    #   # Renders a collection of the same partial by making each element
    #   # of @winners available through the local variable "person" as it
    #   # builds the complete response.
    #   render :partial => "person", :collection => @winners
    #
    #   # Renders a collection of partials but with a custom local variable name
    #   render :partial => "admin_person", :collection => @winners, :as => :person
    #
    #   # Renders the same collection of partials, but also renders the
    #   # person_divider partial between each person partial.
    #   render :partial => "person", :collection => @winners, :spacer_template => "person_divider"
    #
    #   # Renders a collection of partials located in a view subfolder
    #   # outside of our current controller.  In this example we will be
    #   # rendering app/views/shared/_note.r(html|xml)  Inside the partial
    #   # each element of @new_notes is available as the local var "note".
    #   render :partial => "shared/note", :collection => @new_notes
    #
    #   # Renders the partial with a status code of 500 (internal error).
    #   render :partial => "broken", :status => 500
    #
    # Note that the partial filename must also be a valid Ruby variable name,
    # so e.g. 2005 and register-user are invalid.
    #
    #
    # == Automatic etagging
    #
    # Rendering will automatically insert the etag header on 200 OK responses. The etag is calculated using MD5 of the
    # response body. If a request comes in that has a matching etag, the response will be changed to a 304 Not Modified
    # and the response body will be set to an empty string. No etag header will be inserted if it's already set.
    #
    # === Rendering a template
    #
    # Template rendering works just like action rendering except that it takes a path relative to the template root.
    # The current layout is automatically applied.
    #
    #   # Renders the template located in [TEMPLATE_ROOT]/weblog/show.r(html|xml) (in Rails, app/views/weblog/show.erb)
    #   render :template => "weblog/show"
    #
    #   # Renders the template with a local variable
    #   render :template => "weblog/show", :locals => {:customer => Customer.new}
    #
    # === Rendering a file
    #
    # File rendering works just like action rendering except that it takes a filesystem path. By default, the path
    # is assumed to be absolute, and the current layout is not applied.
    #
    #   # Renders the template located at the absolute filesystem path
    #   render :file => "/path/to/some/template.erb"
    #   render :file => "c:/path/to/some/template.erb"
    #
    #   # Renders a template within the current layout, and with a 404 status code
    #   render :file => "/path/to/some/template.erb", :layout => true, :status => 404
    #   render :file => "c:/path/to/some/template.erb", :layout => true, :status => 404
    #
    # === Rendering text
    #
    # Rendering of text is usually used for tests or for rendering prepared content, such as a cache. By default, text
    # rendering is not done within the active layout.
    #
    #   # Renders the clear text "hello world" with status code 200
    #   render :text => "hello world!"
    #
    #   # Renders the clear text "Explosion!"  with status code 500
    #   render :text => "Explosion!", :status => 500
    #
    #   # Renders the clear text "Hi there!" within the current active layout (if one exists)
    #   render :text => "Hi there!", :layout => true
    #
    #   # Renders the clear text "Hi there!" within the layout
    #   # placed in "app/views/layouts/special.r(html|xml)"
    #   render :text => "Hi there!", :layout => "special"
    #
    # The <tt>:text</tt> option can also accept a Proc object, which can be used to manually control the page generation. This should
    # generally be avoided, as it violates the separation between code and content, and because almost everything that can be
    # done with this method can also be done more cleanly using one of the other rendering methods, most notably templates.
    #
    #   # Renders "Hello from code!"
    #   render :text => proc { |response, output| output.write("Hello from code!") }
    #
    # === Rendering XML
    #
    # Rendering XML sets the content type to application/xml.
    #
    #   # Renders '<name>David</name>'
    #   render :xml => {:name => "David"}.to_xml
    #
    # It's not necessary to call <tt>to_xml</tt> on the object you want to render, since <tt>render</tt> will
    # automatically do that for you:
    #
    #   # Also renders '<name>David</name>'
    #   render :xml => {:name => "David"}
    #
    # === Rendering JSON
    #
    # Rendering JSON sets the content type to application/json and optionally wraps the JSON in a callback. It is expected
    # that the response will be parsed (or eval'd) for use as a data structure.
    #
    #   # Renders '{"name": "David"}'
    #   render :json => {:name => "David"}.to_json
    #
    # It's not necessary to call <tt>to_json</tt> on the object you want to render, since <tt>render</tt> will
    # automatically do that for you:
    #
    #   # Also renders '{"name": "David"}'
    #   render :json => {:name => "David"}
    #
    # Sometimes the result isn't handled directly by a script (such as when the request comes from a SCRIPT tag),
    # so the <tt>:callback</tt> option is provided for these cases.
    #
    #   # Renders 'show({"name": "David"})'
    #   render :json => {:name => "David"}.to_json, :callback => 'show'
    #
    # === Rendering an inline template
    #
    # Rendering of an inline template works as a cross between text and action rendering where the source for the template
    # is supplied inline, like text, but its interpreted with ERb or Builder, like action. By default, ERb is used for rendering
    # and the current layout is not used.
    #
    #   # Renders "hello, hello, hello, again"
    #   render :inline => "<%= 'hello, ' * 3 + 'again' %>"
    #
    #   # Renders "<p>Good seeing you!</p>" using Builder
    #   render :inline => "xml.p { 'Good seeing you!' }", :type => :builder
    #
    #   # Renders "hello david"
    #   render :inline => "<%= 'hello ' + name %>", :locals => { :name => "david" }
    #
    # === Rendering inline JavaScriptGenerator page updates
    #
    # In addition to rendering JavaScriptGenerator page updates with Ajax in RJS templates (see ActionView::Base for details),
    # you can also pass the <tt>:update</tt> parameter to +render+, along with a block, to render page updates inline.
    #
    #   render :update do |page|
    #     page.replace_html  'user_list', :partial => 'user', :collection => @users
    #     page.visual_effect :highlight, 'user_list'
    #   end
    #
    # === Rendering vanilla JavaScript
    #
    # In addition to using RJS with render :update, you can also just render vanilla JavaScript with :js.
    #
    #   # Renders "alert('hello')" and sets the mime type to text/javascript
    #   render :js => "alert('hello')"
    #
    # === Rendering with status and location headers
    # All renders take the <tt>:status</tt> and <tt>:location</tt> options and turn them into headers. They can even be used together:
    #
    #   render :xml => post.to_xml, :status => :created, :location => post_url(post)
    def render(options = nil, extra_options = {}, &block) #:doc:
      raise DoubleRenderError, "Can only render or redirect once per action" if performed?

      options = { :layout => true } if options.nil?

      # This handles render "string", render :symbol, and render object
      # render string and symbol are handled by render_for_name
      # render object becomes render :partial => object
      unless options.is_a?(Hash)
        if options.is_a?(String) || options.is_a?(Symbol)
          original, options = options, extra_options
        else
          extra_options[:partial], options = options, extra_options
        end
      end
      
      layout_name = options.delete(:layout)

      _process_options(options)
      
      if block_given?
        @template.send(:_evaluate_assigns_and_ivars)

        generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(@template, &block)
        response.content_type = Mime::JS
        return render_for_text(generator.to_s)
      end
      
      if original
        return render_for_name(original, layout_name, options) unless block_given?
      end
      
      if options.key?(:text)
        return render_for_text(@template._render_text(options[:text], 
          _pick_layout(layout_name), options))
      end

      file, template = options.values_at(:file, :template)
      if file || template
        file = template.sub(/^\//, '') if template
        return render_for_file(file, [layout_name, !!template], options)
      end
      
      if action_option = options[:action]
        return render_for_action(action_option, [layout_name, true], options)
      end
      
      if inline = options[:inline]
        render_for_text(@template._render_inline(inline, _pick_layout(layout_name), options))

      elsif xml = options[:xml]
        response.content_type ||= Mime::XML
        render_for_text(xml.respond_to?(:to_xml) ? xml.to_xml : xml)

      elsif js = options[:js]
        response.content_type ||= Mime::JS
        render_for_text(js)

      elsif options.include?(:json)
        json = options[:json]
        json = ActiveSupport::JSON.encode(json) unless json.respond_to?(:to_str)
        json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
        response.content_type ||= Mime::JSON
        render_for_text(json)

      elsif partial = options[:partial]
        if partial == true
          parts = [action_name_base, formats, controller_name, true]
        elsif partial.is_a?(String)
          parts = partial_parts(partial, options)
        else
          return render_for_text(@template._render_partial(options))
        end
        
        render_for_parts(parts, layout_name, options)
        
      elsif options[:nothing]
        render_for_text(nil)

      else
        render_for_parts([action_name, formats, controller_path], layout_name, options)
      end
    end

    def partial_parts(name, options)
      segments = name.split("/")
      parts = segments.pop.split(".")

      case parts.size
      when 1
        parts
      when 2, 3
        extension = parts.delete_at(1).to_sym
        if formats.include?(extension)
          self.formats.replace [extension]
        end
        parts.pop if parts.size == 2
      end

      path = parts.join(".")
      prefix = segments[0..-1].join("/")
      prefix = prefix.blank? ? controller_path : prefix
      parts = [path, formats, prefix]
      parts.push options[:object] || true
    end

    def formats
      @_request.formats.map {|f| f.symbol }.compact
    end

    def action_name_base(name = action_name)
      (name.is_a?(String) ? name.sub(/^#{controller_path}\//, '') : name).to_s
    end

    # Same rules as <tt>render</tt>, but returns a Rack-compatible body
    # instead of sending the response.
    def render_to_body(options = nil, &block) #:doc:
      render(options, &block)
      response.body
    ensure
      response.content_type = nil
      erase_render_results
      reset_variables_added_to_assigns
    end

    def render_to_string(options = {})
      AbstractController::Renderer.body_to_s(render_to_body(options))
    end

    # Clears the rendered results, allowing for another render to be performed.
    def erase_render_results #:nodoc:
      response.body = []
      @performed_render = false
    end

    # Erase both render and redirect results
    def erase_results #:nodoc:
      erase_render_results
      erase_redirect_results
    end
    
    # Return a response that has no content (merely headers). The options
    # argument is interpreted to be a hash of header names and values.
    # This allows you to easily return a response that consists only of
    # significant headers:
    #
    #   head :created, :location => person_path(@person)
    #
    # It can also be used to return exceptional conditions:
    #
    #   return head(:method_not_allowed) unless request.post?
    #   return head(:bad_request) unless valid_request?
    #   render
    def head(*args)
      if args.length > 2
        raise ArgumentError, "too many arguments to head"
      elsif args.empty?
        raise ArgumentError, "too few arguments to head"
      end
      options = args.extract_options!
      status = interpret_status(args.shift || options.delete(:status) || :ok)

      options.each do |key, value|
        headers[key.to_s.dasherize.split(/-/).map { |v| v.capitalize }.join("-")] = value.to_s
      end

      render :nothing => true, :status => status
    end
    
    private
    def render_for_name(name, layout, options)
      case name.to_s.index('/')
      when 0
        render_for_file(name, layout, options)
      when nil
        render_for_action(name, layout, options)
      else
        render_for_file(name.sub(/^\//, ''), [layout, true], options)
      end
    end

    # ==== Arguments
    # parts<Array[String, Array[Symbol*], String, Boolean]>::
    #     Example: ["show", [:html, :xml], "users", false]
    def render_for_parts(parts, layout_details, options = {})
      parts[1] = {:formats => parts[1], :locales => [I18n.locale]}
      
      tmp = view_paths.find_by_parts(*parts)
      
      layout = _pick_layout(*layout_details) unless 
        self.class.exempt_from_layout.include?(tmp.handler)
      
      render_for_text(
        @template._render_template_with_layout(tmp, layout, options, parts[3]))
    end

    def render_for_file(file, layout, options)
      render_for_parts([file, [request.format.to_sym]], layout, options)
    end
    
    def render_for_action(name, layout, options)
      parts = [action_name_base(name), formats, controller_name]
      render_for_parts(parts, layout, options)
    end
  end
end
