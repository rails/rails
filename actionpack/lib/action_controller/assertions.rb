require 'test/unit'
require 'test/unit/assertions'
require 'rexml/document'
require File.dirname(__FILE__) + "/vendor/html-scanner/html/document"

module Test #:nodoc:
  module Unit #:nodoc:
    # In addition to these specific assertions, you also have easy access to various collections that the regular test/unit assertions
    # can be used against. These collections are:
    #
    # * assigns: Instance variables assigned in the action that are available for the view.
    # * session: Objects being saved in the session.
    # * flash: The flash objects currently in the session.
    # * cookies: Cookies being sent to the user on this request.
    # 
    # These collections can be used just like any other hash:
    #
    #   assert_not_nil assigns(:person) # makes sure that a @person instance variable was set
    #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
    #   assert flash.empty? # makes sure that there's nothing in the flash
    #
    # For historic reasons, the assigns hash uses string-based keys. So assigns[:person] won't work, but assigns["person"] will. To
    # appease our yearning for symbols, though, an alternative accessor has been deviced using a method call instead of index referencing.
    # So assigns(:person) will work just like assigns["person"], but again, assigns[:person] will not work.
    #
    # On top of the collections, you have the complete url that a given action redirected to available in redirect_to_url.
    #
    # For redirects within the same controller, you can even call follow_redirect and the redirect will be followed, triggering another
    # action call which can then be asserted against.
    #
    # == Manipulating the request collections
    #
    # The collections described above link to the response, so you can test if what the actions were expected to do happened. But
    # sometimes you also want to manipulate these collections in the incoming request. This is really only relevant for sessions
    # and cookies, though. For sessions, you just do:
    #
    #   @request.session[:key] = "value"
    #
    # For cookies, you need to manually create the cookie, like this:
    #
    #   @request.cookies["key"] = CGI::Cookie.new("key", "value")
    #
    # == Testing named routes
    #
    # If you're using named routes, they can be easily tested using the original named routes methods straight in the test case.
    # Example: 
    #
    #  assert_redirected_to page_url(:title => 'foo')
    module Assertions
      # Asserts that the response is one of the following types:
      # 
      # * <tt>:success</tt>: Status code was 200
      # * <tt>:redirect</tt>: Status code was in the 300-399 range
      # * <tt>:missing</tt>: Status code was 404
      # * <tt>:error</tt>:  Status code was in the 500-599 range
      #
      # You can also pass an explicit status code number as the type, like assert_response(501)
      def assert_response(type, message = nil)
        clean_backtrace do
          if [ :success, :missing, :redirect, :error ].include?(type) && @response.send("#{type}?")
            assert_block("") { true } # to count the assertion
          elsif type.is_a?(Fixnum) && @response.response_code == type
            assert_block("") { true } # to count the assertion
          else
            assert_block(build_message(message, "Expected response to be a <?>, but was <?>", type, @response.response_code)) { false }
          end               
        end
      end

      # Assert that the redirection options passed in match those of the redirect called in the latest action. This match can be partial,
      # such that assert_redirected_to(:controller => "weblog") will also match the redirection of 
      # redirect_to(:controller => "weblog", :action => "show") and so on.
      def assert_redirected_to(options = {}, message=nil)
        clean_backtrace do
          assert_response(:redirect, message)

          if options.is_a?(String)
            msg = build_message(message, "expected a redirect to <?>, found one to <?>", options, @response.redirect_url)
            url_regexp = %r{^(\w+://.*?(/|$|\?))(.*)$}
            eurl, epath, url, path = [options, @response.redirect_url].collect do |url|
              u, p = (url_regexp =~ url) ? [$1, $3] : [nil, url]
              [u, (p[0..0] == '/') ? p : '/' + p]
            end.flatten

            assert_equal(eurl, url, msg) if eurl && url
            assert_equal(epath, path, msg) if epath && path 
          else
            @response_diff = options.diff(@response.redirected_to) if options.is_a?(Hash) && @response.redirected_to.is_a?(Hash)
            msg = build_message(message, "response is not a redirection to all of the options supplied (redirection is <?>)#{', difference: <?>' if @response_diff}", 
                                @response.redirected_to || @response.redirect_url, @response_diff)

            assert_block(msg) do
              if options.is_a?(Symbol)
                @response.redirected_to == options
              else
                options.keys.all? do |k|
                  if k == :controller then options[k] == ActionController::Routing.controller_relative_to(@response.redirected_to[k], @controller.class.controller_path)
                  else options[k] == (@response.redirected_to[k].respond_to?(:to_param) ? @response.redirected_to[k].to_param : @response.redirected_to[k] unless @response.redirected_to[k].nil?)
                  end
                end
              end
            end
          end
        end
      end

      # Asserts that the request was rendered with the appropriate template file.
      def assert_template(expected = nil, message=nil)
        clean_backtrace do
          rendered = expected ? @response.rendered_file(!expected.include?('/')) : @response.rendered_file
          msg = build_message(message, "expecting <?> but rendering with <?>", expected, rendered)
          assert_block(msg) do
            if expected.nil?
              !@response.rendered_with_file?
            else
              expected == rendered
            end
          end               
        end
      end

      # Asserts that the routing of the given path was handled correctly and that the parsed options match.
      def assert_recognizes(expected_options, path, extras={}, message=nil)
        clean_backtrace do 
          path = "/#{path}" unless path[0..0] == '/'
          # Load routes.rb if it hasn't been loaded.
          ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 
      
          # Assume given controller
          request = ActionController::TestRequest.new({}, {}, nil)
          request.path = path
          ActionController::Routing::Routes.recognize!(request)
      
          expected_options = expected_options.clone
          extras.each_key { |key| expected_options.delete key } unless extras.nil?
      
          expected_options.stringify_keys!
          msg = build_message(message, "The recognized options <?> did not match <?>", 
              request.path_parameters, expected_options)
          assert_block(msg) { request.path_parameters == expected_options }
        end
      end

      # Asserts that the provided options can be used to generate the provided path.
      def assert_generates(expected_path, options, defaults={}, extras = {}, message=nil)
        clean_backtrace do 
          expected_path = "/#{expected_path}" unless expected_path[0] == ?/
          # Load routes.rb if it hasn't been loaded.
          ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 
      
          generated_path, extra_keys = ActionController::Routing::Routes.generate(options, extras)
          found_extras = options.reject {|k, v| ! extra_keys.include? k}

          msg = build_message(message, "found extras <?>, not <?>", found_extras, extras)
          assert_block(msg) { found_extras == extras }
      
          msg = build_message(message, "The generated path <?> did not match <?>", generated_path, 
              expected_path)
          assert_block(msg) { expected_path == generated_path }
        end
      end

      # Asserts that path and options match both ways; in other words, the URL generated from 
      # options is the same as path, and also that the options recognized from path are the same as options
      def assert_routing(path, options, defaults={}, extras={}, message=nil)
        assert_recognizes(options, path, extras, message)
        
        controller, default_controller = options[:controller], defaults[:controller] 
        if controller && controller.include?(?/) && default_controller && default_controller.include?(?/)
          options[:controller] = "/#{controller}"
        end
         
        assert_generates(path, options, defaults, extras, message)
      end

      # Asserts that there is a tag/node/element in the body of the response
      # that meets all of the given conditions. The +conditions+ parameter must
      # be a hash of any of the following keys (all are optional):
      #
      # * <tt>:tag</tt>: the node type must match the corresponding value
      # * <tt>:attributes</tt>: a hash. The node's attributes must match the
      #   corresponding values in the hash.
      # * <tt>:parent</tt>: a hash. The node's parent must match the
      #   corresponding hash.
      # * <tt>:child</tt>: a hash. At least one of the node's immediate children
      #   must meet the criteria described by the hash.
      # * <tt>:ancestor</tt>: a hash. At least one of the node's ancestors must
      #   meet the criteria described by the hash.
      # * <tt>:descendant</tt>: a hash. At least one of the node's descendants
      #   must meet the criteria described by the hash.
      # * <tt>:sibling</tt>: a hash. At least one of the node's siblings must
      #   meet the criteria described by the hash.
      # * <tt>:after</tt>: a hash. The node must be after any sibling meeting
      #   the criteria described by the hash, and at least one sibling must match.
      # * <tt>:before</tt>: a hash. The node must be before any sibling meeting
      #   the criteria described by the hash, and at least one sibling must match.
      # * <tt>:children</tt>: a hash, for counting children of a node. Accepts
      #   the keys:
      #   * <tt>:count</tt>: either a number or a range which must equal (or
      #     include) the number of children that match.
      #   * <tt>:less_than</tt>: the number of matching children must be less
      #     than this number.
      #   * <tt>:greater_than</tt>: the number of matching children must be
      #     greater than this number.
      #   * <tt>:only</tt>: another hash consisting of the keys to use
      #     to match on the children, and only matching children will be
      #     counted.
      # * <tt>:content</tt>: the textual content of the node must match the
      #     given value. This will not match HTML tags in the body of a
      #     tag--only text.
      #
      # Conditions are matched using the following algorithm:
      #
      # * if the condition is a string, it must be a substring of the value.
      # * if the condition is a regexp, it must match the value.
      # * if the condition is a number, the value must match number.to_s.
      # * if the condition is +true+, the value must not be +nil+.
      # * if the condition is +false+ or +nil+, the value must be +nil+.
      #
      # Usage:
      #
      #   # assert that there is a "span" tag
      #   assert_tag :tag => "span"
      #
      #   # assert that there is a "span" tag with id="x"
      #   assert_tag :tag => "span", :attributes => { :id => "x" }
      #
      #   # assert that there is a "span" tag using the short-hand
      #   assert_tag :span
      #
      #   # assert that there is a "span" tag with id="x" using the short-hand
      #   assert_tag :span, :attributes => { :id => "x" }
      #
      #   # assert that there is a "span" inside of a "div"
      #   assert_tag :tag => "span", :parent => { :tag => "div" }
      #
      #   # assert that there is a "span" somewhere inside a table
      #   assert_tag :tag => "span", :ancestor => { :tag => "table" }
      #
      #   # assert that there is a "span" with at least one "em" child
      #   assert_tag :tag => "span", :child => { :tag => "em" }
      #
      #   # assert that there is a "span" containing a (possibly nested)
      #   # "strong" tag.
      #   assert_tag :tag => "span", :descendant => { :tag => "strong" }
      #
      #   # assert that there is a "span" containing between 2 and 4 "em" tags
      #   # as immediate children
      #   assert_tag :tag => "span",
      #              :children => { :count => 2..4, :only => { :tag => "em" } } 
      #
      #   # get funky: assert that there is a "div", with an "ul" ancestor
      #   # and an "li" parent (with "class" = "enum"), and containing a 
      #   # "span" descendant that contains text matching /hello world/
      #   assert_tag :tag => "div",
      #              :ancestor => { :tag => "ul" },
      #              :parent => { :tag => "li",
      #                           :attributes => { :class => "enum" } },
      #              :descendant => { :tag => "span",
      #                               :child => /hello world/ }
      #
      # <strong>Please note</strong: #assert_tag and #assert_no_tag only work
      # with well-formed XHTML. They recognize a few tags as implicitly self-closing
      # (like br and hr and such) but will not work correctly with tags
      # that allow optional closing tags (p, li, td). <em>You must explicitly
      # close all of your tags to use these assertions.</em>
      def assert_tag(*opts)
        clean_backtrace do
          opts = opts.size > 1 ? opts.last.merge({ :tag => opts.first.to_s }) : opts.first
          tag = find_tag(opts)
          assert tag, "expected tag, but no tag found matching #{opts.inspect} in:\n#{@response.body.inspect}"
        end
      end
      
      # Identical to #assert_tag, but asserts that a matching tag does _not_
      # exist. (See #assert_tag for a full discussion of the syntax.)
      def assert_no_tag(*opts)
        clean_backtrace do
          opts = opts.size > 1 ? opts.last.merge({ :tag => opts.first.to_s }) : opts.first
          tag = find_tag(opts)
          assert !tag, "expected no tag, but found tag matching #{opts.inspect} in:\n#{@response.body.inspect}"
        end
      end

      # test 2 html strings to be equivalent, i.e. identical up to reordering of attributes
      def assert_dom_equal(expected, actual, message="")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom = HTML::Document.new(actual).root
          full_message = build_message(message, "<?> expected to be == to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom == actual_dom }
        end
      end
      
      # negated form of +assert_dom_equivalent+
      def assert_dom_not_equal(expected, actual, message="")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom = HTML::Document.new(actual).root
          full_message = build_message(message, "<?> expected to be != to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom != actual_dom }
        end
      end

      # ensures that the passed record is valid by active record standards. returns the error messages if not
      def assert_valid(record)
        clean_backtrace do
          assert record.valid?, record.errors.full_messages.join("\n")
        end
      end             
      
      def clean_backtrace(&block)
        yield
      rescue AssertionFailedError => e         
        path = File.expand_path(__FILE__)
        raise AssertionFailedError, e.message, e.backtrace.reject { |line| File.expand_path(line) =~ /#{path}/ }
      end
    end
  end
end
