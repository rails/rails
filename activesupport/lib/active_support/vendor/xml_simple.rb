# = XmlSimple
#
# Author::    Maik Schmidt <contact@maik-schmidt.de>
# Copyright:: Copyright (c) 2003-2006 Maik Schmidt
# License::   Distributes under the same terms as Ruby.
#
require 'rexml/document'
require 'stringio'

# Easy API to maintain XML (especially configuration files).
class XmlSimple
  include REXML

  @@VERSION = '1.0.9'

  # A simple cache for XML documents that were already transformed
  # by xml_in.
  class Cache #:nodoc:
    # Creates and initializes a new Cache object.
    def initialize
      @mem_share_cache = {}
      @mem_copy_cache  = {}
    end

    # Saves a data structure into a file.
    # 
    # data::
    #   Data structure to be saved.
    # filename::
    #   Name of the file belonging to the data structure.
    def save_storable(data, filename)
      cache_file = get_cache_filename(filename)
      File.open(cache_file, "w+") { |f| Marshal.dump(data, f) }
    end

    # Restores a data structure from a file. If restoring the data
    # structure failed for any reason, nil will be returned.
    #
    # filename::
    #   Name of the file belonging to the data structure.
    def restore_storable(filename)
      cache_file = get_cache_filename(filename)
      return nil unless File::exist?(cache_file)
      return nil unless File::mtime(cache_file).to_i > File::mtime(filename).to_i
      data = nil
      File.open(cache_file) { |f| data = Marshal.load(f) }
      data
    end

    # Saves a data structure in a shared memory cache.
    #
    # data::
    #   Data structure to be saved.
    # filename::
    #   Name of the file belonging to the data structure.
    def save_mem_share(data, filename)
      @mem_share_cache[filename] = [Time::now.to_i, data]
    end

    # Restores a data structure from a shared memory cache. You
    # should consider these elements as "read only". If restoring
    # the data structure failed for any reason, nil will be
    # returned.
    #
    # filename::
    #   Name of the file belonging to the data structure.
    def restore_mem_share(filename)
      get_from_memory_cache(filename, @mem_share_cache)
    end

    # Copies a data structure to a memory cache.
    #
    # data::
    #   Data structure to be copied.
    # filename::
    #   Name of the file belonging to the data structure.
    def save_mem_copy(data, filename)
      @mem_share_cache[filename] = [Time::now.to_i, Marshal.dump(data)]
    end

    # Restores a data structure from a memory cache. If restoring
    # the data structure failed for any reason, nil will be
    # returned.
    #
    # filename::
    #   Name of the file belonging to the data structure.
    def restore_mem_copy(filename)
      data = get_from_memory_cache(filename, @mem_share_cache)
      data = Marshal.load(data) unless data.nil?
      data
    end

    private

    # Returns the "cache filename" belonging to a filename, i.e.
    # the extension '.xml' in the original filename will be replaced
    # by '.stor'. If filename does not have this extension, '.stor'
    # will be appended.
    #
    # filename::
    #   Filename to get "cache filename" for.
    def get_cache_filename(filename)
      filename.sub(/(\.xml)?$/, '.stor')
    end

    # Returns a cache entry from a memory cache belonging to a
    # certain filename. If no entry could be found for any reason,
    # nil will be returned.
    #
    # filename::
    #   Name of the file the cache entry belongs to.
    # cache::
    #   Memory cache to get entry from.
    def get_from_memory_cache(filename, cache)
      return nil unless cache[filename]
      return nil unless cache[filename][0] > File::mtime(filename).to_i
      return cache[filename][1]
    end
  end

  # Create a "global" cache.
  @@cache = Cache.new

  # Creates and intializes a new XmlSimple object.
  # 
  # defaults::
  #   Default values for options.
  def initialize(defaults = nil)
    unless defaults.nil? || defaults.instance_of?(Hash)
      raise ArgumentError, "Options have to be a Hash."
    end
    @default_options = normalize_option_names(defaults, KNOWN_OPTIONS['in'] & KNOWN_OPTIONS['out'])
    @options = Hash.new
    @_var_values = nil
  end

  # Converts an XML document in the same way as the Perl module XML::Simple.
  #
  # string::
  #   XML source. Could be one of the following:
  #
  #   - nil: Tries to load and parse '<scriptname>.xml'.
  #   - filename: Tries to load and parse filename.
  #   - IO object: Reads from object until EOF is detected and parses result.
  #   - XML string: Parses string.
  #   
  # options::
  #   Options to be used.
  def xml_in(string = nil, options = nil)
    handle_options('in', options)

    # If no XML string or filename was supplied look for scriptname.xml.
    if string.nil?
      string = File::basename($0)
      string.sub!(/\.[^.]+$/, '')
      string += '.xml'

      directory = File::dirname($0)
      @options['searchpath'].unshift(directory) unless directory.nil?
    end

    if string.instance_of?(String)
      if string =~ /<.*?>/m
        @doc = parse(string)
      elsif string == '-'
        @doc = parse($stdin.readlines.to_s)
      else
        filename = find_xml_file(string, @options['searchpath'])

        if @options.has_key?('cache')
          @options['cache'].each { |scheme|
            case(scheme)
            when 'storable'
              content = @@cache.restore_storable(filename)
            when 'mem_share'
              content = @@cache.restore_mem_share(filename)
            when 'mem_copy'
              content = @@cache.restore_mem_copy(filename)
            else
              raise ArgumentError, "Unsupported caching scheme: <#{scheme}>."
            end
            return content if content
          }
        end
        
        @doc = load_xml_file(filename)
      end
    elsif string.kind_of?(IO) || string.kind_of?(StringIO)
      @doc = parse(string.readlines.to_s)
    else
      raise ArgumentError, "Could not parse object of type: <#{string.type}>."
    end

    result = collapse(@doc.root)
    result = @options['keeproot'] ? merge({}, @doc.root.name, result) : result
    put_into_cache(result, filename)
    result
  end

  # This is the functional version of the instance method xml_in.
  def XmlSimple.xml_in(string = nil, options = nil)
    xml_simple = XmlSimple.new
    xml_simple.xml_in(string, options)
  end
  
  # Converts a data structure into an XML document.
  #
  # ref::
  #   Reference to data structure to be converted into XML.
  # options::
  #   Options to be used.
  def xml_out(ref, options = nil)
    handle_options('out', options)
    if ref.instance_of?(Array)
      ref = { @options['anonymoustag'] => ref }
    end

    if @options['keeproot']
      keys = ref.keys
      if keys.size == 1
        ref = ref[keys[0]]
        @options['rootname'] = keys[0]
      end
    elsif @options['rootname'] == ''
      if ref.instance_of?(Hash)
        refsave = ref
        ref = {}
        refsave.each { |key, value|
          if !scalar(value)
            ref[key] = value
          else
            ref[key] = [ value.to_s ]
          end
        }
      end
    end

    @ancestors = []
    xml = value_to_xml(ref, @options['rootname'], '')
    @ancestors = nil

    if @options['xmldeclaration']
      xml = @options['xmldeclaration'] + "\n" + xml
    end

    if @options.has_key?('outputfile')
      if @options['outputfile'].kind_of?(IO)
        return @options['outputfile'].write(xml)
      else
        File.open(@options['outputfile'], "w") { |file| file.write(xml) }
      end
    end
    xml
  end

  # This is the functional version of the instance method xml_out.
  def XmlSimple.xml_out(hash, options = nil)
    xml_simple = XmlSimple.new
    xml_simple.xml_out(hash, options)
  end
  
  private

  # Declare options that are valid for xml_in and xml_out.
  KNOWN_OPTIONS = {
    'in'  => %w(
      keyattr keeproot forcecontent contentkey noattr
      searchpath forcearray suppressempty anonymoustag
      cache grouptags normalisespace normalizespace
      variables varattr keytosymbol
    ),
    'out' => %w(
      keyattr keeproot contentkey noattr rootname
      xmldeclaration outputfile noescape suppressempty
      anonymoustag indent grouptags noindent
    )
  }

  # Define some reasonable defaults.
  DEF_KEY_ATTRIBUTES  = []
  DEF_ROOT_NAME       = 'opt'
  DEF_CONTENT_KEY     = 'content'
  DEF_XML_DECLARATION = "<?xml version='1.0' standalone='yes'?>"
  DEF_ANONYMOUS_TAG   = 'anon'
  DEF_FORCE_ARRAY     = true
  DEF_INDENTATION     = '  '
  DEF_KEY_TO_SYMBOL   = false
  
  # Normalizes option names in a hash, i.e., turns all
  # characters to lower case and removes all underscores.
  # Additionally, this method checks, if an unknown option
  # was used and raises an according exception.
  #
  # options::
  #   Hash to be normalized.
  # known_options::
  #   List of known options.
  def normalize_option_names(options, known_options)
    return nil if options.nil?
    result = Hash.new
    options.each { |key, value|
      lkey = key.downcase
      lkey.gsub!(/_/, '')
      if !known_options.member?(lkey)
        raise ArgumentError, "Unrecognised option: #{lkey}."
      end
      result[lkey] = value
    }
    result
  end
  
  # Merges a set of options with the default options.
  # 
  # direction::
  #  'in':  If options should be handled for xml_in.
  #  'out': If options should be handled for xml_out.
  # options::
  #   Options to be merged with the default options.
  def handle_options(direction, options)
    @options = options || Hash.new

    raise ArgumentError, "Options must be a Hash!" unless @options.instance_of?(Hash)

    unless KNOWN_OPTIONS.has_key?(direction)
      raise ArgumentError, "Unknown direction: <#{direction}>."
    end

    known_options = KNOWN_OPTIONS[direction]
    @options = normalize_option_names(@options, known_options)

    unless @default_options.nil?
      known_options.each { |option|
        unless @options.has_key?(option)
          if @default_options.has_key?(option)
            @options[option] = @default_options[option]
          end
        end
      }
    end

    unless @options.has_key?('noattr')
        @options['noattr'] = false
    end

    if @options.has_key?('rootname')
      @options['rootname'] = '' if @options['rootname'].nil?
    else
      @options['rootname'] = DEF_ROOT_NAME
    end

    if @options.has_key?('xmldeclaration') && @options['xmldeclaration'] == true
      @options['xmldeclaration'] = DEF_XML_DECLARATION
    end

    @options['keytosymbol'] = DEF_KEY_TO_SYMBOL unless @options.has_key?('keytosymbol')

    if @options.has_key?('contentkey')
      if @options['contentkey'] =~ /^-(.*)$/
        @options['contentkey']    = $1
        @options['collapseagain'] = true
      end
    else
      @options['contentkey'] = DEF_CONTENT_KEY
    end

    unless @options.has_key?('normalisespace')
      @options['normalisespace'] = @options['normalizespace']
    end
    @options['normalisespace'] = 0 if @options['normalisespace'].nil?

    if @options.has_key?('searchpath')
      unless @options['searchpath'].instance_of?(Array)
        @options['searchpath'] = [ @options['searchpath'] ]
      end
    else
      @options['searchpath'] = []
    end

    if @options.has_key?('cache') && scalar(@options['cache'])
      @options['cache'] = [ @options['cache'] ]
    end

    @options['anonymoustag'] = DEF_ANONYMOUS_TAG unless @options.has_key?('anonymoustag')

    if !@options.has_key?('indent') || @options['indent'].nil?
      @options['indent'] = DEF_INDENTATION
    end

    @options['indent'] = '' if @options.has_key?('noindent')

    # Special cleanup for 'keyattr' which could be an array or
    # a hash or left to default to array.
    if @options.has_key?('keyattr')
      if !scalar(@options['keyattr'])
        # Convert keyattr => { elem => '+attr' }
        #      to keyattr => { elem => ['attr', '+'] }
        if @options['keyattr'].instance_of?(Hash)
          @options['keyattr'].each { |key, value|
            if value =~ /^([-+])?(.*)$/
              @options['keyattr'][key] = [$2, $1 ? $1 : '']
            end
          }
        elsif !@options['keyattr'].instance_of?(Array)
          raise ArgumentError, "'keyattr' must be String, Hash, or Array!"
        end
      else
        @options['keyattr'] = [ @options['keyattr'] ]
      end
    else
      @options['keyattr'] = DEF_KEY_ATTRIBUTES
    end

    if @options.has_key?('forcearray')
      if @options['forcearray'].instance_of?(Regexp)
        @options['forcearray'] = [ @options['forcearray'] ]
      end

      if @options['forcearray'].instance_of?(Array)
        force_list = @options['forcearray']
        unless force_list.empty?
          @options['forcearray'] = {}
          force_list.each { |tag|
            if tag.instance_of?(Regexp)
              unless @options['forcearray']['_regex'].instance_of?(Array)
                @options['forcearray']['_regex'] = []
              end
              @options['forcearray']['_regex'] << tag
            else
              @options['forcearray'][tag] = true
            end
          }
        else
          @options['forcearray'] = false
        end
      else
        @options['forcearray'] = @options['forcearray'] ? true : false
      end
    else
      @options['forcearray'] = DEF_FORCE_ARRAY
    end

    if @options.has_key?('grouptags') && !@options['grouptags'].instance_of?(Hash)
      raise ArgumentError, "Illegal value for 'GroupTags' option - expected a Hash."
    end

    if @options.has_key?('variables') && !@options['variables'].instance_of?(Hash)
      raise ArgumentError, "Illegal value for 'Variables' option - expected a Hash."
    end

    if @options.has_key?('variables')
      @_var_values = @options['variables']
    elsif @options.has_key?('varattr')
      @_var_values = {}
    end
  end

  # Actually converts an XML document element into a data structure.
  #
  # element::
  #   The document element to be collapsed.
  def collapse(element)
    result = @options['noattr'] ? {} : get_attributes(element)

    if @options['normalisespace'] == 2
      result.each { |k, v| result[k] = normalise_space(v) }
    end

    if element.has_elements?
      element.each_element { |child|
        value = collapse(child)
        if empty(value) && (element.attributes.empty? || @options['noattr'])
          next if @options.has_key?('suppressempty') && @options['suppressempty'] == true
        end
        result = merge(result, child.name, value)
      }
      if has_mixed_content?(element)
        # normalisespace?
        content = element.texts.map { |x| x.to_s }
        content = content[0] if content.size == 1
        result[@options['contentkey']] = content
      end
    elsif element.has_text? # i.e. it has only text.
      return collapse_text_node(result, element)
    end

    # Turn Arrays into Hashes if key fields present.
    count = fold_arrays(result)

    # Disintermediate grouped tags.
    if @options.has_key?('grouptags')
      result.each { |key, value|
        next unless (value.instance_of?(Hash) && (value.size == 1))
        child_key, child_value = value.to_a[0]
        if @options['grouptags'][key] == child_key
          result[key] = child_value
        end
      }
    end
    
    # Fold Hases containing a single anonymous Array up into just the Array.
    if count == 1 
      anonymoustag = @options['anonymoustag']
      if result.has_key?(anonymoustag) && result[anonymoustag].instance_of?(Array)
        return result[anonymoustag]
      end
    end

    if result.empty? && @options.has_key?('suppressempty')
      return @options['suppressempty'] == '' ? '' : nil
    end

    result
  end

  # Collapses a text node and merges it with an existing Hash, if
  # possible.
  # Thanks to Curtis Schofield for reporting a subtle bug.
  #
  # hash::
  #   Hash to merge text node value with, if possible.
  # element::
  #   Text node to be collapsed.
  def collapse_text_node(hash, element)
    value = node_to_text(element)
    if empty(value) && !element.has_attributes?
      return {}
    end

    if element.has_attributes? && !@options['noattr']
      return merge(hash, @options['contentkey'], value)
    else
      if @options['forcecontent']
        return merge(hash, @options['contentkey'], value)
      else
        return value
      end
    end
  end

  # Folds all arrays in a Hash.
  # 
  # hash::
  #   Hash to be folded.
  def fold_arrays(hash)
    fold_amount = 0
    keyattr = @options['keyattr']
    if (keyattr.instance_of?(Array) || keyattr.instance_of?(Hash))
      hash.each { |key, value|
        if value.instance_of?(Array)
          if keyattr.instance_of?(Array)
            hash[key] = fold_array(value)
          else
            hash[key] = fold_array_by_name(key, value)
          end
          fold_amount += 1
        end
      }
    end
    fold_amount
  end

  # Folds an Array to a Hash, if possible. Folding happens
  # according to the content of keyattr, which has to be
  # an array.
  #
  # array::
  #   Array to be folded.
  def fold_array(array)
    hash = Hash.new
    array.each { |x|
      return array unless x.instance_of?(Hash)
      key_matched = false
      @options['keyattr'].each { |key|
        if x.has_key?(key)
          key_matched = true
          value = x[key]
          return array if value.instance_of?(Hash) || value.instance_of?(Array)
          value = normalise_space(value) if @options['normalisespace'] == 1
          x.delete(key)
          hash[value] = x
          break
        end
      }
      return array unless key_matched
    }
    hash = collapse_content(hash) if @options['collapseagain']
    hash
  end
  
  # Folds an Array to a Hash, if possible. Folding happens
  # according to the content of keyattr, which has to be
  # a Hash.
  #
  # name::
  #   Name of the attribute to be folded upon.
  # array::
  #   Array to be folded.
  def fold_array_by_name(name, array)
    return array unless @options['keyattr'].has_key?(name)
    key, flag = @options['keyattr'][name]

    hash = Hash.new
    array.each { |x|
      if x.instance_of?(Hash) && x.has_key?(key)
        value = x[key]
        return array if value.instance_of?(Hash) || value.instance_of?(Array)
        value = normalise_space(value) if @options['normalisespace'] == 1
        hash[value] = x
        hash[value]["-#{key}"] = hash[value][key] if flag == '-'
        hash[value].delete(key) unless flag == '+'
      else
        $stderr.puts("Warning: <#{name}> element has no '#{key}' attribute.")
        return array
      end
    }
    hash = collapse_content(hash) if @options['collapseagain']
    hash
  end

  # Tries to collapse a Hash even more ;-)
  #
  # hash::
  #   Hash to be collapsed again.
  def collapse_content(hash)
    content_key = @options['contentkey']
    hash.each_value { |value|
      return hash unless value.instance_of?(Hash) && value.size == 1 && value.has_key?(content_key)
      hash.each_key { |key| hash[key] = hash[key][content_key] }
    }
    hash
  end
  
  # Adds a new key/value pair to an existing Hash. If the key to be added
  # does already exist and the existing value associated with key is not
  # an Array, it will be converted into an Array. Then the new value is
  # appended to that Array.
  #
  # hash::
  #   Hash to add key/value pair to.
  # key::
  #   Key to be added.
  # value::
  #   Value to be associated with key.
  def merge(hash, key, value)
    if value.instance_of?(String)
      value = normalise_space(value) if @options['normalisespace'] == 2

      # do variable substitutions
      unless @_var_values.nil? || @_var_values.empty?
        value.gsub!(/\$\{(\w+)\}/) { |x| get_var($1) }
      end
      
      # look for variable definitions
      if @options.has_key?('varattr')
        varattr = @options['varattr']
        if hash.has_key?(varattr)
          set_var(hash[varattr], value)
        end
      end
    end
    
    #patch for converting keys to symbols
    if @options.has_key?('keytosymbol')
      if @options['keytosymbol'] == true
        key = key.to_s.downcase.to_sym
      end
    end
    
    if hash.has_key?(key)
      if hash[key].instance_of?(Array)
        hash[key] << value
      else
        hash[key] = [ hash[key], value ]
      end
    elsif value.instance_of?(Array) # Handle anonymous arrays.
      hash[key] = [ value ]
    else
      if force_array?(key)
        hash[key] = [ value ]
      else
        hash[key] = value
      end
    end
    hash
  end
  
  # Checks, if the 'forcearray' option has to be used for
  # a certain key.
  def force_array?(key)
    return false if key == @options['contentkey']
    return true if @options['forcearray'] == true
    forcearray = @options['forcearray']
    if forcearray.instance_of?(Hash)
      return true if forcearray.has_key?(key) 
      return false unless forcearray.has_key?('_regex')
      forcearray['_regex'].each { |x| return true if key =~ x }
    end
    return false
  end
  
  # Converts the attributes array of a document node into a Hash.
  # Returns an empty Hash, if node has no attributes.
  #
  # node::
  #   Document node to extract attributes from.
  def get_attributes(node)
    attributes = {}
    node.attributes.each { |n,v| attributes[n] = v }
    attributes
  end
  
  # Determines, if a document element has mixed content.
  #
  # element::
  #   Document element to be checked.
  def has_mixed_content?(element)
    if element.has_text? && element.has_elements?
      return true if element.texts.join('') !~ /^\s*$/s
    end
    false
  end
  
  # Called when a variable definition is encountered in the XML.
  # A variable definition looks like
  #    <element attrname="name">value</element>
  # where attrname matches the varattr setting.
  def set_var(name, value)
    @_var_values[name] = value
  end

  # Called during variable substitution to get the value for the
  # named variable.
  def get_var(name)
    if @_var_values.has_key?(name)
      return @_var_values[name]
    else
      return "${#{name}}"
    end
  end
  
  # Recurses through a data structure building up and returning an
  # XML representation of that structure as a string.
  #
  # ref::
  #   Reference to the data structure to be encoded.
  # name::
  #   The XML tag name to be used for this item.
  # indent::
  #   A string of spaces for use as the current indent level.
  def value_to_xml(ref, name, indent)
    named = !name.nil? && name != ''
    nl    = @options.has_key?('noindent') ? '' : "\n"

    if !scalar(ref)
      if @ancestors.member?(ref)
        raise ArgumentError, "Circular data structures not supported!"
      end
      @ancestors << ref
    else
      if named
        return [indent, '<', name, '>', @options['noescape'] ? ref.to_s : escape_value(ref.to_s), '</', name, '>', nl].join('')
      else
        return ref.to_s + nl
      end
    end

    # Unfold hash to array if possible.
    if ref.instance_of?(Hash) && !ref.empty? && !@options['keyattr'].empty? && indent != ''
      ref = hash_to_array(name, ref)
    end

    result = []
    if ref.instance_of?(Hash)
      # Reintermediate grouped values if applicable.
      if @options.has_key?('grouptags')
        ref.each { |key, value|
          if @options['grouptags'].has_key?(key)
            ref[key] = { @options['grouptags'][key] => value }
          end
        }
      end
      
      nested = []
      text_content = nil
      if named
        result << indent << '<' << name
      end

      if !ref.empty?
        ref.each { |key, value|
          next if !key.nil? && key[0, 1] == '-'
          if value.nil?
            unless @options.has_key?('suppressempty') && @options['suppressempty'].nil?
              raise ArgumentError, "Use of uninitialized value!"
            end
            value = {}
          end

          if !scalar(value) || @options['noattr']
            nested << value_to_xml(value, key, indent + @options['indent'])
          else
            value = value.to_s
            value = escape_value(value) unless @options['noescape']
            if key == @options['contentkey']
              text_content = value
            else
              result << ' ' << key << '="' << value << '"'
            end
          end
        }
      else
        text_content = ''
      end

      if !nested.empty? || !text_content.nil?
        if named
          result << '>'
          if !text_content.nil?
            result << text_content
            nested[0].sub!(/^\s+/, '') if !nested.empty?
          else
            result << nl
          end
          if !nested.empty?
            result << nested << indent
          end
          result << '</' << name << '>' << nl
        else
          result << nested
        end
      else
        result << ' />' << nl
      end
    elsif ref.instance_of?(Array)
      ref.each { |value|
        if scalar(value)
          result << indent << '<' << name << '>'
          result << (@options['noescape'] ? value.to_s : escape_value(value.to_s))
          result << '</' << name << '>' << nl
        elsif value.instance_of?(Hash)
          result << value_to_xml(value, name, indent)
        else
          result << indent << '<' << name << '>' << nl
          result << value_to_xml(value, @options['anonymoustag'], indent + @options['indent'])
          result << indent << '</' << name << '>' << nl
        end
      }
    else
      # Probably, this is obsolete.
      raise ArgumentError, "Can't encode a value of type: #{ref.type}."
    end
    @ancestors.pop if !scalar(ref)
    result.join('')
  end
  
  # Checks, if a certain value is a "scalar" value. Whatever
  # that will be in Ruby ... ;-)
  # 
  # value::
  #   Value to be checked.
  def scalar(value)
    return false if value.instance_of?(Hash) || value.instance_of?(Array)
    return true
  end

  # Attempts to unfold a hash of hashes into an array of hashes. Returns
  # a reference to th array on success or the original hash, if unfolding
  # is not possible.
  # 
  # parent::
  #   
  # hashref::
  #   Reference to the hash to be unfolded.
  def hash_to_array(parent, hashref)
    arrayref = []
    hashref.each { |key, value|
      return hashref unless value.instance_of?(Hash)

      if @options['keyattr'].instance_of?(Hash)
        return hashref unless @options['keyattr'].has_key?(parent)
        arrayref << { @options['keyattr'][parent][0] => key }.update(value)
      else
        arrayref << { @options['keyattr'][0] => key }.update(value)
      end
    }
    arrayref
  end
  
  # Replaces XML markup characters by their external entities.
  #
  # data::
  #   The string to be escaped.
  def escape_value(data)
    Text::normalize(data)
  end
  
  # Removes leading and trailing whitespace and sequences of
  # whitespaces from a string.
  #
  # text::
  #   String to be normalised.
  def normalise_space(text)
    text.strip.gsub(/\s\s+/, ' ')
  end

  # Checks, if an object is nil, an empty String or an empty Hash.
  # Thanks to Norbert Gawor for a bugfix.
  #
  # value::
  #   Value to be checked for emptyness.
  def empty(value)
    case value
      when Hash
        return value.empty?
      when String
        return value !~ /\S/m
      else
        return value.nil?
    end
  end
  
  # Converts a document node into a String.
  # If the node could not be converted into a String
  # for any reason, default will be returned.
  #
  # node::
  #   Document node to be converted.
  # default::
  #   Value to be returned, if node could not be converted.
  def node_to_text(node, default = nil)
    if node.instance_of?(REXML::Element) 
      node.texts.map { |t| t.value }.join('')
    elsif node.instance_of?(REXML::Attribute)
      node.value.nil? ? default : node.value.strip
    elsif node.instance_of?(REXML::Text)
      node.value.strip
    else
      default
    end
  end

  # Parses an XML string and returns the according document.
  #
  # xml_string::
  #   XML string to be parsed.
  #
  # The following exception may be raised:
  #
  # REXML::ParseException::
  #   If the specified file is not wellformed.
  def parse(xml_string)
    Document.new(xml_string)
  end
  
  # Searches in a list of paths for a certain file. Returns
  # the full path to the file, if it could be found. Otherwise,
  # an exception will be raised.
  #
  # filename::
  #   Name of the file to search for.
  # searchpath::
  #   List of paths to search in.
  def find_xml_file(file, searchpath)
    filename = File::basename(file)

    if filename != file
      return file if File::file?(file)
    else
      searchpath.each { |path|
        full_path = File::join(path, filename)
        return full_path if File::file?(full_path)
      }
    end

    if searchpath.empty?
      return file if File::file?(file)
      raise ArgumentError, "File does not exist: #{file}."
    end
    raise ArgumentError, "Could not find <#{filename}> in <#{searchpath.join(':')}>"
  end
  
  # Loads and parses an XML configuration file.
  #
  # filename::
  #   Name of the configuration file to be loaded.
  #
  # The following exceptions may be raised:
  # 
  # Errno::ENOENT::
  #   If the specified file does not exist.
  # REXML::ParseException::
  #   If the specified file is not wellformed.
  def load_xml_file(filename)
    parse(File.readlines(filename).to_s)
  end

  # Caches the data belonging to a certain file.
  #
  # data::
  #   Data to be cached.
  # filename::
  #   Name of file the data was read from.
  def put_into_cache(data, filename)
    if @options.has_key?('cache')
      @options['cache'].each { |scheme|
        case(scheme)
        when 'storable'
          @@cache.save_storable(data, filename)
        when 'mem_share'
          @@cache.save_mem_share(data, filename)
        when 'mem_copy'
          @@cache.save_mem_copy(data, filename)
        else
          raise ArgumentError, "Unsupported caching scheme: <#{scheme}>."
        end
      }
    end
  end
end

# vim:sw=2
