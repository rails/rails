pwd = File.dirname(__FILE__)
$: << pwd
$: << File.join(pwd, "../../activesupport/lib")
$: << File.join(pwd, "../../actionpack/lib")

require "action_controller"
require "action_view"

# Require rubygems after loading Action View
require 'rubygems'
begin
  gem 'RedCloth', '>= 4.1.1'# Need exactly 4.1.1
rescue Gem::LoadError
  $stderr.puts %(Missing the RedCloth 4.1.1 gem.\nPlease `gem install -v=4.1.1 RedCloth` to generate the guides.)
  exit 1
end

require 'redcloth'

module RailsGuides
  autoload :Generator, "rails_guides/generator"
  autoload :Indexer, "rails_guides/indexer"
  autoload :Helpers, "rails_guides/helpers"
  autoload :TextileExtensions, "rails_guides/textile_extensions"
end

RedCloth.send(:include, RailsGuides::TextileExtensions)

if $0 == __FILE__
  RailsGuides::Generator.new.generate
end
