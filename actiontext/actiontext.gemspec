# -*- encoding: utf-8 -*-
# stub: actiontext 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "actiontext".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/actiontext/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/actiontext" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Javan Makhmali".freeze, "Sam Stephenson".freeze, "David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Edit and display rich text in Rails applications.".freeze
  s.email = ["javan@javan.us".freeze, "sstephenson@gmail.com".freeze, "david@loudthinking.com".freeze]
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.md".freeze, "app/helpers/action_text".freeze, "app/helpers/action_text/content_helper.rb".freeze, "app/helpers/action_text/tag_helper.rb".freeze, "app/javascript/actiontext".freeze, "app/javascript/actiontext/attachment_upload.js".freeze, "app/javascript/actiontext/index.js".freeze, "app/models/action_text".freeze, "app/models/action_text/rich_text.rb".freeze, "app/views/action_text".freeze, "app/views/action_text/attachables".freeze, "app/views/action_text/attachables/_missing_attachable.html.erb".freeze, "app/views/action_text/attachables/_remote_image.html.erb".freeze, "app/views/action_text/attachment_galleries".freeze, "app/views/action_text/attachment_galleries/_attachment_gallery.html.erb".freeze, "app/views/action_text/content".freeze, "app/views/action_text/content/_layout.html.erb".freeze, "app/views/active_storage/blobs/_blob.html.erb".freeze, "db/migrate/20180528164100_create_action_text_tables.rb".freeze, "lib/action_text".freeze, "lib/action_text.rb".freeze, "lib/action_text/attachable.rb".freeze, "lib/action_text/attachables".freeze, "lib/action_text/attachables/content_attachment.rb".freeze, "lib/action_text/attachables/missing_attachable.rb".freeze, "lib/action_text/attachables/remote_image.rb".freeze, "lib/action_text/attachment.rb".freeze, "lib/action_text/attachment_gallery.rb".freeze, "lib/action_text/attachments".freeze, "lib/action_text/attachments/caching.rb".freeze, "lib/action_text/attachments/minification.rb".freeze, "lib/action_text/attachments/trix_conversion.rb".freeze, "lib/action_text/attribute.rb".freeze, "lib/action_text/content.rb".freeze, "lib/action_text/engine.rb".freeze, "lib/action_text/fragment.rb".freeze, "lib/action_text/gem_version.rb".freeze, "lib/action_text/html_conversion.rb".freeze, "lib/action_text/plain_text_conversion.rb".freeze, "lib/action_text/serialization.rb".freeze, "lib/action_text/system_test_helper.rb".freeze, "lib/action_text/trix_attachment.rb".freeze, "lib/action_text/version.rb".freeze, "lib/tasks/actiontext.rake".freeze, "lib/templates".freeze, "lib/templates/actiontext.scss".freeze, "lib/templates/fixtures.yml".freeze, "lib/templates/installer.rb".freeze, "package.json".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Rich text framework.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 1.8.5"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<nokogiri>.freeze, [">= 1.8.5"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<nokogiri>.freeze, [">= 1.8.5"])
  end
end
