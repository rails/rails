# -*- encoding: utf-8 -*-
# stub: actionview 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "actionview".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/actionview/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/actionview" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Simple, battle-tested conventions and helpers for building web pages.".freeze
  s.email = "david@loudthinking.com".freeze
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.rdoc".freeze, "lib/action_view".freeze, "lib/action_view.rb".freeze, "lib/action_view/base.rb".freeze, "lib/action_view/buffers.rb".freeze, "lib/action_view/cache_expiry.rb".freeze, "lib/action_view/context.rb".freeze, "lib/action_view/dependency_tracker.rb".freeze, "lib/action_view/digestor.rb".freeze, "lib/action_view/flows.rb".freeze, "lib/action_view/gem_version.rb".freeze, "lib/action_view/helpers".freeze, "lib/action_view/helpers.rb".freeze, "lib/action_view/helpers/active_model_helper.rb".freeze, "lib/action_view/helpers/asset_tag_helper.rb".freeze, "lib/action_view/helpers/asset_url_helper.rb".freeze, "lib/action_view/helpers/atom_feed_helper.rb".freeze, "lib/action_view/helpers/cache_helper.rb".freeze, "lib/action_view/helpers/capture_helper.rb".freeze, "lib/action_view/helpers/controller_helper.rb".freeze, "lib/action_view/helpers/csp_helper.rb".freeze, "lib/action_view/helpers/csrf_helper.rb".freeze, "lib/action_view/helpers/date_helper.rb".freeze, "lib/action_view/helpers/debug_helper.rb".freeze, "lib/action_view/helpers/form_helper.rb".freeze, "lib/action_view/helpers/form_options_helper.rb".freeze, "lib/action_view/helpers/form_tag_helper.rb".freeze, "lib/action_view/helpers/javascript_helper.rb".freeze, "lib/action_view/helpers/number_helper.rb".freeze, "lib/action_view/helpers/output_safety_helper.rb".freeze, "lib/action_view/helpers/rendering_helper.rb".freeze, "lib/action_view/helpers/sanitize_helper.rb".freeze, "lib/action_view/helpers/tag_helper.rb".freeze, "lib/action_view/helpers/tags".freeze, "lib/action_view/helpers/tags.rb".freeze, "lib/action_view/helpers/tags/base.rb".freeze, "lib/action_view/helpers/tags/check_box.rb".freeze, "lib/action_view/helpers/tags/checkable.rb".freeze, "lib/action_view/helpers/tags/collection_check_boxes.rb".freeze, "lib/action_view/helpers/tags/collection_helpers.rb".freeze, "lib/action_view/helpers/tags/collection_radio_buttons.rb".freeze, "lib/action_view/helpers/tags/collection_select.rb".freeze, "lib/action_view/helpers/tags/color_field.rb".freeze, "lib/action_view/helpers/tags/date_field.rb".freeze, "lib/action_view/helpers/tags/date_select.rb".freeze, "lib/action_view/helpers/tags/datetime_field.rb".freeze, "lib/action_view/helpers/tags/datetime_local_field.rb".freeze, "lib/action_view/helpers/tags/datetime_select.rb".freeze, "lib/action_view/helpers/tags/email_field.rb".freeze, "lib/action_view/helpers/tags/file_field.rb".freeze, "lib/action_view/helpers/tags/grouped_collection_select.rb".freeze, "lib/action_view/helpers/tags/hidden_field.rb".freeze, "lib/action_view/helpers/tags/label.rb".freeze, "lib/action_view/helpers/tags/month_field.rb".freeze, "lib/action_view/helpers/tags/number_field.rb".freeze, "lib/action_view/helpers/tags/password_field.rb".freeze, "lib/action_view/helpers/tags/placeholderable.rb".freeze, "lib/action_view/helpers/tags/radio_button.rb".freeze, "lib/action_view/helpers/tags/range_field.rb".freeze, "lib/action_view/helpers/tags/search_field.rb".freeze, "lib/action_view/helpers/tags/select.rb".freeze, "lib/action_view/helpers/tags/tel_field.rb".freeze, "lib/action_view/helpers/tags/text_area.rb".freeze, "lib/action_view/helpers/tags/text_field.rb".freeze, "lib/action_view/helpers/tags/time_field.rb".freeze, "lib/action_view/helpers/tags/time_select.rb".freeze, "lib/action_view/helpers/tags/time_zone_select.rb".freeze, "lib/action_view/helpers/tags/translator.rb".freeze, "lib/action_view/helpers/tags/url_field.rb".freeze, "lib/action_view/helpers/tags/week_field.rb".freeze, "lib/action_view/helpers/text_helper.rb".freeze, "lib/action_view/helpers/translation_helper.rb".freeze, "lib/action_view/helpers/url_helper.rb".freeze, "lib/action_view/layouts.rb".freeze, "lib/action_view/locale".freeze, "lib/action_view/locale/en.yml".freeze, "lib/action_view/log_subscriber.rb".freeze, "lib/action_view/lookup_context.rb".freeze, "lib/action_view/model_naming.rb".freeze, "lib/action_view/path_set.rb".freeze, "lib/action_view/railtie.rb".freeze, "lib/action_view/record_identifier.rb".freeze, "lib/action_view/renderer".freeze, "lib/action_view/renderer/abstract_renderer.rb".freeze, "lib/action_view/renderer/partial_renderer".freeze, "lib/action_view/renderer/partial_renderer.rb".freeze, "lib/action_view/renderer/partial_renderer/collection_caching.rb".freeze, "lib/action_view/renderer/renderer.rb".freeze, "lib/action_view/renderer/streaming_template_renderer.rb".freeze, "lib/action_view/renderer/template_renderer.rb".freeze, "lib/action_view/rendering.rb".freeze, "lib/action_view/routing_url_for.rb".freeze, "lib/action_view/tasks".freeze, "lib/action_view/tasks/cache_digests.rake".freeze, "lib/action_view/template".freeze, "lib/action_view/template.rb".freeze, "lib/action_view/template/error.rb".freeze, "lib/action_view/template/handlers".freeze, "lib/action_view/template/handlers.rb".freeze, "lib/action_view/template/handlers/builder.rb".freeze, "lib/action_view/template/handlers/erb".freeze, "lib/action_view/template/handlers/erb.rb".freeze, "lib/action_view/template/handlers/erb/erubi.rb".freeze, "lib/action_view/template/handlers/html.rb".freeze, "lib/action_view/template/handlers/raw.rb".freeze, "lib/action_view/template/html.rb".freeze, "lib/action_view/template/inline.rb".freeze, "lib/action_view/template/raw_file.rb".freeze, "lib/action_view/template/resolver.rb".freeze, "lib/action_view/template/sources".freeze, "lib/action_view/template/sources.rb".freeze, "lib/action_view/template/sources/file.rb".freeze, "lib/action_view/template/text.rb".freeze, "lib/action_view/template/types.rb".freeze, "lib/action_view/test_case.rb".freeze, "lib/action_view/testing".freeze, "lib/action_view/testing/resolvers.rb".freeze, "lib/action_view/unbound_template.rb".freeze, "lib/action_view/version.rb".freeze, "lib/action_view/view_paths.rb".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Rendering framework putting the V in MVC (part of Rails).".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<builder>.freeze, ["~> 3.1"])
      s.add_runtime_dependency(%q<erubi>.freeze, ["~> 1.4"])
      s.add_runtime_dependency(%q<rails-html-sanitizer>.freeze, ["~> 1.1", ">= 1.2.0"])
      s.add_runtime_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0"])
      s.add_development_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_development_dependency(%q<activemodel>.freeze, ["= 6.1.0.alpha"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<builder>.freeze, ["~> 3.1"])
      s.add_dependency(%q<erubi>.freeze, ["~> 1.4"])
      s.add_dependency(%q<rails-html-sanitizer>.freeze, ["~> 1.1", ">= 1.2.0"])
      s.add_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activemodel>.freeze, ["= 6.1.0.alpha"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<builder>.freeze, ["~> 3.1"])
    s.add_dependency(%q<erubi>.freeze, ["~> 1.4"])
    s.add_dependency(%q<rails-html-sanitizer>.freeze, ["~> 1.1", ">= 1.2.0"])
    s.add_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activemodel>.freeze, ["= 6.1.0.alpha"])
  end
end
