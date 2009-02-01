# Rack does not automatically cleanup Safari 2 AJAX POST body
# This has not yet been commited to Rack, please +1 this ticket:
# http://rack.lighthouseapp.com/projects/22435/tickets/19

module Rack
  module Utils
    alias_method :parse_query_without_ajax_body_cleanup, :parse_query
    module_function :parse_query_without_ajax_body_cleanup

    def parse_query(qs, d = '&;')
      qs = qs.dup
      qs.chop! if qs[-1] == 0
      parse_query_without_ajax_body_cleanup(qs, d)
    end
    module_function :parse_query
  end
end
