$:.push File.expand_path("../lib", __FILE__)

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

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  <%= '# ' if options.dev? || options.edge? -%>s.add_dependency "rails", "<%= Array(rails_version_specifier).join('", "') %>"
<% unless options[:skip_active_record] -%>

  s.add_development_dependency "<%= gem_for_database[0] %>"
<% end -%>
end
