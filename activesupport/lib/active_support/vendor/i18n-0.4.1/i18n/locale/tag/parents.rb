# encoding: utf-8

module I18n
  module Locale
    module Tag
      module Parents
        def parent
          @parent ||= begin
            segs = to_a.compact
            segs.length > 1 ? self.class.tag(*segs[0..(segs.length-2)].join('-')) : nil
          end
        end

        def self_and_parents
          @self_and_parents ||= [self] + parents
        end

        def parents
          @parents ||= ([parent] + (parent ? parent.parents : [])).compact
        end
      end
    end
  end
end
