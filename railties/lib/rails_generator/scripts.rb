require File.dirname(__FILE__) + '/options'

module Rails
  module Generator
    module Scripts

      # Generator scripts handle command-line invocation.  Each script
      # responds to an invoke! class method which handles option parsing
      # and generator invocation.
      class Base
        include Options
        default_options :collision => :ask, :quiet => false

        # Run the generator script.  Takes an array of unparsed arguments
        # and a hash of parsed arguments, takes the generator as an option
        # or first remaining argument, and invokes the requested command.
        def run(args = [], runtime_options = {})
          begin
            parse!(args.dup, runtime_options)
          rescue OptionParser::InvalidOption => e
            # Don't cry, script. Generators want what you think is invalid.
          end

          # Generator name is the only required option.
          unless options[:generator]
            usage if args.empty?
            options[:generator] ||= args.shift
          end

          # Look up generator instance and invoke command on it.
          Rails::Generator::Base.instance(options[:generator], args, options).command(options[:command]).invoke!
        rescue => e
          puts e
          puts "  #{e.backtrace.join("\n  ")}\n" if options[:backtrace]
          raise SystemExit
        end

        protected
          # Override with your own script usage banner.
          def banner
            "Usage: #{$0} generator [options] [args]"
          end

          def usage_message
            usage = "\nInstalled Generators\n"
            Rails::Generator::Base.sources.inject([]) do |mem, source|
              # Using an association list instead of a hash to preserve order,
              # for aesthetic reasons more than anything else.
              label = source.label.to_s.capitalize
              pair = mem.assoc(label)
              mem << (pair = [label, []]) if pair.nil?
              pair[1] |= source.names
              mem
            end.each do |label, names|
              usage << "  #{label}: #{names.join(', ')}\n" unless names.empty?
            end

            usage << <<end_blurb

More are available at http://wiki.rubyonrails.org/rails/pages/AvailableGenerators
  1. Download, for example, login_generator.zip
  2. Unzip to directory #{Dir.user_home}/.rails/generators/login
     to use the generator with all your Rails apps
end_blurb

            if Object.const_defined?(:RAILS_ROOT)
              usage << <<end_blurb
     or to #{File.expand_path(RAILS_ROOT)}/lib/generators/login
     to use with this app only.
end_blurb
            end

            usage << <<end_blurb
  3. Run generate with no arguments for usage information
       #{$0} login

Generator gems are also available:
  1. gem search -r generator
  2. gem install login_generator
  3. #{$0} login

end_blurb
            return usage
          end
      end # Base

    end
  end
end
