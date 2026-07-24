# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    # = System Testing \Test Adapter
    #
    # Subclass +TestAdapter+ to let a browser tool work with
    # ActionDispatch::ServerSystemTestCase. An adapter hands each test the
    # objects it interacts with the page through -- typically a browser and a
    # page, but it can provide any per-test or per-run resource.
    #
    # Declare each resource as a _helper_. A helper is defined with a block that
    # builds the resource and returns it; a test reads it by calling a method of
    # the same name. Helpers come in two kinds:
    #
    # * A global helper is built at most once per run.
    # * A regular helper is built at most once per test.
    #
    # A helper block declares its dependencies as required keyword arguments.
    # Each dependency resolves to another helper of the same name, or to the
    # running server's +base_url+:
    #
    #     class MyBrowserAdapter < ActionDispatch::SystemTesting::TestAdapter
    #       global_helper :browser do
    #         browser = Browser.launch
    #         on_teardown { browser.close }
    #         browser
    #       end
    #
    #       helper :page do |browser:, base_url:|
    #         page = browser.new_page(base_url: base_url)
    #         on_teardown { page.close }
    #         page
    #       end
    #     end
    #
    # Register the adapter under a name so applications can select it with
    # +testing_with+:
    #
    #     ActionDispatch::SystemTesting::TestAdapters.register(:my_browser, MyBrowserAdapter)
    #
    # Helpers are built lazily the first time a test reads them. Use
    # +on_teardown+ to clean the resource up: the callback runs after the test
    # for a regular helper, or after the run for a global helper.
    class TestAdapter
      # A single helper definition: its name, whether it is global (built once
      # per run) or not (built once per test), and the block that builds its
      # value.
      class Helper < Struct.new(:name, :global, :block, keyword_init: true)
        def global?
          global
        end
      end
      private_constant :Helper

      # Holds the values already resolved for one lifecycle scope -- the whole
      # run for global helpers, a single test for regular helpers -- along with
      # the teardown callbacks those helpers registered.
      class HelperScope # :nodoc:
        attr_reader :teardowns

        def initialize
          @values = {}
          @resolving = []
          @teardowns = []
        end

        def resolved?(name)
          @values.key?(name)
        end

        def value(name)
          @values[name]
        end

        def store(name, value, teardowns)
          @teardowns.concat(teardowns)
          @values[name] = value
        end

        # Marks +name+ as being resolved for the duration of the block, so a
        # helper that depends on itself -- directly or through another helper --
        # raises instead of looping forever.
        def resolving(name)
          if @resolving.include?(name)
            path = (@resolving + [name]).join(" -> ")
            raise ArgumentError, "circular system test helper dependency: #{path}"
          end

          @resolving << name
          begin
            yield
          ensure
            @resolving.pop
          end
        end
      end
      private_constant :HelperScope

      class << self
        # Defines a helper built at most once per test run.
        def global_helper(name, &block)
          register_helper(name, global: true, block: block)
        end

        # Defines a helper built at most once per test.
        def helper(name, &block)
          register_helper(name, global: false, block: block)
        end

        # The helpers this adapter declares, keyed by name.
        def helpers # :nodoc:
          @helpers ||= {}
        end

        # Adapters are leaf classes: they inherit directly from TestAdapter and
        # are not themselves subclassed, so an adapter's helpers are exactly the
        # ones it declares -- there is no definition chain to merge.
        def inherited(subclass)
          super

          unless equal?(TestAdapter)
            raise TypeError, "system test adapters cannot be subclassed; inherit directly from ActionDispatch::SystemTesting::TestAdapter"
          end
        end

        private
          def register_helper(name, global:, block:)
            raise ArgumentError, "a block is required" unless block

            name = name.to_sym

            if block.parameters.any? { |kind, _| kind != :keyreq }
              raise ArgumentError, "system test helper #{name.inspect} must declare its dependencies as required keyword arguments"
            end

            helpers[name] = Helper.new(name: name, global: global, block: block)
          end
      end

      attr_reader :options

      def initialize(**options)
        @options = options.freeze
        @global_scope = HelperScope.new
        @test_scope = HelperScope.new
      end

      # Installs an accessor for every helper on the test case class, so a test
      # can read a helper's value by calling a method of the same name.
      def install(test_case_class)
        test_case_class.include(helper_module_for_install)
      end

      # Discards the previous test's helpers and starts a fresh scope, so each
      # test gets its own set of regular helpers.
      def before_setup
        @test_scope = HelperScope.new
      end

      # Runs the teardown callbacks registered by the current test's helpers.
      def after_teardown
        run_teardowns(@test_scope.teardowns)
      end

      # Runs the teardown callbacks registered by global helpers, at the end of
      # the run.
      def shutdown
        scope = @global_scope
        @global_scope = HelperScope.new
        run_teardowns(scope.teardowns)
      end

      # Returns the value of the helper named +name+, resolving it (and its
      # dependencies) the first time it is read. Called by the accessors that
      # #install adds to the test case, so +name+ is always a declared helper.
      def resolve(name, test_case) # :nodoc:
        resolve_helper(self.class.helpers[name], test_case)
      end

      private
        def helper_module_for_install
          adapter = self

          Module.new do
            adapter.class.helpers.each_key do |name|
              define_method(name) { adapter.resolve(name, self) }
            end
          end
        end

        # Resolves +helper+ in the scope it belongs to: global helpers live for
        # the whole run, regular helpers only for the current test.
        def resolve_helper(helper, test_case)
          scope = helper.global? ? @global_scope : @test_scope
          resolve_in_scope(scope, helper, test_case)
        end

        # Resolves +helper+ within +scope+: returns the value if it was already
        # resolved there, otherwise resolves each dependency, runs the block
        # against the adapter -- so it can call the adapter's support methods and
        # +on_teardown+ directly -- and memoizes the value with its teardowns.
        def resolve_in_scope(scope, helper, test_case)
          return scope.value(helper.name) if scope.resolved?(helper.name)

          scope.resolving(helper.name) do
            dependencies = {}
            helper.block.parameters.each do |_kind, name|
              dependencies[name] = resolve_dependency(helper, name, test_case)
            end

            outer_teardowns = @current_teardowns
            @current_teardowns = []
            begin
              value = instance_exec(**dependencies, &helper.block)
              scope.store(helper.name, value, @current_teardowns)
              value
            rescue
              run_teardowns(@current_teardowns)
              raise
            ensure
              @current_teardowns = outer_teardowns
            end
          end
        end

        # Resolves a single dependency +name+ of +helper+ to another helper, or
        # to the running server's +base_url+.
        def resolve_dependency(helper, name, test_case)
          if (dependency = self.class.helpers[name])
            if helper.global? && !dependency.global?
              raise ArgumentError, "global system test helper cannot depend on test helper #{name.inspect}"
            end

            resolve_helper(dependency, test_case)
          elsif name == :base_url
            test_case.base_url
          else
            raise ArgumentError, "system test helper #{helper.name.inspect} has an unknown dependency #{name.inspect}"
          end
        end

        # Registers a cleanup callback for the helper currently being built.
        # Only meaningful while a helper block runs, so it stays private and is
        # not part of the adapter's public API.
        def on_teardown(&block)
          raise ArgumentError, "a block is required" unless block

          @current_teardowns << block
        end

        def run_teardowns(teardowns)
          first_error = nil

          teardowns.reverse_each do |teardown|
            teardown.call
          rescue => error
            first_error ||= error
          end

          teardowns.clear
          raise first_error if first_error
        end
    end
  end
end
