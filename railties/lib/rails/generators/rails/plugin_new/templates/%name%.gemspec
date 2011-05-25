# Provide a simple gemspec so you can easily use your
# project in your rails apps through git.
Gem::Specification.new do |s|
  s.name = "<%= name %>"
  s.summary = "Insert <%= camelized %> summary."
  s.description = "Insert <%= camelized %> description."
  s.files = Dir["{app,config,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
<% unless options.skip_test_unit? -%>
  s.test_files = Dir["test/**/*"]
<% end -%>
  s.version = "0.0.1"
end
