# frozen_string_literal: true

require "rail_inspector/visitor/framework_default"

class FrameworkDefaultTest < Minitest::Test
  def test_smoke
    config = config_for_defaults <<~RUBY
      case target_version.to_s
      when "5.0"
        ActiveSupport.to_time_preserves_timezone = true

        if respond_to?(:active_record)
          active_record.belongs_to_required_by_default = true
        end

        self.ssl_options = { hsts: { subdomains: true } }
      when "5.1"
        load_defaults "5.0"

        if respond_to?(:assets)
          assets.unknown_asset_fallback = false
        end
      else
        raise
      end
    RUBY

    ["5.0", "5.1"].each { |k| assert_includes(config, k) }

    assert_equal("true", config["5.0"]["ActiveSupport.to_time_preserves_timezone"])
    assert_equal("true", config["5.0"]["active_record.belongs_to_required_by_default"])
    assert_equal("{ hsts: { subdomains: true } }", config["5.0"]["self.ssl_options"])
    assert_equal("false", config["5.1"]["assets.unknown_asset_fallback"])
  end

  def test_config_wrapped_in_condition
    config = config_for_defaults <<~RUBY
      case target_version.to_s
      when "7.1"
        if Rails.env.local?
          self.log_file_size = 100 * 1024 * 1024
        end
      end
    RUBY

    assert_includes config, "7.1"
    assert_equal("100 * 1024 * 1024", config["7.1"]["self.log_file_size"])
  end

  def test_condition_inside_framework
    config = config_for_defaults <<~RUBY
      case target_version.to_s
      when "7.1"
        if respond_to?(:action_view)
          if Rails::HTML::Sanitizer.html5_support?
            action_view.sanitizer_vendor = Rails::HTML5::Sanitizer
          end
        end
      end
    RUBY

    assert_includes config, "7.1"
    assert_equal("Rails::HTML5::Sanitizer", config["7.1"]["action_view.sanitizer_vendor"])
  end

  def test_nested_frameworks_raise_when_strict
    original_env, ENV["STRICT"] = ENV["STRICT"], "true"

    assert_raises do
      config_for_defaults <<~RUBY
        case target_version.to_s
        when "7.1"
          if respond_to?(:action_view)
            if respond_to?(:active_record)
            end
          end
        end
      RUBY
    end
  ensure
    ENV["STRICT"] = original_env
  end

  private
    def wrapped_defaults(defaults)
      <<~RUBY
      class Configuration
        def load_defaults(target_version)
          #{defaults}
        end
      end
      RUBY
    end

    def config_for_defaults(defaults)
      full_class = wrapped_defaults(defaults)
      parsed = SyntaxTree.parse(full_class)
      visitor.visit(parsed)
      visitor.config_map
    end

    def visitor
      @visitor ||= RailInspector::Visitor::FrameworkDefault.new
    end
end
