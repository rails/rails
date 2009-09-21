class Gem::Commands::BundleCommand < Gem::Command

  def initialize
    super('bundle', 'Create a gem bundle based on your Gemfile', {:manifest => nil, :update => false})

    add_option('-m', '--manifest MANIFEST', "Specify the path to the manifest file") do |manifest, options|
      options[:manifest] = manifest
    end

    add_option('-u', '--update', "Force a remote check for newer gems") do
      options[:update] = true
    end
  end

  def usage
    "#{program_name}"
  end

  def description # :nodoc:
    <<-EOF
Bundle stuff
    EOF
  end

  def execute
    # Prevent the bundler from getting required unless it is actually being used
    require 'bundler'
    Bundler::CLI.run(:bundle, options)
  end

end