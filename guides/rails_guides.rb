$:.unshift __dir__

as_lib = File.expand_path("../activesupport/lib", __dir__)
ap_lib = File.expand_path("../actionpack/lib", __dir__)
av_lib = File.expand_path("../actionview/lib", __dir__)

$:.unshift as_lib if File.directory?(as_lib)
$:.unshift ap_lib if File.directory?(ap_lib)
$:.unshift av_lib if File.directory?(av_lib)

require "rails_guides/generator"
require "active_support/core_ext/object/blank"

env_value = ->(name) { ENV[name].presence }
env_flag  = ->(name) { "1" == env_value[name] }

version = env_value["RAILS_VERSION"]
edge    = `git rev-parse HEAD`.strip unless version

RailsGuides::Generator.new(
  edge:     edge,
  version:  version,
  all:      env_flag["ALL"],
  only:     env_value["ONLY"],
  kindle:   env_flag["KINDLE"],
  language: env_value["GUIDES_LANGUAGE"]
).generate
