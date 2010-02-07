######################## BEGIN LICENSE BLOCK ########################
# The Original Code is Mozilla Universal charset detector code.
# 
# The Initial Developer of the Original Code is
# Netscape Communications Corporation.
# Portions created by the Initial Developer are Copyright (C) 2001
# the Initial Developer. All Rights Reserved.
# 
# Contributor(s):
#   Jeff Hodges - port to Ruby
#   Mark Pilgrim - port to Python
#   Shy Shalom - original C code
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301  USA
######################### END LICENSE BLOCK #########################

module CharDet
  class CharSetProber
    attr_accessor :active
    def initialize
    end

    def reset
      @_mState = EDetecting
    end

    def get_charset_name
      return nil
    end

    def feed(aBuf)
    end

    def get_state
      return @_mState
    end

    def get_confidence
      return 0.0
    end

    def filter_high_bit_only(aBuf)
      # DO NOT USE `gsub!`
      # It will remove all characters from the buffer that is later used by
      # other probers.  This is because gsub! removes data from the instance variable
      # that will be passed to later probers, while gsub makes a new instance variable
      # that will not. 
      newBuf = aBuf.gsub(/([\x00-\x7F])+/, ' ')
      return newBuf
    end

    def filter_without_english_letters(aBuf)
      newBuf = aBuf.gsub(/([A-Za-z])+/,' ')
      return newBuf
    end

    def filter_with_english_letters(aBuf)
      # TODO
      return aBuf
    end
  end
end
