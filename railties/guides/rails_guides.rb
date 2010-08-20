pwd = File.dirname(__FILE__)
$:.unshift pwd

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
  gem "actionpack", '>= 2.3'
end

begin
  gem 'RedCloth', '>= 4.1.1'
  require 'redcloth'
rescue Gem::LoadError
  $stderr.puts('Generating guides requires RedCloth 4.1.1+.')
  exit 1
end

require "rails_guides/textile_extensions"
RedCloth.send(:include, RailsGuides::TextileExtensions)

require "rails_guides/generator"
RailsGuides::Generator.new.generate
