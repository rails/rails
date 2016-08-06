require "abstract_unit"

module AbstractController
  module Testing
    class UrlForTest < ActionController::TestCase
      class W
        include ActionDispatch::Routing::RouteSet.new.tap { |r|
          r.draw {
            ActiveSupport::Deprecation.silence {
              get ":controller(/:action(/:id(.:format)))"
            }
          }
        }.url_helpers
      end

      def teardown
        W.default_url_options.clear
      end

      def test_nested_optional
        klass = Class.new {
          include ActionDispatch::Routing::RouteSet.new.tap { |r|
            r.draw {
              get "/foo/(:bar/(:baz))/:zot", as: "fun",
                                             controller: :articles,
                                             action: :index
            }
          }.url_helpers
          self.default_url_options[:host] = "example.com"
        }

        path = klass.new.fun_path(controller: :articles,
                                   baz: "baz",
                                   zot: "zot")
        # :bar key isn't provided
        assert_equal "/foo/zot", path
      end

      def add_host!(app = W)
        app.default_url_options[:host] = "www.basecamphq.com"
      end

      def add_port!
        W.default_url_options[:port] = 3000
      end

      def add_numeric_host!
        W.default_url_options[:host] = "127.0.0.1"
      end

      def test_exception_is_thrown_without_host
        assert_raise ArgumentError do
          W.new.url_for controller: "c", action: "a", id: "i"
        end
      end

      def test_anchor
        assert_equal("/c/a#anchor",
          W.new.url_for(only_path: true, controller: "c", action: "a", anchor: "anchor")
        )
      end

      def test_nil_anchor
        assert_equal(
          "/c/a",
          W.new.url_for(only_path: true, controller: "c", action: "a", anchor: nil)
        )
      end

      def test_false_anchor
        assert_equal(
          "/c/a",
          W.new.url_for(only_path: true, controller: "c", action: "a", anchor: false)
        )
      end

      def test_anchor_should_call_to_param
        assert_equal("/c/a#anchor",
          W.new.url_for(only_path: true, controller: "c", action: "a", anchor: Struct.new(:to_param).new("anchor"))
        )
      end

      def test_anchor_should_escape_unsafe_pchar
        assert_equal("/c/a#%23anchor",
          W.new.url_for(only_path: true, controller: "c", action: "a", anchor: Struct.new(:to_param).new("#anchor"))
        )
      end

      def test_anchor_should_not_escape_safe_pchar
        assert_equal("/c/a#name=user&email=user@domain.com",
          W.new.url_for(only_path: true, controller: "c", action: "a", anchor: Struct.new(:to_param).new("name=user&email=user@domain.com"))
        )
      end

      def test_default_host
        add_host!
        assert_equal("http://www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i")
        )
      end

      def test_host_may_be_overridden
        add_host!
        assert_equal("http://37signals.basecamphq.com/c/a/i",
          W.new.url_for(host: "37signals.basecamphq.com", controller: "c", action: "a", id: "i")
        )
      end

      def test_subdomain_may_be_changed
        add_host!
        assert_equal("http://api.basecamphq.com/c/a/i",
          W.new.url_for(subdomain: "api", controller: "c", action: "a", id: "i")
        )
      end

      def test_subdomain_may_be_object
        model = Class.new { def self.to_param; "api"; end }
        add_host!
        assert_equal("http://api.basecamphq.com/c/a/i",
          W.new.url_for(subdomain: model, controller: "c", action: "a", id: "i")
        )
      end

      def test_subdomain_may_be_removed
        add_host!
        assert_equal("http://basecamphq.com/c/a/i",
          W.new.url_for(subdomain: false, controller: "c", action: "a", id: "i")
        )
      end

      def test_subdomain_may_be_removed_with_blank_string
        W.default_url_options[:host] = "api.basecamphq.com"
        assert_equal("http://basecamphq.com/c/a/i",
          W.new.url_for(subdomain: "", controller: "c", action: "a", id: "i")
        )
      end

      def test_multiple_subdomains_may_be_removed
        W.default_url_options[:host] = "mobile.www.api.basecamphq.com"
        assert_equal("http://basecamphq.com/c/a/i",
          W.new.url_for(subdomain: false, controller: "c", action: "a", id: "i")
        )
      end

      def test_subdomain_may_be_accepted_with_numeric_host
        add_numeric_host!
        assert_equal("http://127.0.0.1/c/a/i",
          W.new.url_for(subdomain: "api", controller: "c", action: "a", id: "i")
        )
      end

      def test_domain_may_be_changed
        add_host!
        assert_equal("http://www.37signals.com/c/a/i",
          W.new.url_for(domain: "37signals.com", controller: "c", action: "a", id: "i")
        )
      end

      def test_tld_length_may_be_changed
        add_host!
        assert_equal("http://mobile.www.basecamphq.com/c/a/i",
          W.new.url_for(subdomain: "mobile", tld_length: 2, controller: "c", action: "a", id: "i")
        )
      end

      def test_port
        add_host!
        assert_equal("http://www.basecamphq.com:3000/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", port: 3000)
        )
      end

      def test_default_port
        add_host!
        add_port!
        assert_equal("http://www.basecamphq.com:3000/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i")
        )
      end

      def test_protocol
        add_host!
        assert_equal("https://www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "https")
        )
      end

      def test_protocol_with_and_without_separators
        add_host!
        assert_equal("https://www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "https")
        )
        assert_equal("https://www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "https:")
        )
        assert_equal("https://www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "https://")
        )
      end

      def test_without_protocol
        add_host!
        assert_equal("//www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "//")
        )
        assert_equal("//www.basecamphq.com/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: false)
        )
      end

      def test_without_protocol_and_with_port
        add_host!
        add_port!

        assert_equal("//www.basecamphq.com:3000/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "//")
        )
        assert_equal("//www.basecamphq.com:3000/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: false)
        )
      end

      def test_trailing_slash
        add_host!
        options = {controller: "foo", trailing_slash: true, action: "bar", id: "33"}
        assert_equal("http://www.basecamphq.com/foo/bar/33/", W.new.url_for(options) )
      end

      def test_trailing_slash_with_protocol
        add_host!
        options = { trailing_slash: true,protocol: "https", controller: "foo", action: "bar", id: "33"}
        assert_equal("https://www.basecamphq.com/foo/bar/33/", W.new.url_for(options) )
        assert_equal "https://www.basecamphq.com/foo/bar/33/?query=string", W.new.url_for(options.merge(query: "string"))
      end

      def test_trailing_slash_with_only_path
        options = {controller: "foo", trailing_slash: true}
        assert_equal "/foo/", W.new.url_for(options.merge(only_path: true))
        options.update(action: "bar", id: "33")
        assert_equal "/foo/bar/33/", W.new.url_for(options.merge(only_path: true))
        assert_equal "/foo/bar/33/?query=string", W.new.url_for(options.merge(query: "string",only_path: true))
      end

      def test_trailing_slash_with_anchor
        options = {trailing_slash: true, controller: "foo", action: "bar", id: "33", only_path: true, anchor: "chapter7"}
        assert_equal "/foo/bar/33/#chapter7", W.new.url_for(options)
        assert_equal "/foo/bar/33/?query=string#chapter7", W.new.url_for(options.merge(query: "string"))
      end

      def test_trailing_slash_with_params
        url = W.new.url_for(trailing_slash: true, only_path: true, controller: "cont", action: "act", p1: "cafe", p2: "link")
        params = extract_params(url)
        assert_equal({p1: "cafe"}.to_query, params[0])
        assert_equal({p2: "link"}.to_query, params[1])
      end

      def test_relative_url_root_is_respected
        add_host!
        assert_equal("https://www.basecamphq.com/subdir/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "https", script_name: "/subdir")
        )
      end

      def test_relative_url_root_is_respected_with_environment_variable
        # `config.relative_url_root` is set by ENV['RAILS_RELATIVE_URL_ROOT']
        w = Class.new {
          config = ActionDispatch::Routing::RouteSet::Config.new "/subdir"
          r = ActionDispatch::Routing::RouteSet.new(config)
          r.draw { ActiveSupport::Deprecation.silence { get ":controller(/:action(/:id(.:format)))" } }
          include r.url_helpers
        }
        add_host!(w)
        assert_equal("https://www.basecamphq.com/subdir/c/a/i",
          w.new.url_for(controller: "c", action: "a", id: "i", protocol: "https")
        )
      end

      def test_named_routes
        with_routing do |set|
          set.draw do
            get "this/is/verbose", to: "home#index", as: :no_args
            get "home/sweet/home/:user", to: "home#index", as: :home
          end

          # We need to create a new class in order to install the new named route.
          kls = Class.new { include set.url_helpers }

          controller = kls.new
          assert controller.respond_to?(:home_url)
          assert_equal "http://www.basecamphq.com/home/sweet/home/again",
            controller.send(:home_url, host: "www.basecamphq.com", user: "again")

          assert_equal("/home/sweet/home/alabama", controller.send(:home_path, user: "alabama", host: "unused"))
          assert_equal("http://www.basecamphq.com/home/sweet/home/alabama", controller.send(:home_url, user: "alabama", host: "www.basecamphq.com"))
          assert_equal("http://www.basecamphq.com/this/is/verbose", controller.send(:no_args_url, host: "www.basecamphq.com"))
        end
      end

      def test_relative_url_root_is_respected_for_named_routes
        with_routing do |set|
          set.draw do
            get "/home/sweet/home/:user", to: "home#index", as: :home
          end

          kls = Class.new { include set.url_helpers }
          controller = kls.new

          assert_equal "http://www.basecamphq.com/subdir/home/sweet/home/again",
            controller.send(:home_url, host: "www.basecamphq.com", user: "again", script_name: "/subdir")
        end
      end

      def test_using_nil_script_name_properly_concats_with_original_script_name
        add_host!
        assert_equal("https://www.basecamphq.com/subdir/c/a/i",
          W.new.url_for(controller: "c", action: "a", id: "i", protocol: "https", script_name: nil, original_script_name: "/subdir")
        )
      end

      def test_only_path
        with_routing do |set|
          set.draw do
            get "home/sweet/home/:user", to: "home#index", as: :home

            ActiveSupport::Deprecation.silence do
              get ":controller/:action/:id"
            end
          end

          # We need to create a new class in order to install the new named route.
          kls = Class.new { include set.url_helpers }
          controller = kls.new
          assert_respond_to controller, :home_url
          assert_equal "/brave/new/world",
            controller.url_for(controller: "brave", action: "new", id: "world", only_path: true)

          assert_equal("/home/sweet/home/alabama", controller.home_path(user: "alabama", host: "unused"))
          assert_equal("/home/sweet/home/alabama", controller.home_path("alabama"))
        end
      end

      def test_one_parameter
        assert_equal("/c/a?param=val",
          W.new.url_for(only_path: true, controller: "c", action: "a", param: "val")
        )
      end

      def test_two_parameters
        url = W.new.url_for(only_path: true, controller: "c", action: "a", p1: "X1", p2: "Y2")
        params = extract_params(url)
        assert_equal({p1: "X1"}.to_query, params[0])
        assert_equal({p2: "Y2"}.to_query, params[1])
      end

      def test_hash_parameter
        url = W.new.url_for(only_path: true, controller: "c", action: "a", query: {name: "Bob", category: "prof"})
        params = extract_params(url)
        assert_equal({"query[category]" => "prof"}.to_query, params[0])
        assert_equal({"query[name]" => "Bob"}.to_query, params[1])
      end

      def test_array_parameter
        url = W.new.url_for(only_path: true, controller: "c", action: "a", query: ["Bob", "prof"])
        params = extract_params(url)
        assert_equal({"query[]" => "Bob"}.to_query, params[0])
        assert_equal({"query[]" => "prof"}.to_query, params[1])
      end

      def test_hash_recursive_parameters
        url = W.new.url_for(only_path: true, controller: "c", action: "a", query: {person: {name: "Bob", position: "prof"}, hobby: "piercing"})
        params = extract_params(url)
        assert_equal({"query[hobby]"            => "piercing"}.to_query, params[0])
        assert_equal({"query[person][name]"     => "Bob"     }.to_query, params[1])
        assert_equal({"query[person][position]" => "prof"    }.to_query, params[2])
      end

      def test_hash_recursive_and_array_parameters
        url = W.new.url_for(only_path: true, controller: "c", action: "a", id: 101, query: {person: {name: "Bob", position: ["prof", "art director"]}, hobby: "piercing"})
        assert_match(%r(^/c/a/101), url)
        params = extract_params(url)
        assert_equal({"query[hobby]"              => "piercing"    }.to_query, params[0])
        assert_equal({"query[person][name]"       => "Bob"         }.to_query, params[1])
        assert_equal({"query[person][position][]" => "art director"}.to_query, params[2])
        assert_equal({"query[person][position][]" => "prof"        }.to_query, params[3])
      end

      def test_url_action_controller_parameters
        add_host!
        assert_raise(ArgumentError) do
          W.new.url_for(ActionController::Parameters.new(controller: "c", action: "a", protocol: "javascript", f: "%0Aeval(name)"))
        end
      end

      def test_path_generation_for_symbol_parameter_keys
        assert_generates("/image", controller: :image)
      end

      def test_named_routes_with_nil_keys
        with_routing do |set|
          set.draw do
            get "posts.:format", to: "posts#index", as: :posts
            get "/", to: "posts#index", as: :main
          end

          # We need to create a new class in order to install the new named route.
          kls = Class.new { include set.url_helpers }
          kls.default_url_options[:host] = "www.basecamphq.com"

          controller = kls.new
          params = {action: :index, controller: :posts, format: :xml}
          assert_equal("http://www.basecamphq.com/posts.xml", controller.send(:url_for, params))
          params[:format] = nil
          assert_equal("http://www.basecamphq.com/", controller.send(:url_for, params))
        end
      end

      def test_multiple_includes_maintain_distinct_options
        first_class = Class.new { include ActionController::UrlFor }
        second_class = Class.new { include ActionController::UrlFor }

        first_host, second_host = "firsthost.com", "secondhost.com"

        first_class.default_url_options[:host] = first_host
        second_class.default_url_options[:host] = second_host

        assert_equal  first_host, first_class.default_url_options[:host]
        assert_equal second_host, second_class.default_url_options[:host]
      end

      def test_with_stringified_keys
        assert_equal("/c", W.new.url_for("controller" => "c", "only_path" => true))
        assert_equal("/c/a", W.new.url_for("controller" => "c", "action" => "a", "only_path" => true))
      end

      def test_with_hash_with_indifferent_access
        W.default_url_options[:controller] = "d"
        W.default_url_options[:only_path]  = false
        assert_equal("/c", W.new.url_for(ActiveSupport::HashWithIndifferentAccess.new("controller" => "c", "only_path" => true)))

        W.default_url_options[:action] = "b"
        assert_equal("/c/a", W.new.url_for(ActiveSupport::HashWithIndifferentAccess.new("controller" => "c", "action" => "a", "only_path" => true)))
      end

      def test_url_params_with_nil_to_param_are_not_in_url
        assert_equal("/c/a", W.new.url_for(only_path: true, controller: "c", action: "a", id: Struct.new(:to_param).new(nil)))
      end

      def test_false_url_params_are_included_in_query
        assert_equal("/c/a?show=false", W.new.url_for(only_path: true, controller: "c", action: "a", show: false))
      end

      def test_url_generation_with_array_and_hash
        with_routing do |set|
          set.draw do
            namespace :admin do
              resources :posts
            end
          end

          kls = Class.new { include set.url_helpers }
          kls.default_url_options[:host] = "www.basecamphq.com"

          controller = kls.new
          assert_equal("http://www.basecamphq.com/admin/posts/new?param=value",
            controller.send(:url_for, [:new, :admin, :post, { param: "value" }])
          )
        end
      end

      def test_url_for_with_array_is_unmodified
        with_routing do |set|
          set.draw do
            namespace :admin do
              resources :posts
            end
          end

          kls = Class.new { include set.url_helpers }
          kls.default_url_options[:host] = "www.basecamphq.com"

          original_components = [:new, :admin, :post, { param: "value" }]
          components = original_components.dup

          kls.new.url_for(components)

          assert_equal(original_components, components)
        end
      end

      private
        def extract_params(url)
          url.split("?", 2).last.split("&").sort
        end
    end
  end
end
