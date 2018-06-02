$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "<%= namespaced_name %>/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "<%= name %>"
  s.version     = <%= camelized_modules %>::VERSION
  s.authors     = ["<%= author %>"]
  s.email       = ["<%= email %>"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of <%= camelized_modules %>."
  s.description = "TODO: Description of <%= camelized_modules %>."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  <%= '# ' if options.dev? || options.edge? -%>s.add_dependency "rails", "<%= Array(rails_version_specifier).join('", "') %>"
<% unless options[:skip_active_record] -%>

  s.add_development_dependency "<%= gem_for_database[0] %>"
<% end -%>
end
