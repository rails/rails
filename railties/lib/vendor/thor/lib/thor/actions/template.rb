require 'thor/actions/templater'
require 'erb'

class Thor
  module Actions

    # Gets an ERB template at the relative source, executes it and makes a copy
    # at the relative destination. If the destination is not given it's assumed
    # to be equal to the source removing .tt from the filename.
    #
    # ==== Parameters
    # source<String>:: the relative path to the source root
    # destination<String>:: the relative path to the destination root
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #
    # ==== Examples
    #
    #   template "README", "doc/README"
    #
    #   template "doc/README"
    #
    def template(source, destination=nil, log_status=true)
      destination ||= source.gsub(/.tt$/, '')
      action Template.new(self, source, destination, log_status)
    end

    class Template < Templater #:nodoc:

      def render
        @render ||= begin
          context = base.instance_eval('binding')
          ERB.new(::File.read(source), nil, '-').result(context)
        end
      end

    end
  end
end
