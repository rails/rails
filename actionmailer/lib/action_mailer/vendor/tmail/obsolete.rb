#
# obsolete.rb
#
# Copyright (c) 1998-2003 Minero Aoki <aamine@loveruby.net>
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2 or later.
#

module TMail

  # mail.rb
  class Mail
    alias include? key?
    alias has_key? key?

    def values
      ret = []
      each_field {|v| ret.push v }
      ret
    end

    def value?( val )
      HeaderField === val or return false

      [ @header[val.name.downcase] ].flatten.include? val
    end

    alias has_value? value?
  end


  # facade.rb
  class Mail
    def from_addr( default = nil )
      addr, = from_addrs(nil)
      addr || default
    end

    def from_address( default = nil )
      if a = from_addr(nil)
        a.spec
      else
        default
      end
    end

    alias from_address= from_addrs=

    def from_phrase( default = nil )
      if a = from_addr(nil)
        a.phrase
      else
        default
      end
    end

    alias msgid  message_id
    alias msgid= message_id=

    alias each_dest each_destination
  end


  # address.rb
  class Address
    alias route routes
    alias addr spec

    def spec=( str )
      @local, @domain = str.split(/@/,2).map {|s| s.split(/\./) }
    end

    alias addr= spec=
    alias address= spec=
  end


  # mbox.rb
  class MhMailbox
    alias new_mail new_port
    alias each_mail each_port
    alias each_newmail each_new_port
  end
  class UNIXMbox
    alias new_mail new_port
    alias each_mail each_port
    alias each_newmail each_new_port
  end
  class Maildir
    alias new_mail new_port
    alias each_mail each_port
    alias each_newmail each_new_port
  end


  # utils.rb
  extend TextUtils

  class << self
    alias msgid?    message_id?
    alias boundary  new_boundary
    alias msgid     new_message_id
    alias new_msgid new_message_id
  end

  def Mail.boundary
    ::TMail.new_boundary
  end

  def Mail.msgid
    ::TMail.new_message_id
  end

end   # module TMail
