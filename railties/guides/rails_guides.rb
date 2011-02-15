pwd = File.dirname(__FILE__)
$:.unshift pwd

# This is a predicate useful for the doc:guides task of applications.
def bundler?
  # Note that rake sets the cwd to the one that contains the Rakefile
  # being executed.
  File.exists?('Gemfile')
end

# Loading Action Pack requires rack and erubis.
require 'rubygems'

begin
  # Guides generation in the Rails repo.
  as_lib = File.join(pwd, "../../activesupport/lib")
  ap_lib = File.join(pwd, "../../actionpack/lib")

  $:.unshift as_lib if File.directory?(as_lib)
  $:.unshift ap_lib if File.directory?(ap_lib)
rescue LoadError
  # Guides generation from gems.
  gem "actionpack", '>= 3.0'
end

begin
  require 'redcloth'
rescue Gem::LoadError
  # This can happen if doc:guides is executed in an application.
  $stderr.puts('Generating guides requires RedCloth 4.1.1+.')
  $stderr.puts(<<ERROR) if bundler?
Please add

  gem 'RedCloth', '~> 4.2'

to the Gemfile, run

  bundle install

and try again.
ERROR

  exit 1
end

require "rails_guides/textile_extensions"
RedCloth.send(:include, RailsGuides::TextileExtensions)

require "rails_guides/generator"
RailsGuides::Generator.new.generate
