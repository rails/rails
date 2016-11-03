pwd = File.dirname(__FILE__)
$:.unshift pwd

begin
  # Guides generation in the Rails repo.
  as_lib = File.join(pwd, "../activesupport/lib")
  ap_lib = File.join(pwd, "../actionpack/lib")

  $:.unshift as_lib if File.directory?(as_lib)
  $:.unshift ap_lib if File.directory?(ap_lib)
rescue LoadError
  # Guides generation from gems.
  gem "actionpack", ">= 3.0"
end

require "rails_guides/generator"
RailsGuides::Generator.new.generate
