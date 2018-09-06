$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "<%= namespaced_name %>/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "<%= name %>"
  spec.version     = <%= camelized_modules %>::VERSION
  spec.authors     = ["<%= author %>"]
  spec.email       = ["<%= email %>"]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of <%= camelized_modules %>."
  spec.description = "TODO: Description of <%= camelized_modules %>."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  <%= '# ' if options.dev? || options.edge? -%>spec.add_dependency "rails", "<%= Array(rails_version_specifier).join('", "') %>"
<% unless options[:skip_active_record] -%>

  spec.add_development_dependency "<%= gem_for_database[0] %>"
<% end -%>
end
