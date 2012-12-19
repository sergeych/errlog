# Encoding: utf-8
require 'stringio'

# Copyright (C) 2008 Sergey S. Chernov
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# sergey.chernov@thrift.ru
#

##
# Boss 1.1.1 basic implementation
#
# 1.1.1 version adds support for booelans and removes support for python __reduce__ - based objects
#       as absolutely non portable
#
# 1.1 version changes the way to store bignums in header, now it is
#     encoded <bytes_length> followed by the specified number of bytes
#     LSB first
#
# No object serialization yet, no callables and bound methods - these appear to be
# non portable between platoforms.
#
module Boss
  # Basic types
  TYPE_INT = 0
  TYPE_EXTRA = 1
  TYPE_NINT = 2

  TYPE_TEXT = 3
  TYPE_BIN = 4
  TYPE_CREF = 5
  TYPE_LIST = 6
  TYPE_DICT = 7

  # Extra types:

  DZERO = 0 #: float 0.0
  FZERO = 1 #: double 0.0

  DONE = 2 #: double 1.0
  FONE = 3 #: float 1.0
  DMINUSONE = 4 #: double -1.0
  FMINUSONE = 5 #: float  -1.0

  TFLOAT = 6  #: 32-bit IEEE float
  TDOUBLE = 7 #: 64-bit IEEE float

  TOBJECT = 8    #: object record
  TMETHOD = 9    #: instance method
  TFUNCTION = 10 #: callable function
  TGLOBREF = 11  #: global reference

  TTRUE    = 12
  TFALSE   = 13
  # TBOOLEAN = 12
  # TREDOBJECT = 12#: __reduce__ - based object, python only, do not use elsewhere!
  def checkArg(cond,msg=nil)
    raise ArgumentError unless cond
  end

  ##
  # Formats ruby object hierarchies with BOSS
  # notation
  #
  class Formatter

    include Boss # for checkArg

    ##
    # Construct formatter for a given IO-like object
    # or create StringIO one as output
    #
    def initialize(dst=nil)
      @io = dst ? dst : StringIO.new
      @cache = { nil => 0 }
    end

    ##
    # Put object tree routed as ob to the output.
    # Alias: <<. It is possible to put more than one
    # object to the same Formatter. Not that formatter
    # has per-instance cache so put(x) put(x) put(x)
    # will store one object and 2 more refs to it, so
    # on load time only one object will be constructed and
    # 2 more refs will be creted.
    def put(ob)
      case ob
      when Fixnum,Bignum
        if ob < 0
          whdr TYPE_NINT, -ob
        else
          whdr TYPE_INT, ob
        end
      when String
        if notCached(ob)
          if ob.encoding == Encoding::BINARY
            whdr TYPE_BIN, ob.length
            wbin ob
          else
            whdr TYPE_TEXT, ob.bytesize
            wbin ob.dup.encode(Encoding::UTF_8)
          end
        end
      when Array
        if notCached(ob)
          whdr TYPE_LIST, ob.length
          ob.each { |x| put(x) }
        end
      when Hash
        if notCached(ob)
          whdr TYPE_DICT, ob.length
          ob.each { |k,v| self << k << v }
        end
      when Float
        whdr TYPE_EXTRA, TDOUBLE
        wdouble ob
      when TrueClass, FalseClass
        whdr TYPE_EXTRA, ob ? TTRUE : TFALSE
      when nil
        whdr TYPE_CREF, 0
      else
        error = "error: not supported object: #{ob}, #{ob.class}"
        p error
        raise NotSupportedException, error
      end
      self
    end

    alias << put

    ##
    # Get the result as string, may not work if
    # some specific IO instance is passsed to constructor.
    # works well with default contructor or StringIO
    def string
      #      p "string!! #{@io.string}"
      @io.string
    end

    private

    ##
    # Write cache ref if the object is cached, and return true
    # otherwise store object in the cache. Caller should
    # write object to @io if notCached return true, and skip
    # writing otherwise
    def notCached(obj)
      n = @cache[obj]
      if n
        whdr TYPE_CREF, n
        false
      else
        @cache[obj] = @cache.length
        true
      end
    end

    ##
    # Write variable-length positive integer
    def wrenc(value)
      checkArg value >= 0
      while value > 0x7f
        wbyte value & 0x7f
        value >>= 7
      end
      wbyte value | 0x80
    end

    ##
    # write standard record header with code and value
    #
    def whdr(code,value)
      checkArg code.between?(0, 7)
      checkArg value >= 0
      #      p "WHDR #{code}, #{value}"
      if value < 23
        wbyte code | value<<3
      else
        # Get the size of the value (0..9)
        if (n=sizeBytes(value)) < 9
          wbyte code | (n+22) << 3
        else
          wbyte code | 0xF8
          wrenc n
        end
        n.times { wbyte value & 0xff; value >>=8 }
      end
    end

    ##
    # Determine minimum amount of bytes needed to
    # store value (should be positive integer)
    def sizeBytes(value)
      checkArg value >= 0
      mval = 0x100
      cnt = 1
      while value >= mval
        cnt += 1
        mval <<= 8
      end
      cnt
    end

    ##
    # write binary value
    #
    def wbin(bb)
      @io.syswrite bb
    end

    ##
    # write single byte
    def wbyte(b)
      @io.putc(b.chr)
    end

    def wdouble val
      wbin [val].pack('E')
    end


  end

  ##
  # Parser incapsulates IO-like cource and provides deserializing of
  # BOSS objects. Parser can store multiple root objects and share same
  # object cache for all them
  class Parser

    include Enumerable

    ##
    # construct parser to read from the given string or IO-like
    # object
    def initialize(src=nil)
      @io = src.class <= String ? StringIO.new(src) : src
      @io.set_encoding Encoding::BINARY
      @cache = [nil]
    end

    ##
    # Load the object (object tree) from the stream. Note that if there
    # is more than one object in the stream that are stored with the same
    # Formatter instance, they will share same cache and references,
    # see Boss.Formatter.put for details.
    # Note that nil is a valid restored object. Check eof? or catch
    # EOFError, or use Boss.Parser.each to read all objects from the stream
    def get
      code, value = rhdr
      case code
      when TYPE_INT
        return value
      when TYPE_NINT
        return -value
      when TYPE_TEXT, TYPE_BIN
        s = rbin value
        s.force_encoding code == TYPE_BIN ? Encoding::BINARY : Encoding::UTF_8
        @cache << s
        return s
      when TYPE_LIST
        #        p "items", value
        @cache << (list = [])
        value.times { list << get }
        return list
      when TYPE_DICT
        @cache << (dict = {})
        value.times { dict[get] = get }
        return dict
      when TYPE_CREF
        return @cache[value]
      end
    end

    ##
    # True is underlying IO-like object reached its end.
    def eof?
      @io.eof?
    end

    ##
    # yields all objects in the stream
    def each
      @io.rewind
      yield get until eof?
    end

    private

    ##
    # Read header and return code,value
    def rhdr
      b = rbyte
      code, value = b & 7, b >> 3
      case value
      when 0..22
        return code, value
      when 23...31
        return code, rlongint(value-22)
      else
        n = renc
        return code, rlongint(n)
      end
    end

    ##
    # read n-bytes long positive integer
    def rlongint(bytes)
      res = i = 0
      bytes.times do
        res |= rbyte << i
        i += 8
      end
      res
    end

    ##
    # Read variable-length positive integer
    def renc
      value = i = 0
      loop do
        x = rbyte
        value |= (x&0x7f) << i
        return value if x & 0x80 != 0
        i += 7
      end
    end

    def rbyte
      @io.readbyte
    end

    def rbin(length)
      @io.sysread length
    end
  end

  ##
  # If block is given, yields all objects from the
  # src (that can be either string or IO), passes it to the block and stores
  # what block returns in the array, unless block returns nil. The array
  # is then returned.
  #
  # Otherwise, reads and return first object from src
  def Boss.load(src)
    p = Parser.new(src)
    if block_given?
      res = []
      res << yield(p.get) while !p.eof?
      res
    else
      p.get
    end
  end

  # Load all objects from the src and return them as an array
  def Boss.load_all src
    p = Parser.new(src)
    res = []
    res << p.get while !p.eof?
    res
  end

  ##
  # convert all arguments into successive BOSS encoeded
  # object, so all them will share same global reference
  # cache.
  def Boss.dump(*roots)
    f = f = Formatter.new
    roots.each { |r| f << r }
    f.string
  end

end

