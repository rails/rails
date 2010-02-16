require File.expand_path('../../../bundler', __FILE__)

%w(
  actionmailer
  actionpack
  activemodel
  activerecord
  activeresource
  activesupport
  railties
).each do |framework|
  framework_path = File.expand_path("../../../#{framework}/lib", __FILE__)
  $:.unshift(framework_path) if File.directory?(framework_path) && !$:.include?(framework_path)
end
