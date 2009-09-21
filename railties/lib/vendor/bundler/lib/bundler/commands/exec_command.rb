class Gem::Commands::ExecCommand < Gem::Command

  def initialize
    super('exec', 'Run a command in context of a gem bundle', {:manifest => nil})

    add_option('-m', '--manifest MANIFEST', "Specify the path to the manifest file") do |manifest, options|
      options[:manifest] = manifest
    end
  end

  def usage
    "#{program_name} COMMAND"
  end

  def arguments # :nodoc:
    "COMMAND  command to run in context of the gem bundle"
  end

  def description # :nodoc:
    <<-EOF.gsub('      ', '')
      Run in context of a bundle
    EOF
  end

  def execute
    # Prevent the bundler from getting required unless it is actually being used
    require 'bundler'
    Bundler::CLI.run(:exec, options)
  end

end