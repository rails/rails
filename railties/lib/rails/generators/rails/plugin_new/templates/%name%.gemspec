$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "<%= name %>/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "<%= name %>"
  s.version     = <%= camelized %>::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of <%= camelized %>."
  s.description = "TODO: Description of <%= camelized %>."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
<% unless options.skip_test_unit? -%>
  s.test_files = Dir["test/**/*"]
<% end -%>
end
