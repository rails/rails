#
# mysq411.rb - 0.1 - Matt Mower <self@mattmower.com>
#
# The native Ruby MySQL client (mysql.rb) by Tomita Masahiro does not (yet) handle the new MySQL
# protocol introduced in MySQL 4.1.1. This protocol introduces a new authentication scheme as
# well as modifications to the client/server exchanges themselves.
#
# mysql411.rb modifies the Mysql class to add MySQL 4.1.x support.  It modifies the connection
# algorithm to detect a 4.1.1 server and respond with the new authentication scheme, otherwise using
# the original one.  Similarly for the changes to packet structures and field definitions, etc...
#
# It redefines serveral methods which behave differently depending upon the server context. The
# way I have implemented this is to alias the old method, create a new alternative method, and redefine
# the original method as a selector which calls the appropriate method based upon the server version.
# There may have been a neater way to do this.
#
# In general I've tried not to change the original code any more than necessary, i.e. even where I
# redefine a method I have made the smallest number of changes possible, rather than rewriting from
# scratch.
#
# *Caveat Lector* This code passes all current ActiveRecord unit tests however this is no guarantee that
# full & correct MySQL 4.1 support has been achieved.
# 

require 'digest/sha1'

#
# Extend the Mysql class to work with MySQL 4.1.1+ servers.  After version
# 4.1.1 the password hashing function (and some other connection details) have
# changed rendering the previous Mysql class unable to connect:
#
#

class Mysql
  CLIENT_PROTOCOL_41 = 512
  CLIENT_SECURE_CONNECTION = 32768
  
  def real_connect( host=nil, user=nil, passwd=nil, db=nil, port=nil, socket=nil, flag=nil )
    @server_status = SERVER_STATUS_AUTOCOMMIT
    
    if( host == nil || host == "localhost" ) && defined? UNIXSocket
      unix_socket = socket || ENV["MYSQL_UNIX_PORT"] || MYSQL_UNIX_ADDR
      sock = UNIXSocket::new( unix_socket )
      @host_info = Error::err( Error::CR_LOCALHOST_CONNECTION )
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

    # Store the version number components for speedy comparison
    version, ostag = @server_version.split( /-/, 2 )
    @major_ver, @minor_ver, @revision_num = version.split( /\./ ).map { |v| v.to_i }
    
    @thread_id, @scramble_buff = a.slice!(0,13).unpack("La8")
    if a.size >= 2 then
      @server_capabilities, = a.slice!(0,2).unpack("v")
    end
    if a.size >= 16 then
      @server_language, @server_status = a.unpack("cv")
    end
    
    # Set the flags we'll send back to the server
    flag = 0 if flag == nil
    flag |= @client_flag | CLIENT_CAPABILITIES
    flag |= CLIENT_CONNECT_WITH_DB if db
    
    if version_meets_minimum?( 4, 1, 1 )
      # In 4.1.1+ the seed comes in two parts which must be combined
      a.slice!( 0, 16 )
      seed_part_2 = a.slice!( 0, 12 );      
      @scramble_buff << seed_part_2
      
      flag |= CLIENT_FOUND_ROWS
      flag |= CLIENT_PROTOCOL_41
      flag |= CLIENT_SECURE_CONNECTION if @server_capabilities & CLIENT_SECURE_CONNECTION;
      
      if db && @server_capabilities & CLIENT_CONNECT_WITH_DB != 0
        @db = db.dup
      end
      
      scrambled_password = scramble411( passwd, @scramble_buff, @protocol_version==9 )
      data = make_client_auth_packet_41( flag, user, scrambled_password, db )
    else
      scrambled_password = scramble( passwd, @scramble_buff, @protocol_version == 9 )
      data = Net::int2str(flag)+Net::int3str(@max_allowed_packet)+(user||"")+"\0"+scrambled_password
      if db and @server_capabilities & CLIENT_CONNECT_WITH_DB != 0 then
        data << "\0"+db
        @db = db.dup
      end
    end
    
    write data
    read
    self
  end
  alias :connect :real_connect
  
  # Pack the authentication information into depending upon whether an initial database has
  # been specified
  def make_client_auth_packet_41( flag, user, password, db )
    if db && @server_capabilities & CLIENT_CONNECT_WITH_DB != 0
      template = "VVcx23a#{user.size+1}cA#{password.size}a#{db.size+1}"
    else
      template = "VVcx23a#{user.size+1}cA#{password.size}x"
    end
    
    [ flag, @max_allowed_packet, @server_language, user, password.size, password, db ].pack( template )
  end
  
  def version_meets_minimum?( major, minor, revision )
    @major_ver >= major && @minor_ver >= minor && @revision_num >= revision
  end
  
  # SERVER:  public_seed=create_random_string()
  #          send(public_seed)
  #
  # CLIENT:  recv(public_seed)
  #          hash_stage1=sha1("password")
  #          hash_stage2=sha1(hash_stage1)
  #          reply=xor(hash_stage1, sha1(public_seed,hash_stage2)
  #
  #          #this three steps are done in scramble()
  #
  #          send(reply)
  #
  #
  # SERVER:  recv(reply)
  #          hash_stage1=xor(reply, sha1(public_seed,hash_stage2))
  #          candidate_hash2=sha1(hash_stage1)
  #          check(candidate_hash2==hash_stage2)
  def scramble411( password, seed, old_ver )
    return "" if password == nil or password == ""
    raise "old version password is not implemented" if old_ver
    
    #    print "Seed Bytes = "
    #    seed.each_byte { |b| print "0x#{b.to_s( 16 )}, " }
    #    puts
    
    stage1 = Digest::SHA1.digest( password )
    stage2 = Digest::SHA1.digest( stage1 )
    
    dgst = Digest::SHA1.new
    dgst << seed
    dgst << stage2
    stage3 = dgst.digest
    
    #    stage1.zip( stage3 ).map { |a, b| (a ^ b).chr }.join
    scrambled = ( 0 ... stage3.size ).map { |i| stage3[i] ^ stage1[i] }
    scrambled = scrambled.map { |x| x.chr }
    scrambled.join
  end
  
  def change_user(user="", passwd="", db="")
    scrambled_password = version_meets_minimum?( 4, 1, 1 ) ? scramble411( passwd, @scramble_buff, @protocol_version==9 ) : scramble( passwd, @scramble_buff, @protocol_version==9 )
    data = user+"\0"+scrambled_password+"\0"+db
    command COM_CHANGE_USER, data
    @user = user
    @passwd = passwd
    @db = db
  end
  
  #
  # The 4.1 protocol changed the length of the END packet
  #
  alias_method :old_read_one_row, :read_one_row

  def read_one_row( field_count )
    if version_meets_minimum?( 4, 1, 1 )
      read_one_row_41( field_count )
    else
      old_read_one_row( field_count )
    end
  end

  def read_one_row_41( field_count )
    data = read
    return if data[0] == 254 and data.length < 9
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
  
  #
  # The 4.1 protocol changed the length of the END packet
  #
  alias_method :old_skip_result, :skip_result
  
  def skip_result
    if version_meets_minimum?( 4, 1, 1 )
      skip_result_41
    else
      old_skip_result
    end
  end
  
  def skip_result_41()
    if @status == :STATUS_USE_RESULT then
      loop do
	data = read
	break if data[0] == 254 and data.length == 1
      end
      @status = :STATUS_READY
    end
  end
  
  # The field description structure is changed for the 4.1 protocol passing
  # more data and a different packing form.  NOTE: The 4.1 protocol now passes
  # back a "catalog" name for each field which is a new feature.  Since AR has
  # nowhere to put it I'm throwing it away.  Possibly this is not the best
  # idea?
  #
  alias_method :old_unpack_fields, :unpack_fields
  
  def unpack_fields( data, long_flag_protocol )
    if version_meets_minimum?( 4, 1, 1 )
      unpack_fields_41( data, long_flag_protocol )
    else
      old_unpack_fields( data, long_flag_protocol )
    end
  end
  
  def unpack_fields_41( data, long_flag_protocol )
    ret = []
    
    data.each do |f|
      catalog_name = f[0]
      database_name = f[1]
      table_name_alias = f[2]
      table_name = f[3]
      column_name_alias = f[4]
      column_name = f[5]
      
      charset = f[6][0] + f[6][1]*256
      length = f[6][2] + f[6][3]*256 + f[6][4]*256*256 + f[6][5]*256*256*256
      type = f[6][6]
      flags = f[6][7] + f[6][8]*256
      decimals = f[6][9]
      def_value = f[7]
      max_length = 0
      
      ret << Field::new(table_name, table_name, column_name_alias, length, type, flags, decimals, def_value, max_length)
    end
    ret
  end

  # In this instance the read_query_result method in mysql is bound to read 5 field parameters which
  # is expanded to 7 in the 4.1 protocol.  So in this case we redefine this entire method in order
  # to write "read_rows 7" instead of "read_rows 5"!
  #
  alias_method :old_read_query_result, :read_query_result
  
  def read_query_result
    if version_meets_minimum?( 4, 1, 1 )
      read_query_result_41
    else
      old_read_query_result
    end
  end
  
  def read_query_result_41
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
      fields = read_rows 7
      @fields = unpack_fields(fields, @server_capabilities & CLIENT_LONG_FLAG != 0)
      @status = :STATUS_GET_RESULT
    end
    self
  end


  # Get rid of GC.start in #free.
  class Result
    def free
      @handle.skip_result
      @handle = @fields = @data = nil
    end
  end
end
