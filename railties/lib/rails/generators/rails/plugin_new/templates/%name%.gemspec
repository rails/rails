# Provide a simple gemspec so you can easily use your
# project in your rails apps through git.
Gem::Specification.new do |s|
  s.name        = "<%= name %>"
  s.version     = "0.0.1"
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
