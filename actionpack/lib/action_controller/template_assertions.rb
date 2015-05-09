module ActionController
  module TemplateAssertions
    extend ActiveSupport::Concern

    included do
      setup :setup_subscriptions
      teardown :teardown_subscriptions
    end

    RENDER_TEMPLATE_INSTANCE_VARIABLES = %w{partials templates layouts files}.freeze

    def setup_subscriptions
      RENDER_TEMPLATE_INSTANCE_VARIABLES.each do |instance_variable|
        instance_variable_set("@_#{instance_variable}", Hash.new(0))
      end

      @_subscribers = []

      @_subscribers << ActiveSupport::Notifications.subscribe("render_template.action_view") do |_name, _start, _finish, _id, payload|
        path = payload[:layout]
        if path
          @_layouts[path] += 1
          if path =~ /^layouts\/(.*)/
            @_layouts[$1] += 1
          end
        end
      end

      @_subscribers << ActiveSupport::Notifications.subscribe("!render_template.action_view") do |_name, _start, _finish, _id, payload|
        if virtual_path = payload[:virtual_path]
          partial = virtual_path =~ /^.*\/_[^\/]*$/

          if partial
            @_partials[virtual_path] += 1
            @_partials[virtual_path.split("/").last] += 1
          end

          @_templates[virtual_path] += 1
        else
          path = payload[:identifier]
          if path
            @_files[path] += 1
            @_files[path.split("/").last] += 1
          end
        end
      end
    end

    def teardown_subscriptions
      @_subscribers.each do |subscriber|
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end

    def process(*args)
      reset_template_assertion
      super
    end

    def reset_template_assertion
      RENDER_TEMPLATE_INSTANCE_VARIABLES.each do |instance_variable|
        ivar_name = "@_#{instance_variable}"
        if instance_variable_defined?(ivar_name)
          instance_variable_get(ivar_name).clear
        end
      end
    end

    # Asserts that the request was rendered with the appropriate template file or partials.
    #
    #   # assert that the "new" view template was rendered
    #   assert_template "new"
    #
    #   # assert that the exact template "admin/posts/new" was rendered
    #   assert_template %r{\Aadmin/posts/new\Z}
    #
    #   # assert that the layout 'admin' was rendered
    #   assert_template layout: 'admin'
    #   assert_template layout: 'layouts/admin'
    #   assert_template layout: :admin
    #
    #   # assert that no layout was rendered
    #   assert_template layout: nil
    #   assert_template layout: false
    #
    #   # assert that the "_customer" partial was rendered twice
    #   assert_template partial: '_customer', count: 2
    #
    #   # assert that no partials were rendered
    #   assert_template partial: false
    #
    #   # assert that a file was rendered
    #   assert_template file: "README.rdoc"
    #
    #   # assert that no file was rendered
    #   assert_template file: nil
    #   assert_template file: false
    #
    # In a view test case, you can also assert that specific locals are passed
    # to partials:
    #
    #   # assert that the "_customer" partial was rendered with a specific object
    #   assert_template partial: '_customer', locals: { customer: @customer }
    def assert_template(options = {}, message = nil)
      # Force body to be read in case the template is being streamed.
      response.body

      case options
      when NilClass, Regexp, String, Symbol
        options = options.to_s if Symbol === options
        rendered = @_templates
        msg = message || sprintf("expecting <%s> but rendering with <%s>",
                options.inspect, rendered.keys)
        matches_template =
          case options
          when String
            !options.empty? && rendered.any? do |t, num|
              options_splited = options.split(File::SEPARATOR)
              t_splited = t.split(File::SEPARATOR)
              t_splited.last(options_splited.size) == options_splited
            end
          when Regexp
            rendered.any? { |t,num| t.match(options) }
          when NilClass
            rendered.blank?
          end
        assert matches_template, msg
      when Hash
        options.assert_valid_keys(:layout, :partial, :locals, :count, :file)

        if options.key?(:layout)
          expected_layout = options[:layout]
          msg = message || sprintf("expecting layout <%s> but action rendered <%s>",
                  expected_layout, @_layouts.keys)

          case expected_layout
          when String, Symbol
            assert_includes @_layouts.keys, expected_layout.to_s, msg
          when Regexp
            assert(@_layouts.keys.any? {|l| l =~ expected_layout }, msg)
          when nil, false
            assert(@_layouts.empty?, msg)
          else
            raise ArgumentError, "assert_template only accepts a String, Symbol, Regexp, nil or false for :layout"
          end
        end

        if options[:file]
          assert_includes @_files.keys, options[:file]
        elsif options.key?(:file)
          assert @_files.blank?, "expected no files but #{@_files.keys} was rendered"
        end

        if expected_partial = options[:partial]
          if expected_locals = options[:locals]
            if defined?(@_rendered_views)
              view = expected_partial.to_s.sub(/^_/, '').sub(/\/_(?=[^\/]+\z)/, '/')

              partial_was_not_rendered_msg = "expected %s to be rendered but it was not." % view
              assert_includes @_rendered_views.rendered_views, view, partial_was_not_rendered_msg

              msg = 'expecting %s to be rendered with %s but was with %s' % [expected_partial,
                                                                             expected_locals,
                                                                             @_rendered_views.locals_for(view)]
              assert(@_rendered_views.view_rendered?(view, options[:locals]), msg)
            else
              warn "the :locals option to #assert_template is only supported in a ActionView::TestCase"
            end
          elsif expected_count = options[:count]
            actual_count = @_partials[expected_partial]
            msg = message || sprintf("expecting %s to be rendered %s time(s) but rendered %s time(s)",
                     expected_partial, expected_count, actual_count)
            assert(actual_count == expected_count.to_i, msg)
          else
            msg = message || sprintf("expecting partial <%s> but action rendered <%s>",
                    options[:partial], @_partials.keys)
            assert_includes @_partials, expected_partial, msg
          end
        elsif options.key?(:partial)
          assert @_partials.empty?,
            "Expected no partials to be rendered"
        end
      else
        raise ArgumentError, "assert_template only accepts a String, Symbol, Hash, Regexp, or nil"
      end
    end
  end
end
