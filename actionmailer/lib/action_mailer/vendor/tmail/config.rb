#
# config.rb
#
# Copyright (c) 1998-2003 Minero Aoki <aamine@loveruby.net>
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2 or later.
#

module TMail

  class Config

    def initialize( strict )
      @strict_parse = strict
      @strict_base64decode = strict
    end

    def strict_parse?
      @strict_parse
    end

    attr_writer :strict_parse

    def strict_base64decode?
      @strict_base64decode
    end

    attr_writer :strict_base64decode

    def new_body_port( mail )
      StringPort.new
    end

    alias new_preamble_port  new_body_port
    alias new_part_port      new_body_port
  
  end

  DEFAULT_CONFIG        = Config.new(false)
  DEFAULT_STRICT_CONFIG = Config.new(true)

  def Config.to_config( arg )
    return DEFAULT_STRICT_CONFIG if arg == true
    return DEFAULT_CONFIG        if arg == false
    arg or DEFAULT_CONFIG
  end

end
