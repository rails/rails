source 'https://rubygems.org'

<% if options[:skip_gemspec] -%>
<%= '# ' if options.dev? || options.edge? -%>gem 'rails', '~> <%= Rails::VERSION::STRING %>'
<% else -%>
# Declare your gem's dependencies in <%= name %>.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec
<% end -%>

<% if options[:skip_gemspec] -%>
group :development do
  gem '<%= gem_for_database[0] %>'
end
<% else -%>
# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.
<% end -%>

<% if options.dev? || options.edge? -%>
# Your gem is dependent on dev or edge Rails. Once you can lock this
# dependency down to a specific version, move it to your gemspec.
<% max_width = gemfile_entries.map { |g| g.name.length }.max -%>
<% gemfile_entries.each do |gem| -%>
<% if gem.comment -%>

# <%= gem.comment %>
<% end -%>
<%= gem.commented_out ? '# ' : '' %>gem '<%= gem.name %>'<%= %(, '#{gem.version}') if gem.version -%>
<% if gem.options.any? -%>
, <%= gem.options.map { |k,v|
  "#{k}: #{v.inspect}" }.join(', ') %>
<% end -%>
<% end -%>

<% end -%>
<% unless defined?(JRUBY_VERSION) -%>
# To use a debugger
  <%- if RUBY_VERSION < '2.0.0' -%>
# gem 'debugger', group: [:development, :test]
  <%- else -%>
# gem 'byebug', group: [:development, :test]
  <%- end -%>
<% end -%>

<% if RUBY_PLATFORM.match(/bccwin|cygwin|emx|mingw|mswin|wince|java/) -%>
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
<% end -%>
