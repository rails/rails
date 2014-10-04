$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "<%= name %>/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "<%= name %>"
  s.version     = <%= camelized %>::VERSION
  s.authors     = ["<%= author %>"]
  s.email       = ["<%= email %>"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of <%= camelized %>."
  s.description = "TODO: Description of <%= camelized %>."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
<% unless options.skip_test_unit? -%>
  s.test_files = Dir["test/**/*"]
<% end -%>

  <%= '# ' if options.dev? || options.edge? -%>s.add_dependency "rails", "~> <%= Rails::VERSION::STRING %>"
<% unless options[:skip_active_record] -%>

  s.add_development_dependency "<%= gem_for_database %>"
<% end -%>
end
