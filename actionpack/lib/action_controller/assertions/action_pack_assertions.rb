require 'test/unit'
require 'test/unit/assertions'
require 'rexml/document'

module Test #:nodoc:
  module Unit #:nodoc:
    # Adds a wealth of assertions to do functional testing of Action Controllers.
    module Assertions
      # -- basic assertions ---------------------------------------------------
      
      # ensure that the web request has been serviced correctly
      def assert_success(message=nil)
        response = acquire_assertion_target
        if response.success?
          # to count the assertion
          assert_block("") { true }
        else
          if response.redirect?
            msg = build_message(message, "Response unexpectedly redirect to <?>", response.redirect_url)
          else
            msg = build_message(message, "unsuccessful request (response code = <?>)", 
                response.response_code)
          end
          assert_block(msg) { false }
        end
      end

      # ensure the request was rendered with the appropriate template file
      def assert_rendered_file(expected=nil, message=nil)
        response = acquire_assertion_target
        rendered = expected ? response.rendered_file(!expected.include?('/')) : response.rendered_file
        msg = build_message(message, "expecting <?> but rendering with <?>", expected, rendered)
        assert_block(msg) do
          if expected.nil?
            response.rendered_with_file?
          else
            expected == rendered
          end
        end
      end
      
      # -- session assertions -------------------------------------------------

      # ensure that the session has an object with the specified name
      def assert_session_has(key=nil, message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is not in the session <?>", key, response.session)
        assert_block(msg) { response.has_session_object?(key) }
      end

      # ensure that the session has no object with the specified name
      def assert_session_has_no(key=nil, message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is in the session <?>", key, response.session)
        assert_block(msg) { !response.has_session_object?(key) }
      end
      
      def assert_session_equal(expected = nil, key = nil, message = nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> expected in session['?'] but was <?>", expected, key, response.session[key])
        assert_block(msg) { expected == response.session[key] }
      end

      # -- cookie assertions ---------------------------------------------------

      def assert_cookie_equal(expected = nil, key = nil, message = nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> expected in cookies['?'] but was <?>", expected, key, response.cookies[key.to_s].first)
        assert_block(msg) { expected == response.cookies[key.to_s].first }
      end
      
      # -- flash assertions ---------------------------------------------------

      # ensure that the flash has an object with the specified name
      def assert_flash_has(key=nil, message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is not in the flash <?>", key, response.flash)
        assert_block(msg) { response.has_flash_object?(key) }
      end

      # ensure that the flash has no object with the specified name
      def assert_flash_has_no(key=nil, message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is in the flash <?>", key, response.flash)
        assert_block(msg) { !response.has_flash_object?(key) }
      end

      # ensure the flash exists
      def assert_flash_exists(message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "the flash does not exist <?>", response.session['flash'] )
        assert_block(msg) { response.has_flash? }
      end

      # ensure the flash does not exist
      def assert_flash_not_exists(message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "the flash exists <?>", response.flash)
        assert_block(msg) { !response.has_flash? }
      end
      
      # ensure the flash is empty but existant
      def assert_flash_empty(message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "the flash is not empty <?>", response.flash)
        assert_block(msg) { !response.has_flash_with_contents? }
      end

      # ensure the flash is not empty
      def assert_flash_not_empty(message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "the flash is empty")
        assert_block(msg) { response.has_flash_with_contents? }
      end
      
      def assert_flash_equal(expected = nil, key = nil, message = nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> expected in flash['?'] but was <?>", expected, key, response.flash[key])
        assert_block(msg) { expected == response.flash[key] }
      end
      
      # -- redirection assertions ---------------------------------------------

      # ensure we have be redirected
      def assert_redirect(message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "response is not a redirection (response code is <?>)", response.response_code)
        assert_block(msg) { response.redirect? }
      end

      def assert_redirected_to(options = {}, message=nil)
        assert_redirect(message)
        response = acquire_assertion_target

        msg = build_message(message, "response is not a redirection to all of the options supplied (redirection is <?>)", response.redirected_to)
        assert_block(msg) do
          if options.is_a?(Symbol)
            response.redirected_to == options
          else
            options.keys.all? { |k| options[k] == response.redirected_to[k] }
          end
        end
      end

      # ensure our redirection url is an exact match
      def assert_redirect_url(url=nil, message=nil)
        assert_redirect(message)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is not the redirected location <?>", url, response.redirect_url)
        assert_block(msg) { response.redirect_url == url }
      end

      # ensure our redirection url matches a pattern
      def assert_redirect_url_match(pattern=nil, message=nil)
        assert_redirect(message)
        response = acquire_assertion_target
        msg = build_message(message, "<?> was not found in the location: <?>", pattern, response.redirect_url)
        assert_block(msg) { response.redirect_url_match?(pattern) }
      end

      # -- template assertions ------------------------------------------------

      # ensure that a template object with the given name exists
      def assert_template_has(key=nil, message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is not a template object", key )
        assert_block(msg) { response.has_template_object?(key) }
      end

      # ensure that a template object with the given name does not exist
      def assert_template_has_no(key=nil,message=nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> is a template object <?>", key, response.template_objects[key])
        assert_block(msg) { !response.has_template_object?(key) }
      end

      # ensures that the object assigned to the template on +key+ is equal to +expected+ object.
      def assert_assigned_equal(expected = nil, key = nil, message = nil)
        response = acquire_assertion_target
        msg = build_message(message, "<?> expected in assigns['?'] but was <?>", expected, key, response.template.assigns[key.to_s])
        assert_block(msg) { expected == response.template.assigns[key.to_s] }
      end

      # Asserts that the template returns the +expected+ string or array based on the XPath +expression+.
      # This will only work if the template rendered a valid XML document.
      def assert_template_xpath_match(expression=nil, expected=nil, message=nil)
        response = acquire_assertion_target
        xml, matches = REXML::Document.new(response.body), []
        xml.elements.each(expression) { |e| matches << e.text }
        matches = matches.first if matches.length < 2

        msg = build_message(message, "<?> found <?>, not <?>", expression, matches, expected)
        assert_block(msg) { matches == expected }
      end
      
      # -- helper functions ---------------------------------------------------
       
      # get the TestResponse object that these assertions depend upon 
      def acquire_assertion_target
        target = ActionController::TestResponse.assertion_target
        assert_block( "Unable to acquire the TestResponse.assertion_target.  Please set this before calling this assertion." ) { !target.nil? }
        target
      end
      
    end # Assertions
  end # Unit
end # Test
