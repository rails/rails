# $Id: mysql.rb,v 1.24 2005/02/12 11:37:15 tommy Exp $
#
# Copyright (C) 2003-2005 TOMITA Masahiro
# tommy@tmtm.org
#

class Mysql

  VERSION = "4.0-ruby-0.2.6-plus-changes"

  require "socket"
  require "digest/sha1"

  MAX_PACKET_LENGTH = 256*256*256-1
  MAX_ALLOWED_PACKET = 1024*1024*1024

  MYSQL_UNIX_ADDR = "/tmp/mysql.sock"
  MYSQL_PORT = 3306
  PROTOCOL_VERSION = 10

  SCRAMBLE_LENGTH = 20
  SCRAMBLE_LENGTH_323 = 8

  # Command
  COM_SLEEP		= 0
  COM_QUIT		= 1
  COM_INIT_DB		= 2
  COM_QUERY		= 3
  COM_FIELD_LIST	= 4
  COM_CREATE_DB		= 5
  COM_DROP_DB		= 6
  COM_REFRESH		= 7
  COM_SHUTDOWN		= 8
  COM_STATISTICS	= 9
  COM_PROCESS_INFO	= 10
  COM_CONNECT		= 11
  COM_PROCESS_KILL	= 12
  COM_DEBUG		= 13
  COM_PING		= 14
  COM_TIME		= 15
  COM_DELAYED_INSERT	= 16
  COM_CHANGE_USER	= 17
  COM_BINLOG_DUMP	= 18
  COM_TABLE_DUMP	= 19
  COM_CONNECT_OUT	= 20
  COM_REGISTER_SLAVE	= 21

  # Client flag
  CLIENT_LONG_PASSWORD	= 1
  CLIENT_FOUND_ROWS	= 1 << 1
  CLIENT_LONG_FLAG	= 1 << 2
  CLIENT_CONNECT_WITH_DB= 1 << 3
  CLIENT_NO_SCHEMA	= 1 << 4
  CLIENT_COMPRESS	= 1 << 5
  CLIENT_ODBC		= 1 << 6
  CLIENT_LOCAL_FILES	= 1 << 7
  CLIENT_IGNORE_SPACE	= 1 << 8
  CLIENT_PROTOCOL_41	= 1 << 9
  CLIENT_INTERACTIVE	= 1 << 10
  CLIENT_SSL		= 1 << 11
  CLIENT_IGNORE_SIGPIPE	= 1 << 12
  CLIENT_TRANSACTIONS	= 1 << 13
  CLIENT_RESERVED	= 1 << 14
  CLIENT_SECURE_CONNECTION	= 1 << 15
  CLIENT_CAPABILITIES = CLIENT_LONG_PASSWORD|CLIENT_LONG_FLAG|CLIENT_TRANSACTIONS
  PROTO_AUTH41 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION

  # Connection Option
  OPT_CONNECT_TIMEOUT	= 0
  OPT_COMPRESS		= 1
  OPT_NAMED_PIPE	= 2
  INIT_COMMAND		= 3
  READ_DEFAULT_FILE	= 4
  READ_DEFAULT_GROUP	= 5
  SET_CHARSET_DIR	= 6
  SET_CHARSET_NAME	= 7
  OPT_LOCAL_INFILE	= 8

  # Server Status
  SERVER_STATUS_IN_TRANS	= 1
  SERVER_STATUS_AUTOCOMMIT	= 2

  # Refresh parameter
  REFRESH_GRANT		= 1
  REFRESH_LOG		= 2
  REFRESH_TABLES	= 4
  REFRESH_HOSTS		= 8
  REFRESH_STATUS	= 16
  REFRESH_THREADS	= 32
  REFRESH_SLAVE		= 64
  REFRESH_MASTER	= 128

  def initialize(*args)
    @client_flag = 0
    @max_allowed_packet = MAX_ALLOWED_PACKET
    @query_with_result = true
    @status = :STATUS_READY
    if args[0] != :INIT then
      real_connect(*args)
    end
  end

  def real_connect(host=nil, user=nil, passwd=nil, db=nil, port=nil, socket=nil, flag=nil)
    @server_status = SERVER_STATUS_AUTOCOMMIT
    if (host == nil or host == "localhost") and defined? UNIXSocket then
      unix_socket = socket || ENV["MYSQL_UNIX_PORT"] || MYSQL_UNIX_ADDR
      sock = UNIXSocket::new(unix_socket)
      @host_info = Error::err(Error::CR_LOCALHOST_CONNECTION)
      @unix_socket = unix_socket
    else      
      sock = TCPSocket::new(host, port||ENV["MYSQL_TCP_PORT"]||(Socket::getservbyname("mysql","tcp") rescue MYSQL_PORT))
      @host_info = sprintf Error::err(Error::CR_TCP_CONNECTION), host
    end
    @host = host ? host.dup : nil
    sock.setsockopt Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
    @net = Net::new sock

    a = read
    @protocol_version = a.slice!(0)
    @server_version, a = a.split(/\0/,2)
    @thread_id, @scramble_buff = a.slice!(0,13).unpack("La8")
    if a.size >= 2 then
      @server_capabilities, = a.slice!(0,2).unpack("v")
    end
    if a.size >= 16 then
      @server_language, @server_status = a.slice!(0,3).unpack("cv")
    end

    flag = 0 if flag == nil
    flag |= @client_flag | CLIENT_CAPABILITIES
    flag |= CLIENT_CONNECT_WITH_DB if db

    @pre_411 = (0 == @server_capabilities & PROTO_AUTH41)
    if @pre_411
      data = Net::int2str(flag)+Net::int3str(@max_allowed_packet)+
             (user||"")+"\0"+
                   scramble(passwd, @scramble_buff, @protocol_version==9)
    else
      dummy, @salt2 = a.unpack("a13a12")
      @scramble_buff += @salt2
      flag |= PROTO_AUTH41
      data = Net::int4str(flag) + Net::int4str(@max_allowed_packet) +
             ([8] + Array.new(23, 0)).pack("c24") + (user||"")+"\0"+
             scramble41(passwd, @scramble_buff)
    end

    if db and @server_capabilities & CLIENT_CONNECT_WITH_DB != 0
      data << "\0" if @pre_411
      data << db
      @db = db.dup
    end
    write data
    pkt = read
    handle_auth_fallback(pkt, passwd)
    ObjectSpace.define_finalizer(self, Mysql.finalizer(@net))
    self
  end
  alias :connect :real_connect

  def handle_auth_fallback(pkt, passwd)
    # A packet like this means that we need to send an old-format password
    if pkt.size == 1 and pkt[0] == 254 and
       @server_capabilities & CLIENT_SECURE_CONNECTION != 0 then
      data = scramble(passwd, @scramble_buff, @protocol_version == 9)
      write data + "\0"
      read
    end
  end

  def escape_string(str)
    Mysql::escape_string str
  end
  alias :quote :escape_string

  def get_client_info()
    VERSION
  end
  alias :client_info :get_client_info

  def options(option, arg=nil)
    if option == OPT_LOCAL_INFILE then
      if arg == false or arg == 0 then
	@client_flag &= ~CLIENT_LOCAL_FILES
      else
	@client_flag |= CLIENT_LOCAL_FILES
      end
    else
      raise "not implemented"
    end
  end

  def real_query(query)
    command COM_QUERY, query, true
    read_query_result
    self
  end

  def use_result()
    if @status != :STATUS_GET_RESULT then
      error Error::CR_COMMANDS_OUT_OF_SYNC
    end
    res = Result::new self, @fields, @field_count
    @status = :STATUS_USE_RESULT
    res
  end

  def store_result()
    if @status != :STATUS_GET_RESULT then
      error Error::CR_COMMANDS_OUT_OF_SYNC
    end
    @status = :STATUS_READY
    data = read_rows @field_count
    res = Result::new self, @fields, @field_count, data
    @fields = nil
    @affected_rows = data.length
    res
  end

  def change_user(user="", passwd="", db="")
    if @pre_411
      data = user+"\0"+scramble(passwd, @scramble_buff, @protocol_version==9)+"\0"+db
    else
      data = user+"\0"+scramble41(passwd, @scramble_buff)+db
    end
    pkt = command COM_CHANGE_USER, data
    handle_auth_fallback(pkt, passwd)
    @user = user
    @passwd = passwd
    @db = db
  end

  def character_set_name()
    raise "not implemented"
  end

  def close()
    @status = :STATUS_READY
    command COM_QUIT, nil, true
    @net.close
    self
  end

  def create_db(db)
    command COM_CREATE_DB, db
    self
  end

  def drop_db(db)
    command COM_DROP_DB, db
    self
  end

  def dump_debug_info()
    command COM_DEBUG
    self
  end

  def get_host_info()
    @host_info
  end
  alias :host_info :get_host_info

  def get_proto_info()
    @protocol_version
  end
  alias :proto_info :get_proto_info

  def get_server_info()
    @server_version
  end
  alias :server_info :get_server_info

  def kill(id)
    command COM_PROCESS_KILL, Net::int4str(id)
    self
  end

  def list_dbs(db=nil)
    real_query "show databases #{db}"
    @status = :STATUS_READY
    read_rows(1).flatten
  end

  def list_fields(table, field=nil)
    command COM_FIELD_LIST, "#{table}\0#{field}", true
    if @pre_411
      f = read_rows 6
    else
      f = read_rows 7
    end
    fields = unpack_fields(f, @server_capabilities & CLIENT_LONG_FLAG != 0)
    res = Result::new self, fields, f.length
    res.eof = true
    res
  end

  def list_processes()
    data = command COM_PROCESS_INFO
    @field_count = get_length data
    if @pre_411
      fields = read_rows 5
    else
      fields = read_rows 7
    end
    @fields = unpack_fields(fields, @server_capabilities & CLIENT_LONG_FLAG != 0)
    @status = :STATUS_GET_RESULT
    store_result
  end

  def list_tables(table=nil)
    real_query "show tables #{table}"
    @status = :STATUS_READY
    read_rows(1).flatten
  end

  def ping()
    command COM_PING
    self
  end

  def query(query)
    real_query query
    if not @query_with_result then
      return self
    end
    if @field_count == 0 then
      return nil
    end
    store_result
  end

  def refresh(r)
    command COM_REFRESH, r.chr
    self
  end

  def reload()
    refresh REFRESH_GRANT
    self
  end

  def select_db(db)
    command COM_INIT_DB, db
    @db = db
    self
  end

  def shutdown()
    command COM_SHUTDOWN
    self
  end

  def stat()
    command COM_STATISTICS
  end

  attr_reader :info, :insert_id, :affected_rows, :field_count, :thread_id
  attr_accessor :query_with_result, :status

  def read_one_row(field_count)
    data = read
    if data[0] == 254 and data.length == 1 ## EOF
      return
    elsif data[0] == 254 and data.length == 5
      return
    end
    rec = []
    field_count.times do
      len = get_length data
      if len == nil then
	rec << len
      else
	rec << data.slice!(0,len)
      end
    end
    rec
  end

  def skip_result()
    if @status == :STATUS_USE_RESULT then
      loop do
	data = read
	break if data[0] == 254 and data.length == 1
      end
      @status = :STATUS_READY
    end
  end

  def inspect()
    "#<#{self.class}>"
  end

  private

  def read_query_result()
    data = read
    @field_count = get_length(data)
    if @field_count == nil then		# LOAD DATA LOCAL INFILE
      File::open(data) do |f|
	write f.read
      end
      write ""		# mark EOF
      data = read
      @field_count = get_length(data)
    end
    if @field_count == 0 then
      @affected_rows = get_length(data, true)
      @insert_id = get_length(data, true)
      if @server_capabilities & CLIENT_TRANSACTIONS != 0 then
	a = data.slice!(0,2)
	@server_status = a[0]+a[1]*256
      end
      if data.size > 0 and get_length(data) then
	@info = data
      end
    else
      @extra_info = get_length(data, true)
      if @pre_411
        fields = read_rows(5)
      else
        fields = read_rows(7)
      end
      @fields = unpack_fields(fields, @server_capabilities & CLIENT_LONG_FLAG != 0)
      @status = :STATUS_GET_RESULT
    end
    self
  end

  def unpack_fields(data, long_flag_protocol)
    ret = []
    data.each do |f|
      if @pre_411
        table = org_table = f[0]
        name = f[1]
        length = f[2][0]+f[2][1]*256+f[2][2]*256*256
        type = f[3][0]
        if long_flag_protocol then
          flags = f[4][0]+f[4][1]*256
          decimals = f[4][2]
        else
          flags = f[4][0]
          decimals = f[4][1]
        end
        def_value = f[5]
        max_length = 0
      else
        catalog = f[0]
        db = f[1]
        table = f[2]
        org_table = f[3]
        name = f[4]
        org_name = f[5]
        length = f[6][2]+f[6][3]*256+f[6][4]*256*256
        type = f[6][6]
        flags = f[6][7]+f[6][8]*256
        decimals = f[6][9]
        def_value = ""
        max_length = 0
      end
      ret << Field::new(table, org_table, name, length, type, flags, decimals, def_value, max_length)
    end
    ret
  end

  def read_rows(field_count)
    ret = []
    while rec = read_one_row(field_count) do
      ret << rec
    end
    ret
  end

  def get_length(data, longlong=nil)
    return if data.length == 0
    c = data.slice!(0)
    case c
    when 251
      return nil
    when 252
      a = data.slice!(0,2)
      return a[0]+a[1]*256
    when 253
      a = data.slice!(0,3)
      return a[0]+a[1]*256+a[2]*256**2
    when 254
      a = data.slice!(0,8)
      if longlong then
	return a[0]+a[1]*256+a[2]*256**2+a[3]*256**3+
	  a[4]*256**4+a[5]*256**5+a[6]*256**6+a[7]*256**7
      else
	return a[0]+a[1]*256+a[2]*256**2+a[3]*256**3
      end
    else
      c
    end
  end

  def command(cmd, arg=nil, skip_check=nil)
    unless @net then
      error Error::CR_SERVER_GONE_ERROR
    end
    if @status != :STATUS_READY then
      error Error::CR_COMMANDS_OUT_OF_SYNC
    end
    @net.clear
    write cmd.chr+(arg||"")
    read unless skip_check
  end

  def read()
    unless @net then
      error Error::CR_SERVER_GONE_ERROR
    end
    a = @net.read
    if a[0] == 255 then
      if a.length > 3 then
	@errno = a[1]+a[2]*256
	@error = a[3 .. -1]
      else
	@errno = Error::CR_UNKNOWN_ERROR
	@error = Error::err @errno
      end
      raise Error::new(@errno, @error)
    end
    a
  end

  def write(arg)
    unless @net then
      error Error::CR_SERVER_GONE_ERROR
    end
    @net.write arg
  end

  def hash_password(password)
    nr = 1345345333
    add = 7
    nr2 = 0x12345671
    password.each_byte do |i|
      next if i == 0x20 or i == 9
      nr ^= (((nr & 63) + add) * i) + (nr << 8)
      nr2 += (nr2 << 8) ^ nr
      add += i
    end
    [nr & ((1 << 31) - 1), nr2 & ((1 << 31) - 1)]
  end

  def scramble(password, message, old_ver)
    return "" if password == nil or password == ""
    raise "old version password is not implemented" if old_ver
    hash_pass = hash_password password
    hash_message = hash_password message.slice(0,SCRAMBLE_LENGTH_323)
    rnd = Random::new hash_pass[0] ^ hash_message[0], hash_pass[1] ^ hash_message[1]
    to = []
    1.upto(SCRAMBLE_LENGTH_323) do
      to << ((rnd.rnd*31)+64).floor
    end
    extra = (rnd.rnd*31).floor
    to.map! do |t| (t ^ extra).chr end
    to.join
  end

  def scramble41(password, message)
    return 0x00.chr if password.nil? or password.empty?
    buf = [0x14]
    s1 = Digest::SHA1.new(password).digest
    s2 = Digest::SHA1.new(s1).digest
    x = Digest::SHA1.new(message + s2).digest
    (0..s1.length - 1).each {|i| buf.push(s1[i] ^ x[i])}
    buf.pack("C*")
  end

  def error(errno)
    @errno = errno
    @error = Error::err errno
    raise Error::new(@errno, @error)
  end

  class Result
    def initialize(mysql, fields, field_count, data=nil)
      @handle = mysql
      @fields = fields
      @field_count = field_count
      @data = data
      @current_field = 0
      @current_row = 0
      @eof = false
      @row_count = 0
    end
    attr_accessor :eof

    def data_seek(n)
      @current_row = n
    end

    def fetch_field()
      return if @current_field >= @field_count
      f = @fields[@current_field]
      @current_field += 1
      f
    end

    def fetch_fields()
      @fields
    end

    def fetch_field_direct(n)
      @fields[n]
    end

    def fetch_lengths()
      @data ? @data[@current_row].map{|i| i ? i.length : 0} : @lengths
    end

    def fetch_row()
      if @data then
	if @current_row >= @data.length then
	  @handle.status = :STATUS_READY
	  return
	end
	ret = @data[@current_row]
	@current_row += 1
      else
	return if @eof
	ret = @handle.read_one_row @field_count
	if ret == nil then
	  @eof = true
	  return
	end
	@lengths = ret.map{|i| i ? i.length : 0}
	@row_count += 1
      end
      ret
    end

    def fetch_hash(with_table=nil)
      row = fetch_row
      return if row == nil
      hash = {}
      @fields.each_index do |i|
	f = with_table ? @fields[i].table+"."+@fields[i].name : @fields[i].name
	hash[f] = row[i]
      end
      hash
    end

    def field_seek(n)
      @current_field = n
    end

    def field_tell()
      @current_field
    end

    def free()
      @handle.skip_result
      @handle = @fields = @data = nil
    end

    def num_fields()
      @field_count
    end

    def num_rows()
      @data ? @data.length : @row_count
    end

    def row_seek(n)
      @current_row = n
    end

    def row_tell()
      @current_row
    end

    def each()
      while row = fetch_row do
	yield row
      end
    end

    def each_hash(with_table=nil)
      while hash = fetch_hash(with_table) do
	yield hash
      end
    end

    def inspect()
      "#<#{self.class}>"
    end

  end

  class Field
    # Field type
    TYPE_DECIMAL = 0
    TYPE_TINY = 1
    TYPE_SHORT = 2
    TYPE_LONG = 3
    TYPE_FLOAT = 4
    TYPE_DOUBLE = 5
    TYPE_NULL = 6
    TYPE_TIMESTAMP = 7
    TYPE_LONGLONG = 8
    TYPE_INT24 = 9
    TYPE_DATE = 10
    TYPE_TIME = 11
    TYPE_DATETIME = 12
    TYPE_YEAR = 13
    TYPE_NEWDATE = 14
    TYPE_ENUM = 247
    TYPE_SET = 248
    TYPE_TINY_BLOB = 249
    TYPE_MEDIUM_BLOB = 250
    TYPE_LONG_BLOB = 251
    TYPE_BLOB = 252
    TYPE_VAR_STRING = 253
    TYPE_STRING = 254
    TYPE_GEOMETRY = 255
    TYPE_CHAR = TYPE_TINY
    TYPE_INTERVAL = TYPE_ENUM

    # Flag
    NOT_NULL_FLAG = 1
    PRI_KEY_FLAG = 2
    UNIQUE_KEY_FLAG  = 4
    MULTIPLE_KEY_FLAG  = 8
    BLOB_FLAG = 16
    UNSIGNED_FLAG = 32
    ZEROFILL_FLAG = 64
    BINARY_FLAG = 128
    ENUM_FLAG = 256
    AUTO_INCREMENT_FLAG = 512
    TIMESTAMP_FLAG  = 1024
    SET_FLAG = 2048
    NUM_FLAG = 32768
    PART_KEY_FLAG = 16384
    GROUP_FLAG = 32768
    UNIQUE_FLAG = 65536

    def initialize(table, org_table, name, length, type, flags, decimals, def_value, max_length)
      @table = table
      @org_table = org_table
      @name = name
      @length = length
      @type = type
      @flags = flags
      @decimals = decimals
      @def = def_value
      @max_length = max_length
      if (type <= TYPE_INT24 and (type != TYPE_TIMESTAMP or length == 14 or length == 8)) or type == TYPE_YEAR then
	@flags |= NUM_FLAG
      end
    end
    attr_reader :table, :org_table, :name, :length, :type, :flags, :decimals, :def, :max_length

    def inspect()
      "#<#{self.class}:#{@name}>"
    end
  end

  class Error < StandardError
    # Server Error
    ER_HASHCHK			= 1000
    ER_NISAMCHK			= 1001
    ER_NO			= 1002
    ER_YES			= 1003
    ER_CANT_CREATE_FILE		= 1004
    ER_CANT_CREATE_TABLE	= 1005
    ER_CANT_CREATE_DB		= 1006
    ER_DB_CREATE_EXISTS		= 1007
    ER_DB_DROP_EXISTS		= 1008
    ER_DB_DROP_DELETE		= 1009
    ER_DB_DROP_RMDIR		= 1010
    ER_CANT_DELETE_FILE		= 1011
    ER_CANT_FIND_SYSTEM_REC	= 1012
    ER_CANT_GET_STAT		= 1013
    ER_CANT_GET_WD		= 1014
    ER_CANT_LOCK		= 1015
    ER_CANT_OPEN_FILE		= 1016
    ER_FILE_NOT_FOUND		= 1017
    ER_CANT_READ_DIR		= 1018
    ER_CANT_SET_WD		= 1019
    ER_CHECKREAD		= 1020
    ER_DISK_FULL		= 1021
    ER_DUP_KEY			= 1022
    ER_ERROR_ON_CLOSE		= 1023
    ER_ERROR_ON_READ		= 1024
    ER_ERROR_ON_RENAME		= 1025
    ER_ERROR_ON_WRITE		= 1026
    ER_FILE_USED		= 1027
    ER_FILSORT_ABORT		= 1028
    ER_FORM_NOT_FOUND		= 1029
    ER_GET_ERRNO		= 1030
    ER_ILLEGAL_HA		= 1031
    ER_KEY_NOT_FOUND		= 1032
    ER_NOT_FORM_FILE		= 1033
    ER_NOT_KEYFILE		= 1034
    ER_OLD_KEYFILE		= 1035
    ER_OPEN_AS_READONLY		= 1036
    ER_OUTOFMEMORY		= 1037
    ER_OUT_OF_SORTMEMORY	= 1038
    ER_UNEXPECTED_EOF		= 1039
    ER_CON_COUNT_ERROR		= 1040
    ER_OUT_OF_RESOURCES		= 1041
    ER_BAD_HOST_ERROR		= 1042
    ER_HANDSHAKE_ERROR		= 1043
    ER_DBACCESS_DENIED_ERROR	= 1044
    ER_ACCESS_DENIED_ERROR	= 1045
    ER_NO_DB_ERROR		= 1046
    ER_UNKNOWN_COM_ERROR	= 1047
    ER_BAD_NULL_ERROR		= 1048
    ER_BAD_DB_ERROR		= 1049
    ER_TABLE_EXISTS_ERROR	= 1050
    ER_BAD_TABLE_ERROR		= 1051
    ER_NON_UNIQ_ERROR		= 1052
    ER_SERVER_SHUTDOWN		= 1053
    ER_BAD_FIELD_ERROR		= 1054
    ER_WRONG_FIELD_WITH_GROUP	= 1055
    ER_WRONG_GROUP_FIELD	= 1056
    ER_WRONG_SUM_SELECT		= 1057
    ER_WRONG_VALUE_COUNT	= 1058
    ER_TOO_LONG_IDENT		= 1059
    ER_DUP_FIELDNAME		= 1060
    ER_DUP_KEYNAME		= 1061
    ER_DUP_ENTRY		= 1062
    ER_WRONG_FIELD_SPEC		= 1063
    ER_PARSE_ERROR		= 1064
    ER_EMPTY_QUERY		= 1065
    ER_NONUNIQ_TABLE		= 1066
    ER_INVALID_DEFAULT		= 1067
    ER_MULTIPLE_PRI_KEY		= 1068
    ER_TOO_MANY_KEYS		= 1069
    ER_TOO_MANY_KEY_PARTS	= 1070
    ER_TOO_LONG_KEY		= 1071
    ER_KEY_COLUMN_DOES_NOT_EXITS	= 1072
    ER_BLOB_USED_AS_KEY		= 1073
    ER_TOO_BIG_FIELDLENGTH	= 1074
    ER_WRONG_AUTO_KEY		= 1075
    ER_READY			= 1076
    ER_NORMAL_SHUTDOWN		= 1077
    ER_GOT_SIGNAL		= 1078
    ER_SHUTDOWN_COMPLETE	= 1079
    ER_FORCING_CLOSE		= 1080
    ER_IPSOCK_ERROR		= 1081
    ER_NO_SUCH_INDEX		= 1082
    ER_WRONG_FIELD_TERMINATORS	= 1083
    ER_BLOBS_AND_NO_TERMINATED	= 1084
    ER_TEXTFILE_NOT_READABLE	= 1085
    ER_FILE_EXISTS_ERROR	= 1086
    ER_LOAD_INFO		= 1087
    ER_ALTER_INFO		= 1088
    ER_WRONG_SUB_KEY		= 1089
    ER_CANT_REMOVE_ALL_FIELDS	= 1090
    ER_CANT_DROP_FIELD_OR_KEY	= 1091
    ER_INSERT_INFO		= 1092
    ER_INSERT_TABLE_USED	= 1093
    ER_NO_SUCH_THREAD		= 1094
    ER_KILL_DENIED_ERROR	= 1095
    ER_NO_TABLES_USED		= 1096
    ER_TOO_BIG_SET		= 1097
    ER_NO_UNIQUE_LOGFILE	= 1098
    ER_TABLE_NOT_LOCKED_FOR_WRITE	= 1099
    ER_TABLE_NOT_LOCKED		= 1100
    ER_BLOB_CANT_HAVE_DEFAULT	= 1101
    ER_WRONG_DB_NAME		= 1102
    ER_WRONG_TABLE_NAME		= 1103
    ER_TOO_BIG_SELECT		= 1104
    ER_UNKNOWN_ERROR		= 1105
    ER_UNKNOWN_PROCEDURE	= 1106
    ER_WRONG_PARAMCOUNT_TO_PROCEDURE	= 1107
    ER_WRONG_PARAMETERS_TO_PROCEDURE	= 1108
    ER_UNKNOWN_TABLE		= 1109
    ER_FIELD_SPECIFIED_TWICE	= 1110
    ER_INVALID_GROUP_FUNC_USE	= 1111
    ER_UNSUPPORTED_EXTENSION	= 1112
    ER_TABLE_MUST_HAVE_COLUMNS	= 1113
    ER_RECORD_FILE_FULL		= 1114
    ER_UNKNOWN_CHARACTER_SET	= 1115
    ER_TOO_MANY_TABLES		= 1116
    ER_TOO_MANY_FIELDS		= 1117
    ER_TOO_BIG_ROWSIZE		= 1118
    ER_STACK_OVERRUN		= 1119
    ER_WRONG_OUTER_JOIN		= 1120
    ER_NULL_COLUMN_IN_INDEX	= 1121
    ER_CANT_FIND_UDF		= 1122
    ER_CANT_INITIALIZE_UDF	= 1123
    ER_UDF_NO_PATHS		= 1124
    ER_UDF_EXISTS		= 1125
    ER_CANT_OPEN_LIBRARY	= 1126
    ER_CANT_FIND_DL_ENTRY	= 1127
    ER_FUNCTION_NOT_DEFINED	= 1128
    ER_HOST_IS_BLOCKED		= 1129
    ER_HOST_NOT_PRIVILEGED	= 1130
    ER_PASSWORD_ANONYMOUS_USER	= 1131
    ER_PASSWORD_NOT_ALLOWED	= 1132
    ER_PASSWORD_NO_MATCH	= 1133
    ER_UPDATE_INFO		= 1134
    ER_CANT_CREATE_THREAD	= 1135
    ER_WRONG_VALUE_COUNT_ON_ROW	= 1136
    ER_CANT_REOPEN_TABLE	= 1137
    ER_INVALID_USE_OF_NULL	= 1138
    ER_REGEXP_ERROR		= 1139
    ER_MIX_OF_GROUP_FUNC_AND_FIELDS	= 1140
    ER_NONEXISTING_GRANT	= 1141
    ER_TABLEACCESS_DENIED_ERROR	= 1142
    ER_COLUMNACCESS_DENIED_ERROR	= 1143
    ER_ILLEGAL_GRANT_FOR_TABLE	= 1144
    ER_GRANT_WRONG_HOST_OR_USER	= 1145
    ER_NO_SUCH_TABLE		= 1146
    ER_NONEXISTING_TABLE_GRANT	= 1147
    ER_NOT_ALLOWED_COMMAND	= 1148
    ER_SYNTAX_ERROR		= 1149
    ER_DELAYED_CANT_CHANGE_LOCK	= 1150
    ER_TOO_MANY_DELAYED_THREADS	= 1151
    ER_ABORTING_CONNECTION	= 1152
    ER_NET_PACKET_TOO_LARGE	= 1153
    ER_NET_READ_ERROR_FROM_PIPE	= 1154
    ER_NET_FCNTL_ERROR		= 1155
    ER_NET_PACKETS_OUT_OF_ORDER	= 1156
    ER_NET_UNCOMPRESS_ERROR	= 1157
    ER_NET_READ_ERROR		= 1158
    ER_NET_READ_INTERRUPTED	= 1159
    ER_NET_ERROR_ON_WRITE	= 1160
    ER_NET_WRITE_INTERRUPTED	= 1161
    ER_TOO_LONG_STRING		= 1162
    ER_TABLE_CANT_HANDLE_BLOB	= 1163
    ER_TABLE_CANT_HANDLE_AUTO_INCREMENT	= 1164
    ER_DELAYED_INSERT_TABLE_LOCKED	= 1165
    ER_WRONG_COLUMN_NAME	= 1166
    ER_WRONG_KEY_COLUMN		= 1167
    ER_WRONG_MRG_TABLE		= 1168
    ER_DUP_UNIQUE		= 1169
    ER_BLOB_KEY_WITHOUT_LENGTH	= 1170
    ER_PRIMARY_CANT_HAVE_NULL	= 1171
    ER_TOO_MANY_ROWS		= 1172
    ER_REQUIRES_PRIMARY_KEY	= 1173
    ER_NO_RAID_COMPILED		= 1174
    ER_UPDATE_WITHOUT_KEY_IN_SAFE_MODE	= 1175
    ER_KEY_DOES_NOT_EXITS	= 1176
    ER_CHECK_NO_SUCH_TABLE	= 1177
    ER_CHECK_NOT_IMPLEMENTED	= 1178
    ER_CANT_DO_THIS_DURING_AN_TRANSACTION	= 1179
    ER_ERROR_DURING_COMMIT	= 1180
    ER_ERROR_DURING_ROLLBACK	= 1181
    ER_ERROR_DURING_FLUSH_LOGS	= 1182
    ER_ERROR_DURING_CHECKPOINT	= 1183
    ER_NEW_ABORTING_CONNECTION	= 1184
    ER_DUMP_NOT_IMPLEMENTED   	= 1185
    ER_FLUSH_MASTER_BINLOG_CLOSED	= 1186
    ER_INDEX_REBUILD 		= 1187
    ER_MASTER			= 1188
    ER_MASTER_NET_READ		= 1189
    ER_MASTER_NET_WRITE		= 1190
    ER_FT_MATCHING_KEY_NOT_FOUND	= 1191
    ER_LOCK_OR_ACTIVE_TRANSACTION	= 1192
    ER_UNKNOWN_SYSTEM_VARIABLE	= 1193
    ER_CRASHED_ON_USAGE		= 1194
    ER_CRASHED_ON_REPAIR	= 1195
    ER_WARNING_NOT_COMPLETE_ROLLBACK	= 1196
    ER_TRANS_CACHE_FULL		= 1197
    ER_SLAVE_MUST_STOP		= 1198
    ER_SLAVE_NOT_RUNNING	= 1199
    ER_BAD_SLAVE		= 1200
    ER_MASTER_INFO		= 1201
    ER_SLAVE_THREAD		= 1202
    ER_TOO_MANY_USER_CONNECTIONS	= 1203
    ER_SET_CONSTANTS_ONLY	= 1204
    ER_LOCK_WAIT_TIMEOUT	= 1205
    ER_LOCK_TABLE_FULL		= 1206
    ER_READ_ONLY_TRANSACTION	= 1207
    ER_DROP_DB_WITH_READ_LOCK	= 1208
    ER_CREATE_DB_WITH_READ_LOCK	= 1209
    ER_WRONG_ARGUMENTS		= 1210
    ER_NO_PERMISSION_TO_CREATE_USER	= 1211
    ER_UNION_TABLES_IN_DIFFERENT_DIR	= 1212
    ER_LOCK_DEADLOCK		= 1213
    ER_TABLE_CANT_HANDLE_FULLTEXT	= 1214
    ER_CANNOT_ADD_FOREIGN	= 1215
    ER_NO_REFERENCED_ROW	= 1216
    ER_ROW_IS_REFERENCED	= 1217
    ER_CONNECT_TO_MASTER	= 1218
    ER_QUERY_ON_MASTER		= 1219
    ER_ERROR_WHEN_EXECUTING_COMMAND	= 1220
    ER_WRONG_USAGE		= 1221
    ER_WRONG_NUMBER_OF_COLUMNS_IN_SELECT	= 1222
    ER_CANT_UPDATE_WITH_READLOCK	= 1223
    ER_MIXING_NOT_ALLOWED	= 1224
    ER_DUP_ARGUMENT		= 1225
    ER_USER_LIMIT_REACHED	= 1226
    ER_SPECIFIC_ACCESS_DENIED_ERROR	= 1227
    ER_LOCAL_VARIABLE		= 1228
    ER_GLOBAL_VARIABLE		= 1229
    ER_NO_DEFAULT		= 1230
    ER_WRONG_VALUE_FOR_VAR	= 1231
    ER_WRONG_TYPE_FOR_VAR	= 1232
    ER_VAR_CANT_BE_READ		= 1233
    ER_CANT_USE_OPTION_HERE	= 1234
    ER_NOT_SUPPORTED_YET   	= 1235
    ER_MASTER_FATAL_ERROR_READING_BINLOG	= 1236
    ER_SLAVE_IGNORED_TABLE	= 1237
    ER_ERROR_MESSAGES 		= 238

    # Client Error
    CR_MIN_ERROR		= 2000
    CR_MAX_ERROR		= 2999
    CR_UNKNOWN_ERROR		= 2000
    CR_SOCKET_CREATE_ERROR	= 2001
    CR_CONNECTION_ERROR		= 2002
    CR_CONN_HOST_ERROR		= 2003
    CR_IPSOCK_ERROR		= 2004
    CR_UNKNOWN_HOST		= 2005
    CR_SERVER_GONE_ERROR	= 2006
    CR_VERSION_ERROR		= 2007
    CR_OUT_OF_MEMORY		= 2008
    CR_WRONG_HOST_INFO		= 2009
    CR_LOCALHOST_CONNECTION	= 2010
    CR_TCP_CONNECTION		= 2011
    CR_SERVER_HANDSHAKE_ERR	= 2012
    CR_SERVER_LOST		= 2013
    CR_COMMANDS_OUT_OF_SYNC	= 2014
    CR_NAMEDPIPE_CONNECTION	= 2015
    CR_NAMEDPIPEWAIT_ERROR	= 2016
    CR_NAMEDPIPEOPEN_ERROR	= 2017
    CR_NAMEDPIPESETSTATE_ERROR	= 2018
    CR_CANT_READ_CHARSET	= 2019
    CR_NET_PACKET_TOO_LARGE	= 2020
    CR_EMBEDDED_CONNECTION	= 2021
    CR_PROBE_SLAVE_STATUS	= 2022
    CR_PROBE_SLAVE_HOSTS	= 2023
    CR_PROBE_SLAVE_CONNECT	= 2024
    CR_PROBE_MASTER_CONNECT	= 2025
    CR_SSL_CONNECTION_ERROR	= 2026
    CR_MALFORMED_PACKET		= 2027

    CLIENT_ERRORS = [
      "Unknown MySQL error",
      "Can't create UNIX socket (%d)",
      "Can't connect to local MySQL server through socket '%-.64s' (%d)",
      "Can't connect to MySQL server on '%-.64s' (%d)",
      "Can't create TCP/IP socket (%d)",
      "Unknown MySQL Server Host '%-.64s' (%d)",
      "MySQL server has gone away",
      "Protocol mismatch. Server Version = %d Client Version = %d",
      "MySQL client run out of memory",
      "Wrong host info",
      "Localhost via UNIX socket",
      "%-.64s via TCP/IP",
      "Error in server handshake",
      "Lost connection to MySQL server during query",
      "Commands out of sync;  You can't run this command now",
      "%-.64s via named pipe",
      "Can't wait for named pipe to host: %-.64s  pipe: %-.32s (%lu)",
      "Can't open named pipe to host: %-.64s  pipe: %-.32s (%lu)",
      "Can't set state of named pipe to host: %-.64s  pipe: %-.32s (%lu)",
      "Can't initialize character set %-.64s (path: %-.64s)",
      "Got packet bigger than 'max_allowed_packet'",
      "Embedded server",
      "Error on SHOW SLAVE STATUS:",
      "Error on SHOW SLAVE HOSTS:",
      "Error connecting to slave:",
      "Error connecting to master:",
      "SSL connection error",
      "Malformed packet"
    ]

    def initialize(errno, error)
      @errno = errno
      @error = error
      super error
    end
    attr_reader :errno, :error

    def Error::err(errno)
      CLIENT_ERRORS[errno - Error::CR_MIN_ERROR]
    end
  end

  class Net
    def initialize(sock)
      @sock = sock
      @pkt_nr = 0
    end

    def clear()
      @pkt_nr = 0
    end

    def read()
      buf = []
      len = nil
      @sock.sync = false
      while len == nil or len == MAX_PACKET_LENGTH do
	a = @sock.read(4)
	len = a[0]+a[1]*256+a[2]*256*256
	pkt_nr = a[3]
	if @pkt_nr != pkt_nr then
	  raise "Packets out of order: #{@pkt_nr}<>#{pkt_nr}"
	end
	@pkt_nr = @pkt_nr + 1 & 0xff
	buf << @sock.read(len)
      end
      @sock.sync = true
      buf.join
    rescue
      errno = Error::CR_SERVER_LOST 
      raise Error::new(errno, Error::err(errno)) 
    end
    
    def write(data)
      if data.is_a? Array then
	data = data.join
      end
      @sock.sync = false
      ptr = 0
      while data.length >= MAX_PACKET_LENGTH do
	@sock.write Net::int3str(MAX_PACKET_LENGTH)+@pkt_nr.chr+data[ptr, MAX_PACKET_LENGTH]
	@pkt_nr = @pkt_nr + 1 & 0xff
	ptr += MAX_PACKET_LENGTH
      end
      @sock.write Net::int3str(data.length-ptr)+@pkt_nr.chr+data[ptr .. -1]
      @pkt_nr = @pkt_nr + 1 & 0xff
      @sock.sync = true
      @sock.flush
    rescue
      errno = Error::CR_SERVER_LOST 
      raise Error::new(errno, Error::err(errno)) 
    end

    def close()
      @sock.close
    end

    def Net::int2str(n)
      [n].pack("v")
    end

    def Net::int3str(n)
      [n%256, n>>8].pack("cv")
    end

    def Net::int4str(n)
      [n].pack("V")
    end

  end

  class Random
    def initialize(seed1, seed2)
      @max_value = 0x3FFFFFFF
      @seed1 = seed1 % @max_value
      @seed2 = seed2 % @max_value
    end

    def rnd()
      @seed1 = (@seed1*3+@seed2) % @max_value
      @seed2 = (@seed1+@seed2+33) % @max_value
      @seed1.to_f / @max_value
    end
  end

end

class << Mysql
  def init()
    Mysql::new :INIT
  end

  def real_connect(*args)
    Mysql::new(*args)
  end
  alias :connect :real_connect

  def finalizer(net)
    proc {
      net.clear
      net.write Mysql::COM_QUIT.chr
    }
  end

  def escape_string(str)
    str.gsub(/([\0\n\r\032\'\"\\])/) do
      case $1
      when "\0" then "\\0"
      when "\n" then "\\n"
      when "\r" then "\\r"
      when "\032" then "\\Z"
      else "\\"+$1
      end
    end
  end
  alias :quote :escape_string

  def get_client_info()
    Mysql::VERSION
  end
  alias :client_info :get_client_info

  def debug(str)
    raise "not implemented"
  end
end

#
# for compatibility
#

MysqlRes = Mysql::Result
MysqlField = Mysql::Field
MysqlError = Mysql::Error
