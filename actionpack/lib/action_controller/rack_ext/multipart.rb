module Rack
  module Utils
    module Multipart
      class << self
        def parse_multipart_with_rewind(env)
          result = parse_multipart_without_rewind(env)

          begin
            env['rack.input'].rewind if env['rack.input'].respond_to?(:rewind)
          rescue Errno::ESPIPE
            # Handles exceptions raised by input streams that cannot be rewound
            # such as when using plain CGI under Apache
          end

          result
        end

        alias_method_chain :parse_multipart, :rewind
      end
    end
  end
end
