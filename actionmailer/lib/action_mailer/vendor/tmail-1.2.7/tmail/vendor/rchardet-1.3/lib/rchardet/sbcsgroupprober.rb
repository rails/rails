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
  class SBCSGroupProber < CharSetGroupProber
    def initialize
      super
      @_mProbers = [ SingleByteCharSetProber.new(Win1251CyrillicModel),
                     SingleByteCharSetProber.new(Koi8rModel),
                     SingleByteCharSetProber.new(Latin5CyrillicModel),
                     SingleByteCharSetProber.new(MacCyrillicModel),
                     SingleByteCharSetProber.new(Ibm866Model),
                     SingleByteCharSetProber.new(Ibm855Model),
                     SingleByteCharSetProber.new(Latin7GreekModel),
                     SingleByteCharSetProber.new(Win1253GreekModel),
                     SingleByteCharSetProber.new(Latin5BulgarianModel),
                     SingleByteCharSetProber.new(Win1251BulgarianModel),
                     SingleByteCharSetProber.new(Latin2HungarianModel),
                     SingleByteCharSetProber.new(Win1250HungarianModel),
                     SingleByteCharSetProber.new(TIS620ThaiModel) ]
      hebrewProber = HebrewProber.new()
      logicalHebrewProber = SingleByteCharSetProber.new(Win1255HebrewModel, false, hebrewProber)
      visualHebrewProber = SingleByteCharSetProber.new(Win1255HebrewModel, true, hebrewProber)
      hebrewProber.set_model_probers(logicalHebrewProber, visualHebrewProber)
      @_mProbers += [hebrewProber, logicalHebrewProber, visualHebrewProber]

      reset()
    end
  end
end
