# frozen_string_literal: true

module Rails
  module Generators
    module BundleHelper # :nodoc:
      def bundle_command(command, env = {}, params = {})
        say_status :run, "bundle #{command}"

        # We are going to shell out rather than invoking Bundler::CLI.new(command)
        # because `rails new` loads the Thor gem and on the other hand bundler uses
        # its own vendored Thor, which could be a different version. Running both
        # things in the same process is a recipe for a night with paracetamol.
        #
        # Thanks to James Tucker for the Gem tricks involved in this call.
        _bundle_command = Gem.bin_path("bundler", "bundle")

        require "bundler"
        Bundler.with_original_env do
          exec_bundle_command(_bundle_command, command, env, params)
        end
      end

      private
        def exec_bundle_command(bundle_command, command, env, params)
          full_command = %Q["#{Gem.ruby}" "#{bundle_command}" #{command}]
          if options[:quiet] || params[:quiet]
            system(env, full_command, out: File::NULL)
          else
            system(env, full_command)
          end
        end
    end
  end
end
