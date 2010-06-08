# -*- encoding: utf-8 -*-
require File.expand_path('../lib/arel/version.rb', __FILE__)

Gem::Specification.new do |s|
  s.name      = "arel"
  s.version   = Arel::VERSION
  s.authors   = ["Bryan Helmkamp", "Nick Kallen", "Emilio Tagua"]
  s.date      = %q{2010-06-08}
  s.email     = "bryan@brynary.com"
  s.homepage  = "http://github.com/brynary/arel"
  s.summary   = "Arel is a relational algebra engine for Ruby"
  s.description  = <<-EOS.strip
Arel is a Relational Algebra for Ruby. It 1) simplifies the generation complex
of SQL queries and it 2) adapts to various RDBMS systems. It is intended to be
a framework framework; that is, you can build your own ORM with it, focusing on
innovative object and collection modeling as opposed to database compatibility
and query generation.
  EOS
  s.rubyforge_project = "arel"

  s.files      = Dir['lib/**/*']
  s.test_files = Dir['spec/**/*.rb'] - Dir['spec/support/fixtures/**/*.rb']

  s.has_rdoc = true
  s.extra_rdoc_files = %w[History.txt README.markdown]

  # Arel required ActiveRecord, but we're not declaring it to avoid a
  # circular dependency chain. The solution is for ActiveRecord to release
  # the connection adapters which Arel uses in a separate gem
  # s.add_dependency "activerecord", ">= 3.0.pre"
  s.add_dependency "activesupport", ">= 3.0.0.beta"
end
