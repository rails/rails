######################## BEGIN LICENSE BLOCK ########################
# The Original Code is mozilla.org code.
#
# The Initial Developer of the Original Code is
# Netscape Communications Corporation.
# Portions created by the Initial Developer are Copyright (C) 1998
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Jeff Hodges - port to Ruby
#   Mark Pilgrim - port to Python
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
  # BIG5 

  BIG5_cls = [
    1,1,1,1,1,1,1,1,  # 00 - 07    #allow 0x00 as legal value
    1,1,1,1,1,1,0,0,  # 08 - 0f 
    1,1,1,1,1,1,1,1,  # 10 - 17 
    1,1,1,0,1,1,1,1,  # 18 - 1f 
    1,1,1,1,1,1,1,1,  # 20 - 27 
    1,1,1,1,1,1,1,1,  # 28 - 2f 
    1,1,1,1,1,1,1,1,  # 30 - 37 
    1,1,1,1,1,1,1,1,  # 38 - 3f 
    2,2,2,2,2,2,2,2,  # 40 - 47 
    2,2,2,2,2,2,2,2,  # 48 - 4f 
    2,2,2,2,2,2,2,2,  # 50 - 57 
    2,2,2,2,2,2,2,2,  # 58 - 5f 
    2,2,2,2,2,2,2,2,  # 60 - 67 
    2,2,2,2,2,2,2,2,  # 68 - 6f 
    2,2,2,2,2,2,2,2,  # 70 - 77 
    2,2,2,2,2,2,2,1,  # 78 - 7f 
    4,4,4,4,4,4,4,4,  # 80 - 87 
    4,4,4,4,4,4,4,4,  # 88 - 8f 
    4,4,4,4,4,4,4,4,  # 90 - 97 
    4,4,4,4,4,4,4,4,  # 98 - 9f 
    4,3,3,3,3,3,3,3,  # a0 - a7 
    3,3,3,3,3,3,3,3,  # a8 - af 
    3,3,3,3,3,3,3,3,  # b0 - b7 
    3,3,3,3,3,3,3,3,  # b8 - bf 
    3,3,3,3,3,3,3,3,  # c0 - c7 
    3,3,3,3,3,3,3,3,  # c8 - cf 
    3,3,3,3,3,3,3,3,  # d0 - d7 
    3,3,3,3,3,3,3,3,  # d8 - df 
    3,3,3,3,3,3,3,3,  # e0 - e7 
    3,3,3,3,3,3,3,3,  # e8 - ef 
    3,3,3,3,3,3,3,3,  # f0 - f7 
    3,3,3,3,3,3,3,0  # f8 - ff 
  ]

  BIG5_st = [
    EError,EStart,EStart,     3,EError,EError,EError,EError,#00-07 
    EError,EError,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EError,#08-0f 
    EError,EStart,EStart,EStart,EStart,EStart,EStart,EStart #10-17 
  ]

  Big5CharLenTable = [0, 1, 1, 2, 0]

  Big5SMModel = {'classTable' =>  BIG5_cls,
	       'classFactor' =>  5,
	       'stateTable' =>  BIG5_st,
	       'charLenTable' =>  Big5CharLenTable,
	       'name' =>  'Big5'
  }

  # EUC-JP

  EUCJP_cls = [
    4,4,4,4,4,4,4,4,  # 00 - 07 
    4,4,4,4,4,4,5,5,  # 08 - 0f 
    4,4,4,4,4,4,4,4,  # 10 - 17 
    4,4,4,5,4,4,4,4,  # 18 - 1f 
    4,4,4,4,4,4,4,4,  # 20 - 27 
    4,4,4,4,4,4,4,4,  # 28 - 2f 
    4,4,4,4,4,4,4,4,  # 30 - 37 
    4,4,4,4,4,4,4,4,  # 38 - 3f 
    4,4,4,4,4,4,4,4,  # 40 - 47 
    4,4,4,4,4,4,4,4,  # 48 - 4f 
    4,4,4,4,4,4,4,4,  # 50 - 57 
    4,4,4,4,4,4,4,4,  # 58 - 5f 
    4,4,4,4,4,4,4,4,  # 60 - 67 
    4,4,4,4,4,4,4,4,  # 68 - 6f 
    4,4,4,4,4,4,4,4,  # 70 - 77 
    4,4,4,4,4,4,4,4,  # 78 - 7f 
    5,5,5,5,5,5,5,5,  # 80 - 87 
    5,5,5,5,5,5,1,3,  # 88 - 8f 
    5,5,5,5,5,5,5,5,  # 90 - 97 
    5,5,5,5,5,5,5,5,  # 98 - 9f 
    5,2,2,2,2,2,2,2,  # a0 - a7 
    2,2,2,2,2,2,2,2,  # a8 - af 
    2,2,2,2,2,2,2,2,  # b0 - b7 
    2,2,2,2,2,2,2,2,  # b8 - bf 
    2,2,2,2,2,2,2,2,  # c0 - c7 
    2,2,2,2,2,2,2,2,  # c8 - cf 
    2,2,2,2,2,2,2,2,  # d0 - d7 
    2,2,2,2,2,2,2,2,  # d8 - df 
    0,0,0,0,0,0,0,0,  # e0 - e7 
    0,0,0,0,0,0,0,0,  # e8 - ef 
    0,0,0,0,0,0,0,0,  # f0 - f7 
    0,0,0,0,0,0,0,5  # f8 - ff 
  ]

  EUCJP_st = [
    3,     4,     3,     5,EStart,EError,EError,EError,#00-07 
    EError,EError,EError,EError,EItsMe,EItsMe,EItsMe,EItsMe,#08-0f 
    EItsMe,EItsMe,EStart,EError,EStart,EError,EError,EError,#10-17 
    EError,EError,EStart,EError,EError,EError,     3,EError,#18-1f 
    3,EError,EError,EError,EStart,EStart,EStart,EStart #20-27 
  ]

  EUCJPCharLenTable = [2, 2, 2, 3, 1, 0]

  EUCJPSMModel = {'classTable' =>  EUCJP_cls,
		'classFactor' =>  6,
		'stateTable' =>  EUCJP_st,
		'charLenTable' =>  EUCJPCharLenTable,
		'name' =>  'EUC-JP'
  }

  # EUC-KR

  EUCKR_cls  = [
    1,1,1,1,1,1,1,1,  # 00 - 07 
    1,1,1,1,1,1,0,0,  # 08 - 0f 
    1,1,1,1,1,1,1,1,  # 10 - 17 
    1,1,1,0,1,1,1,1,  # 18 - 1f 
    1,1,1,1,1,1,1,1,  # 20 - 27 
    1,1,1,1,1,1,1,1,  # 28 - 2f 
    1,1,1,1,1,1,1,1,  # 30 - 37 
    1,1,1,1,1,1,1,1,  # 38 - 3f 
    1,1,1,1,1,1,1,1,  # 40 - 47 
    1,1,1,1,1,1,1,1,  # 48 - 4f 
    1,1,1,1,1,1,1,1,  # 50 - 57 
    1,1,1,1,1,1,1,1,  # 58 - 5f 
    1,1,1,1,1,1,1,1,  # 60 - 67 
    1,1,1,1,1,1,1,1,  # 68 - 6f 
    1,1,1,1,1,1,1,1,  # 70 - 77 
    1,1,1,1,1,1,1,1,  # 78 - 7f 
    0,0,0,0,0,0,0,0,  # 80 - 87 
    0,0,0,0,0,0,0,0,  # 88 - 8f 
    0,0,0,0,0,0,0,0,  # 90 - 97 
    0,0,0,0,0,0,0,0,  # 98 - 9f 
    0,2,2,2,2,2,2,2,  # a0 - a7 
    2,2,2,2,2,3,3,3,  # a8 - af 
    2,2,2,2,2,2,2,2,  # b0 - b7 
    2,2,2,2,2,2,2,2,  # b8 - bf 
    2,2,2,2,2,2,2,2,  # c0 - c7 
    2,3,2,2,2,2,2,2,  # c8 - cf 
    2,2,2,2,2,2,2,2,  # d0 - d7 
    2,2,2,2,2,2,2,2,  # d8 - df 
    2,2,2,2,2,2,2,2,  # e0 - e7 
    2,2,2,2,2,2,2,2,  # e8 - ef 
    2,2,2,2,2,2,2,2,  # f0 - f7 
    2,2,2,2,2,2,2,0  # f8 - ff 
  ]

  EUCKR_st = [
    EError,EStart,     3,EError,EError,EError,EError,EError,#00-07 
    EItsMe,EItsMe,EItsMe,EItsMe,EError,EError,EStart,EStart#08-0f 
  ]

  EUCKRCharLenTable = [0, 1, 2, 0]

  EUCKRSMModel = {'classTable' =>  EUCKR_cls,
		'classFactor' =>  4,
		'stateTable' =>  EUCKR_st,
		'charLenTable' =>  EUCKRCharLenTable,
		'name' =>  'EUC-KR'
  }

  # EUC-TW

  EUCTW_cls = [
    2,2,2,2,2,2,2,2,  # 00 - 07 
    2,2,2,2,2,2,0,0,  # 08 - 0f 
    2,2,2,2,2,2,2,2,  # 10 - 17 
    2,2,2,0,2,2,2,2,  # 18 - 1f 
    2,2,2,2,2,2,2,2,  # 20 - 27 
    2,2,2,2,2,2,2,2,  # 28 - 2f 
    2,2,2,2,2,2,2,2,  # 30 - 37 
    2,2,2,2,2,2,2,2,  # 38 - 3f 
    2,2,2,2,2,2,2,2,  # 40 - 47 
    2,2,2,2,2,2,2,2,  # 48 - 4f 
    2,2,2,2,2,2,2,2,  # 50 - 57 
    2,2,2,2,2,2,2,2,  # 58 - 5f 
    2,2,2,2,2,2,2,2,  # 60 - 67 
    2,2,2,2,2,2,2,2,  # 68 - 6f 
    2,2,2,2,2,2,2,2,  # 70 - 77 
    2,2,2,2,2,2,2,2,  # 78 - 7f 
    0,0,0,0,0,0,0,0,  # 80 - 87 
    0,0,0,0,0,0,6,0,  # 88 - 8f 
    0,0,0,0,0,0,0,0,  # 90 - 97 
    0,0,0,0,0,0,0,0,  # 98 - 9f 
    0,3,4,4,4,4,4,4,  # a0 - a7 
    5,5,1,1,1,1,1,1,  # a8 - af 
    1,1,1,1,1,1,1,1,  # b0 - b7 
    1,1,1,1,1,1,1,1,  # b8 - bf 
    1,1,3,1,3,3,3,3,  # c0 - c7 
    3,3,3,3,3,3,3,3,  # c8 - cf 
    3,3,3,3,3,3,3,3,  # d0 - d7 
    3,3,3,3,3,3,3,3,  # d8 - df 
    3,3,3,3,3,3,3,3,  # e0 - e7 
    3,3,3,3,3,3,3,3,  # e8 - ef 
    3,3,3,3,3,3,3,3,  # f0 - f7 
    3,3,3,3,3,3,3,0  # f8 - ff 
  ]

  EUCTW_st = [
    EError,EError,EStart,     3,     3,     3,     4,EError,#00-07 
    EError,EError,EError,EError,EError,EError,EItsMe,EItsMe,#08-0f 
    EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EError,EStart,EError,#10-17 
    EStart,EStart,EStart,EError,EError,EError,EError,EError,#18-1f 
    5,EError,EError,EError,EStart,EError,EStart,EStart,#20-27 
    EStart,EError,EStart,EStart,EStart,EStart,EStart,EStart #28-2f 
  ]

  EUCTWCharLenTable = [0, 0, 1, 2, 2, 2, 3]

  EUCTWSMModel = {'classTable' =>  EUCTW_cls,
		'classFactor' =>  7,
		'stateTable' =>  EUCTW_st,
		'charLenTable' =>  EUCTWCharLenTable,
		'name' =>  'x-euc-tw'
  }

  # GB2312

  GB2312_cls = [
    1,1,1,1,1,1,1,1,  # 00 - 07 
    1,1,1,1,1,1,0,0,  # 08 - 0f 
    1,1,1,1,1,1,1,1,  # 10 - 17 
    1,1,1,0,1,1,1,1,  # 18 - 1f 
    1,1,1,1,1,1,1,1,  # 20 - 27 
    1,1,1,1,1,1,1,1,  # 28 - 2f 
    3,3,3,3,3,3,3,3,  # 30 - 37 
    3,3,1,1,1,1,1,1,  # 38 - 3f 
    2,2,2,2,2,2,2,2,  # 40 - 47 
    2,2,2,2,2,2,2,2,  # 48 - 4f 
    2,2,2,2,2,2,2,2,  # 50 - 57 
    2,2,2,2,2,2,2,2,  # 58 - 5f 
    2,2,2,2,2,2,2,2,  # 60 - 67 
    2,2,2,2,2,2,2,2,  # 68 - 6f 
    2,2,2,2,2,2,2,2,  # 70 - 77 
    2,2,2,2,2,2,2,4,  # 78 - 7f 
    5,6,6,6,6,6,6,6,  # 80 - 87 
    6,6,6,6,6,6,6,6,  # 88 - 8f 
    6,6,6,6,6,6,6,6,  # 90 - 97 
    6,6,6,6,6,6,6,6,  # 98 - 9f 
    6,6,6,6,6,6,6,6,  # a0 - a7 
    6,6,6,6,6,6,6,6,  # a8 - af 
    6,6,6,6,6,6,6,6,  # b0 - b7 
    6,6,6,6,6,6,6,6,  # b8 - bf 
    6,6,6,6,6,6,6,6,  # c0 - c7 
    6,6,6,6,6,6,6,6,  # c8 - cf 
    6,6,6,6,6,6,6,6,  # d0 - d7 
    6,6,6,6,6,6,6,6,  # d8 - df 
    6,6,6,6,6,6,6,6,  # e0 - e7 
    6,6,6,6,6,6,6,6,  # e8 - ef 
    6,6,6,6,6,6,6,6,  # f0 - f7 
    6,6,6,6,6,6,6,0  # f8 - ff 
  ]

  GB2312_st = [
    EError,EStart,EStart,EStart,EStart,EStart,     3,EError,#00-07 
    EError,EError,EError,EError,EError,EError,EItsMe,EItsMe,#08-0f 
    EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EError,EError,EStart,#10-17 
    4,EError,EStart,EStart,EError,EError,EError,EError,#18-1f 
    EError,EError,     5,EError,EError,EError,EItsMe,EError,#20-27 
    EError,EError,EStart,EStart,EStart,EStart,EStart,EStart#28-2f 
  ]

  # To be accurate, the length of class 6 can be either 2 or 4. 
  # But it is not necessary to discriminate between the two since 
  # it is used for frequency analysis only, and we are validing 
  # each code range there as well. So it is safe to set it to be 
  # 2 here. 
  GB2312CharLenTable = [0, 1, 1, 1, 1, 1, 2]

  GB2312SMModel = {'classTable' =>  GB2312_cls,
		  'classFactor' =>  7,
		  'stateTable' =>  GB2312_st,
		  'charLenTable' =>  GB2312CharLenTable,
		  'name' =>  'GB2312'
  }

  # Shift_JIS

  SJIS_cls = [
    1,1,1,1,1,1,1,1,  # 00 - 07 
    1,1,1,1,1,1,0,0,  # 08 - 0f 
    1,1,1,1,1,1,1,1,  # 10 - 17 
    1,1,1,0,1,1,1,1,  # 18 - 1f 
    1,1,1,1,1,1,1,1,  # 20 - 27 
    1,1,1,1,1,1,1,1,  # 28 - 2f 
    1,1,1,1,1,1,1,1,  # 30 - 37 
    1,1,1,1,1,1,1,1,  # 38 - 3f 
    2,2,2,2,2,2,2,2,  # 40 - 47 
    2,2,2,2,2,2,2,2,  # 48 - 4f 
    2,2,2,2,2,2,2,2,  # 50 - 57 
    2,2,2,2,2,2,2,2,  # 58 - 5f 
    2,2,2,2,2,2,2,2,  # 60 - 67 
    2,2,2,2,2,2,2,2,  # 68 - 6f 
    2,2,2,2,2,2,2,2,  # 70 - 77 
    2,2,2,2,2,2,2,1,  # 78 - 7f 
    3,3,3,3,3,3,3,3,  # 80 - 87 
    3,3,3,3,3,3,3,3,  # 88 - 8f 
    3,3,3,3,3,3,3,3,  # 90 - 97 
    3,3,3,3,3,3,3,3,  # 98 - 9f 
    #0xa0 is illegal in sjis encoding, but some pages does 
    #contain such byte. We need to be more error forgiven.
    2,2,2,2,2,2,2,2,  # a0 - a7     
    2,2,2,2,2,2,2,2,  # a8 - af 
    2,2,2,2,2,2,2,2,  # b0 - b7 
    2,2,2,2,2,2,2,2,  # b8 - bf 
    2,2,2,2,2,2,2,2,  # c0 - c7 
    2,2,2,2,2,2,2,2,  # c8 - cf 
    2,2,2,2,2,2,2,2,  # d0 - d7 
    2,2,2,2,2,2,2,2,  # d8 - df 
    3,3,3,3,3,3,3,3,  # e0 - e7 
    3,3,3,3,3,4,4,4,  # e8 - ef 
    4,4,4,4,4,4,4,4,  # f0 - f7 
    4,4,4,4,4,0,0,0  # f8 - ff 
  ]

  SJIS_st = [
    EError,EStart,EStart,     3,EError,EError,EError,EError,#00-07 
    EError,EError,EError,EError,EItsMe,EItsMe,EItsMe,EItsMe,#08-0f 
    EItsMe,EItsMe,EError,EError,EStart,EStart,EStart,EStart#10-17 
  ]

  SJISCharLenTable = [0, 1, 1, 2, 0, 0]

  SJISSMModel = {'classTable' =>  SJIS_cls,
	       'classFactor' =>  6,
	       'stateTable' =>  SJIS_st,
	       'charLenTable' =>  SJISCharLenTable,
	       'name' =>  'Shift_JIS'
  }

  # UCS2-BE

  UCS2BE_cls = [
    0,0,0,0,0,0,0,0,  # 00 - 07 
    0,0,1,0,0,2,0,0,  # 08 - 0f 
    0,0,0,0,0,0,0,0,  # 10 - 17 
    0,0,0,3,0,0,0,0,  # 18 - 1f 
    0,0,0,0,0,0,0,0,  # 20 - 27 
    0,3,3,3,3,3,0,0,  # 28 - 2f 
    0,0,0,0,0,0,0,0,  # 30 - 37 
    0,0,0,0,0,0,0,0,  # 38 - 3f 
    0,0,0,0,0,0,0,0,  # 40 - 47 
    0,0,0,0,0,0,0,0,  # 48 - 4f 
    0,0,0,0,0,0,0,0,  # 50 - 57 
    0,0,0,0,0,0,0,0,  # 58 - 5f 
    0,0,0,0,0,0,0,0,  # 60 - 67 
    0,0,0,0,0,0,0,0,  # 68 - 6f 
    0,0,0,0,0,0,0,0,  # 70 - 77 
    0,0,0,0,0,0,0,0,  # 78 - 7f 
    0,0,0,0,0,0,0,0,  # 80 - 87 
    0,0,0,0,0,0,0,0,  # 88 - 8f 
    0,0,0,0,0,0,0,0,  # 90 - 97 
    0,0,0,0,0,0,0,0,  # 98 - 9f 
    0,0,0,0,0,0,0,0,  # a0 - a7 
    0,0,0,0,0,0,0,0,  # a8 - af 
    0,0,0,0,0,0,0,0,  # b0 - b7 
    0,0,0,0,0,0,0,0,  # b8 - bf 
    0,0,0,0,0,0,0,0,  # c0 - c7 
    0,0,0,0,0,0,0,0,  # c8 - cf 
    0,0,0,0,0,0,0,0,  # d0 - d7 
    0,0,0,0,0,0,0,0,  # d8 - df 
    0,0,0,0,0,0,0,0,  # e0 - e7 
    0,0,0,0,0,0,0,0,  # e8 - ef 
    0,0,0,0,0,0,0,0,  # f0 - f7 
    0,0,0,0,0,0,4,5  # f8 - ff 
  ]

  UCS2BE_st  = [
    5,     7,     7,EError,     4,     3,EError,EError,#00-07 
    EError,EError,EError,EError,EItsMe,EItsMe,EItsMe,EItsMe,#08-0f 
    EItsMe,EItsMe,     6,     6,     6,     6,EError,EError,#10-17 
    6,     6,     6,     6,     6,EItsMe,     6,     6,#18-1f 
    6,     6,     6,     6,     5,     7,     7,EError,#20-27 
    5,     8,     6,     6,EError,     6,     6,     6,#28-2f 
    6,     6,     6,     6,EError,EError,EStart,EStart#30-37 
  ]

  UCS2BECharLenTable = [2, 2, 2, 0, 2, 2]

  UCS2BESMModel = {'classTable' =>  UCS2BE_cls,
		 'classFactor' =>  6,
		 'stateTable' =>  UCS2BE_st,
		 'charLenTable' =>  UCS2BECharLenTable,
		 'name' =>  'UTF-16BE'
  }

  # UCS2-LE

  UCS2LE_cls = [
    0,0,0,0,0,0,0,0,  # 00 - 07 
    0,0,1,0,0,2,0,0,  # 08 - 0f 
    0,0,0,0,0,0,0,0,  # 10 - 17 
    0,0,0,3,0,0,0,0,  # 18 - 1f 
    0,0,0,0,0,0,0,0,  # 20 - 27 
    0,3,3,3,3,3,0,0,  # 28 - 2f 
    0,0,0,0,0,0,0,0,  # 30 - 37 
    0,0,0,0,0,0,0,0,  # 38 - 3f 
    0,0,0,0,0,0,0,0,  # 40 - 47 
    0,0,0,0,0,0,0,0,  # 48 - 4f 
    0,0,0,0,0,0,0,0,  # 50 - 57 
    0,0,0,0,0,0,0,0,  # 58 - 5f 
    0,0,0,0,0,0,0,0,  # 60 - 67 
    0,0,0,0,0,0,0,0,  # 68 - 6f 
    0,0,0,0,0,0,0,0,  # 70 - 77 
    0,0,0,0,0,0,0,0,  # 78 - 7f 
    0,0,0,0,0,0,0,0,  # 80 - 87 
    0,0,0,0,0,0,0,0,  # 88 - 8f 
    0,0,0,0,0,0,0,0,  # 90 - 97 
    0,0,0,0,0,0,0,0,  # 98 - 9f 
    0,0,0,0,0,0,0,0,  # a0 - a7 
    0,0,0,0,0,0,0,0,  # a8 - af 
    0,0,0,0,0,0,0,0,  # b0 - b7 
    0,0,0,0,0,0,0,0,  # b8 - bf 
    0,0,0,0,0,0,0,0,  # c0 - c7 
    0,0,0,0,0,0,0,0,  # c8 - cf 
    0,0,0,0,0,0,0,0,  # d0 - d7 
    0,0,0,0,0,0,0,0,  # d8 - df 
    0,0,0,0,0,0,0,0,  # e0 - e7 
    0,0,0,0,0,0,0,0,  # e8 - ef 
    0,0,0,0,0,0,0,0,  # f0 - f7 
    0,0,0,0,0,0,4,5  # f8 - ff 
  ]

  UCS2LE_st = [
    6,     6,     7,     6,     4,     3,EError,EError,#00-07 
    EError,EError,EError,EError,EItsMe,EItsMe,EItsMe,EItsMe,#08-0f 
    EItsMe,EItsMe,     5,     5,     5,EError,EItsMe,EError,#10-17 
    5,     5,     5,EError,     5,EError,     6,     6,#18-1f 
    7,     6,     8,     8,     5,     5,     5,EError,#20-27 
    5,     5,     5,EError,EError,EError,     5,     5,#28-2f 
    5,     5,     5,EError,     5,EError,EStart,EStart#30-37 
  ]

  UCS2LECharLenTable = [2, 2, 2, 2, 2, 2]

  UCS2LESMModel = {'classTable' =>  UCS2LE_cls,
		 'classFactor' =>  6,
		 'stateTable' =>  UCS2LE_st,
		 'charLenTable' =>  UCS2LECharLenTable,
		 'name' =>  'UTF-16LE'
  }

  # UTF-8

  UTF8_cls = [
    1,1,1,1,1,1,1,1,  # 00 - 07  #allow 0x00 as a legal value
    1,1,1,1,1,1,0,0,  # 08 - 0f 
    1,1,1,1,1,1,1,1,  # 10 - 17 
    1,1,1,0,1,1,1,1,  # 18 - 1f 
    1,1,1,1,1,1,1,1,  # 20 - 27 
    1,1,1,1,1,1,1,1,  # 28 - 2f 
    1,1,1,1,1,1,1,1,  # 30 - 37 
    1,1,1,1,1,1,1,1,  # 38 - 3f 
    1,1,1,1,1,1,1,1,  # 40 - 47 
    1,1,1,1,1,1,1,1,  # 48 - 4f 
    1,1,1,1,1,1,1,1,  # 50 - 57 
    1,1,1,1,1,1,1,1,  # 58 - 5f 
    1,1,1,1,1,1,1,1,  # 60 - 67 
    1,1,1,1,1,1,1,1,  # 68 - 6f 
    1,1,1,1,1,1,1,1,  # 70 - 77 
    1,1,1,1,1,1,1,1,  # 78 - 7f 
    2,2,2,2,3,3,3,3,  # 80 - 87 
    4,4,4,4,4,4,4,4,  # 88 - 8f 
    4,4,4,4,4,4,4,4,  # 90 - 97 
    4,4,4,4,4,4,4,4,  # 98 - 9f 
    5,5,5,5,5,5,5,5,  # a0 - a7 
    5,5,5,5,5,5,5,5,  # a8 - af 
    5,5,5,5,5,5,5,5,  # b0 - b7 
    5,5,5,5,5,5,5,5,  # b8 - bf 
    0,0,6,6,6,6,6,6,  # c0 - c7 
    6,6,6,6,6,6,6,6,  # c8 - cf 
    6,6,6,6,6,6,6,6,  # d0 - d7 
    6,6,6,6,6,6,6,6,  # d8 - df 
    7,8,8,8,8,8,8,8,  # e0 - e7 
    8,8,8,8,8,9,8,8,  # e8 - ef 
    10,11,11,11,11,11,11,11,  # f0 - f7 
    12,13,13,13,14,15,0,0   # f8 - ff 
  ]

  UTF8_st = [ 
    EError,EStart,EError,EError,EError,EError,     12,   10,#00-07 
    9,     11,     8,     7,     6,     5,     4,    3,#08-0f 
    EError,EError,EError,EError,EError,EError,EError,EError,#10-17 
    EError,EError,EError,EError,EError,EError,EError,EError,#18-1f 
    EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,#20-27 
    EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,EItsMe,#28-2f 
    EError,EError,     5,     5,     5,     5,EError,EError,#30-37 
    EError,EError,EError,EError,EError,EError,EError,EError,#38-3f 
    EError,EError,EError,     5,     5,     5,EError,EError,#40-47 
    EError,EError,EError,EError,EError,EError,EError,EError,#48-4f 
    EError,EError,     7,     7,     7,     7,EError,EError,#50-57 
    EError,EError,EError,EError,EError,EError,EError,EError,#58-5f 
    EError,EError,EError,EError,     7,     7,EError,EError,#60-67 
    EError,EError,EError,EError,EError,EError,EError,EError,#68-6f 
    EError,EError,     9,     9,     9,     9,EError,EError,#70-77 
    EError,EError,EError,EError,EError,EError,EError,EError,#78-7f 
    EError,EError,EError,EError,EError,     9,EError,EError,#80-87 
    EError,EError,EError,EError,EError,EError,EError,EError,#88-8f 
    EError,EError,    12,    12,    12,    12,EError,EError,#90-97 
    EError,EError,EError,EError,EError,EError,EError,EError,#98-9f 
    EError,EError,EError,EError,EError,    12,EError,EError,#a0-a7 
    EError,EError,EError,EError,EError,EError,EError,EError,#a8-af 
    EError,EError,    12,    12,    12,EError,EError,EError,#b0-b7 
    EError,EError,EError,EError,EError,EError,EError,EError,#b8-bf 
    EError,EError,EStart,EStart,EStart,EStart,EError,EError,#c0-c7 
    EError,EError,EError,EError,EError,EError,EError,EError#c8-cf 
  ]

  UTF8CharLenTable = [0, 1, 0, 0, 0, 0, 2, 3, 3, 3, 4, 4, 5, 5, 6, 6]

  UTF8SMModel = {'classTable' =>  UTF8_cls,
	       'classFactor' =>  16,
	       'stateTable' =>  UTF8_st,
	       'charLenTable' =>  UTF8CharLenTable,
	       'name' =>  'UTF-8'
  }
end
