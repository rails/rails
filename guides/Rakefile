desc 'Generate guides (for authors), use ONLY=foo to process just "foo.textile"'
task :generate_guides do
  ENV["WARN_BROKEN_LINKS"] = "1" # authors can't disable this
  ruby "rails_guides.rb"
end

# Validate guides -------------------------------------------------------------------------
desc 'Validate guides, use ONLY=foo to process just "foo.html"'
task :validate_guides do
  ruby "w3c_validator.rb"
end
