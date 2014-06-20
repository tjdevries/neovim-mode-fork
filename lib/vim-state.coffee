_ = require 'underscore-plus'
{$} = require 'atom'

Operators = require './operators/index'
Prefixes = require './prefixes'
Motions = require './motions/index'

TextObjects = require './text-objects'
Utils = require './utils'
Panes = require './panes'
Scroll = require './scroll'
{$$, Point, Range} = require 'atom'
Marker = require 'atom'
net = require 'net'
map = require './mapped'
Buffer = require("buffer").Buffer

bops_readUInt8 = (target, at) ->
  target[at]
bops_readInt8 = (target, at) ->
  v = target[at]
  (if v < 0x80 then v else v - 0x100)
bops_readUInt16LE = (target, at) ->
  dv = map.get(target)
  dv.getUint16 at + target.byteOffset, true
bops_readUInt32LE = (target, at) ->
  dv = map.get(target)
  dv.getUint32 at + target.byteOffset, true
bops_readInt16LE = (target, at) ->
  dv = map.get(target)
  dv.getInt16 at + target.byteOffset, true
bops_readInt32LE = (target, at) ->
  dv = map.get(target)
  dv.getInt32 at + target.byteOffset, true
bops_readFloatLE = (target, at) ->
  dv = map.get(target)
  dv.getFloat32 at + target.byteOffset, true
bops_readDoubleLE = (target, at) ->
  dv = map.get(target)
  dv.getFloat64 at + target.byteOffset, true
bops_readUInt16BE = (target, at) ->
  dv = map.get(target)
  dv.getUint16 at + target.byteOffset, false
bops_readUInt32BE = (target, at) ->
  dv = map.get(target)
  dv.getUint32 at + target.byteOffset, false
bops_readInt16BE = (target, at) ->
  dv = map.get(target)
  dv.getInt16 at + target.byteOffset, false
bops_readInt32BE = (target, at) ->
  dv = map.get(target)
  dv.getInt32 at + target.byteOffset, false
bops_readFloatBE = (target, at) ->
  dv = map.get(target)
  dv.getFloat32 at + target.byteOffset, false
bops_readDoubleBE = (target, at) ->
  dv = map.get(target)
  dv.getFloat64 at + target.byteOffset, false
bops_writeUInt8 = (target, value, at) ->
  target[at] = value
bops_writeInt8 = (target, value, at) ->
  target[at] = (if value < 0 then value + 0x100 else value)
bops_writeUInt16LE = (target, value, at) ->
  dv = map.get(target)
  dv.setUint16 at + target.byteOffset, value, true
bops_writeUInt32LE = (target, value, at) ->
  dv = map.get(target)
  dv.setUint32 at + target.byteOffset, value, true
bops_writeInt16LE = (target, value, at) ->
  dv = map.get(target)
  dv.setInt16 at + target.byteOffset, value, true
bops_writeInt32LE = (target, value, at) ->
  dv = map.get(target)
  dv.setInt32 at + target.byteOffset, value, true
bops_writeFloatLE = (target, value, at) ->
  dv = map.get(target)
  dv.setFloat32 at + target.byteOffset, value, true
bops_writeDoubleLE = (target, value, at) ->
  dv = map.get(target)
  dv.setFloat64 at + target.byteOffset, value, true
bops_writeUInt16BE = (target, value, at) ->
  dv = map.get(target)
  dv.setUint16 at + target.byteOffset, value, false
bops_writeUInt32BE = (target, value, at) ->
  dv = map.get(target)
  dv.setUint32 at + target.byteOffset, value, false
bops_writeInt16BE = (target, value, at) ->
  dv = map.get(target)
  dv.setInt16 at + target.byteOffset, value, false
bops_writeInt32BE = (target, value, at) ->
  dv = map.get(target)
  dv.setInt32 at + target.byteOffset, value, false
bops_writeFloatBE = (target, value, at) ->
  dv = map.get(target)
  dv.setFloat32 at + target.byteOffset, value, false
bops_writeDoubleBE = (target, value, at) ->
  dv = map.get(target)
  dv.setFloat64 at + target.byteOffset, value, false

bops_create = (size) ->
  new Buffer(size)

bops_copy = (source, target, target_start, source_start, source_end) ->
  source.copy target, target_start, source_start, source_end

bops_subarray = (source, from, to) ->
  (source.subarray(from, to))

bops_to = (source, encoding) ->
  source.toString encoding

bops_from = (source, encoding) ->
  new Buffer(source, encoding)
bops_is = (buffer) ->
  Buffer.isBuffer buffer

encode_pub = (value) ->
  toJSONed = []
  size = sizeof(value)
  return `undefined`  if size is 0
  buffer = bops_create(size)
  encode value, buffer, 0
  buffer
Decoder = (buffer, offset) ->
  @offset = offset or 0
  @buffer = buffer
  return
Decoder::map = (length) ->
  value = {}
  i = 0

  while i < length
    key = @parse()
    value[key] = @parse()
    i++
  value

Decoder::bin = (length) ->
  value = bops_subarray(@buffer, @offset, @offset + length)
  @offset += length
  value

Decoder::str = (length) ->
  res = ''
  i = 0
  while i < length
    res = res + String.fromCharCode(@buffer[@offset+i])
    i++
  @offset += length
  res

  # value = (bops_subarray(@buffer, @offset, @offset + length))
  # @offset += length
  # value

Decoder::array = (length) ->
  value = new Array(length)
  i = 0

  while i < length
    value[i] = @parse()
    i++
  value

Decoder::parse = ->
  type = @buffer[@offset]
  value = undefined
  length = undefined
  extType = undefined

  # Positive FixInt
  if (type & 0x80) is 0x00
    @offset++
    return type

  # FixMap
  if (type & 0xf0) is 0x80
    length = type & 0x0f
    @offset++
    return @map(length)

  # FixArray
  if (type & 0xf0) is 0x90
    length = type & 0x0f
    @offset++
    return @array(length)

  # FixStr
  if (type & 0xe0) is 0xa0
    length = type & 0x1f
    @offset++
    return @str(length)

  # Negative FixInt
  if (type & 0xe0) is 0xe0
    value = bops_readInt8(@buffer, @offset)
    @offset++
    return value
  switch type

    # nil
    when 0xc0
      @offset++
      return null

    # 0xc1: (never used)
    # false
    when 0xc2
      @offset++
      return false

    # true
    when 0xc3
      @offset++
      return true

    # bin 8
    when 0xc4
      length = bops_readUInt8(@buffer, @offset + 1)
      @offset += 2
      return @bin(length)

    # bin 16
    when 0xc5
      length = bops_readUInt16BE(@buffer, @offset + 1)
      @offset += 3
      return @bin(length)

    # bin 32
    when 0xc6
      length = bops_readUInt32BE(@buffer, @offset + 1)
      @offset += 5
      return @bin(length)

    # ext 8
    when 0xc7
      length = bops_readUInt8(@buffer, @offset + 1)
      extType = bops_readUInt8(@buffer, @offset + 2)
      @offset += 3
      return [
        extType
        @bin(length)
      ]

    # ext 16
    when 0xc8
      length = bops_readUInt16BE(@buffer, @offset + 1)
      extType = bops_readUInt8(@buffer, @offset + 3)
      @offset += 4
      return [
        extType
        @bin(length)
      ]

    # ext 32
    when 0xc9
      length = bops_readUInt32BE(@buffer, @offset + 1)
      extType = bops_readUInt8(@buffer, @offset + 5)
      @offset += 6
      return [
        extType
        @bin(length)
      ]

    # float 32
    when 0xca
      value = bops_readFloatBE(@buffer, @offset + 1)
      @offset += 5
      return value

    # float 64 / double
    when 0xcb
      value = bops_readDoubleBE(@buffer, @offset + 1)
      @offset += 9
      return value

    # uint8
    when 0xcc
      value = @buffer[@offset + 1]
      @offset += 2
      return value

    # uint 16
    when 0xcd
      value = bops_readUInt16BE(@buffer, @offset + 1)
      @offset += 3
      return value

    # uint 32
    when 0xce
      value = bops_readUInt32BE(@buffer, @offset + 1)
      @offset += 5
      return value

    # uint64
    when 0xcf
      value = bops_readUInt64BE(@buffer, @offset + 1)
      @offset += 9
      return value

    # int 8
    when 0xd0
      value = bops_readInt8(@buffer, @offset + 1)
      @offset += 2
      return value

    # int 16
    when 0xd1
      value = bops_readInt16BE(@buffer, @offset + 1)
      @offset += 3
      return value

    # int 32
    when 0xd2
      value = bops_readInt32BE(@buffer, @offset + 1)
      @offset += 5
      return value

    # int 64
    when 0xd3
      value = bops_readInt64BE(@buffer, @offset + 1)
      @offset += 9
      return value

    # fixext 1 / undefined
    when 0xd4
      extType = bops_readUInt8(@buffer, @offset + 1)
      value = bops_readUInt8(@buffer, @offset + 2)
      @offset += 3
      return (if (extType is 0 and value is 0) then `undefined` else [
        extType
        value
      ])

    # fixext 2
    when 0xd5
      extType = bops_readUInt8(@buffer, @offset + 1)
      @offset += 2
      return [
        extType
        @bin(2)
      ]

    # fixext 4
    when 0xd6
      extType = bops_readUInt8(@buffer, @offset + 1)
      @offset += 2
      return [
        extType
        @bin(4)
      ]

    # fixext 8
    when 0xd7
      extType = bops_readUInt8(@buffer, @offset + 1)
      @offset += 2
      return [
        extType
        @bin(8)
      ]

    # fixext 16
    when 0xd8
      extType = bops_readUInt8(@buffer, @offset + 1)
      @offset += 2
      return [
        extType
        @bin(16)
      ]

    # str 8
    when 0xd9
      length = bops_readUInt8(@buffer, @offset + 1)
      @offset += 2
      return @str(length)

    # str 16
    when 0xda
      length = bops_readUInt16BE(@buffer, @offset + 1)
      @offset += 3
      return @str(length)

    # str 32
    when 0xdb
      length = bops_readUInt32BE(@buffer, @offset + 1)
      @offset += 5
      return @str(length)

    # array 16
    when 0xdc
      length = bops_readUInt16BE(@buffer, @offset + 1)
      @offset += 3
      return @array(length)

    # array 32
    when 0xdd
      length = bops_readUInt32BE(@buffer, @offset + 1)
      @offset += 5
      return @array(length)

    # map 16:
    when 0xde
      length = bops_readUInt16BE(@buffer, @offset + 1)
      @offset += 3
      return @map(length)

    # map 32
    when 0xdf
      length = bops_readUInt32BE(@buffer, @offset + 1)
      @offset += 5
      return @map(length)

    # buffer 16
    when 0xd8
      length = bops_readUInt16BE(@buffer, @offset + 1)
      @offset += 3
      return @buf(length)

    # buffer 32
    when 0xd9
      length = bops_readUInt32BE(@buffer, @offset + 1)
      @offset += 5
      return @buf(length)
  throw new Error("Unknown type 0x" + type.toString(16))
  return
decode_pub = (buffer) ->
  decoder = new Decoder(buffer)
  value = decoder.parse()
  # throw new Error((buffer.length - decoder.offset) + " trailing bytes")  if decoder.offset isnt buffer.length
  {value:value, trailing:buffer.length - decoder.offset}

encodeableKeys = (value) ->
  Object.keys(value).filter (e) ->
    "function" isnt typeof value[e] or !!value[e].toJSON

encode = (value, buffer, offset) ->
  type = typeof value
  length = undefined
  size = undefined

  # Strings Bytes
  if type is "string"
    value = bops_from(value)
    length = value.length

    # fixstr
    if length < 0x20
      buffer[offset] = length | 0xa0
      bops_copy value, buffer, offset + 1
      return 1 + length

    # str 8
    if length < 0x100
      buffer[offset] = 0xd9
      bops_writeUInt8 buffer, length, offset + 1
      bops_copy value, buffer, offset + 2
      return 2 + length

    # str 16
    if length < 0x10000
      buffer[offset] = 0xda
      bops_writeUInt16BE buffer, length, offset + 1
      bops_copy value, buffer, offset + 3
      return 3 + length

    # str 32
    if length < 0x100000000
      buffer[offset] = 0xdb
      bops_writeUInt32BE buffer, length, offset + 1
      bops_copy value, buffer, offset + 5
      return 5 + length
  if bops_is(value)
    length = value.length

    # bin 8
    if length < 0x100
      buffer[offset] = 0xc4
      bops_writeUInt8 buffer, length, offset + 1
      bops_copy value, buffer, offset + 2
      return 2 + length

    # bin 16
    if length < 0x10000
      buffer[offset] = 0xd8
      bops_writeUInt16BE buffer, length, offset + 1
      bops_copy value, buffer, offset + 3
      return 3 + length

    # bin 32
    if length < 0x100000000
      buffer[offset] = 0xd9
      bops_writeUInt32BE buffer, length, offset + 1
      bops_copy value, buffer, offset + 5
      return 5 + length
  if type is "number"

    # Floating Point
    if (value << 0) isnt value
      buffer[offset] = 0xcb
      bops_writeDoubleBE buffer, value, offset + 1
      return 9

    # Integers
    if value >= 0

      # positive fixnum
      if value < 0x80
        buffer[offset] = value
        return 1

      # uint 8
      if value < 0x100
        buffer[offset] = 0xcc
        buffer[offset + 1] = value
        return 2

      # uint 16
      if value < 0x10000
        buffer[offset] = 0xcd
        bops_writeUInt16BE buffer, value, offset + 1
        return 3

      # uint 32
      if value < 0x100000000
        buffer[offset] = 0xce
        bops_writeUInt32BE buffer, value, offset + 1
        return 5

      # uint 64
      if value < 0x10000000000000000
        buffer[offset] = 0xcf
        bops_writeUInt64BE buffer, value, offset + 1
        return 9
      throw new Error("Number too big 0x" + value.toString(16))

    # negative fixnum
    if value >= -0x20
      bops_writeInt8 buffer, value, offset
      return 1

    # int 8
    if value >= -0x80
      buffer[offset] = 0xd0
      bops_writeInt8 buffer, value, offset + 1
      return 2

    # int 16
    if value >= -0x8000
      buffer[offset] = 0xd1
      bops_writeInt16BE buffer, value, offset + 1
      return 3

    # int 32
    if value >= -0x80000000
      buffer[offset] = 0xd2
      bops_writeInt32BE buffer, value, offset + 1
      return 5

    # int 64
    if value >= -0x8000000000000000
      buffer[offset] = 0xd3
      bops_writeInt64BE buffer, value, offset + 1
      return 9
    throw new Error("Number too small -0x" + value.toString(16).substr(1))
  if type is "undefined"
    buffer[offset] = 0xd4
    buffer[offset + 1] = 0x00 # fixext special type/value
    buffer[offset + 2] = 0x00
    return 1

  # null
  if value is null
    buffer[offset] = 0xc0
    return 1

  # Boolean
  if type is "boolean"
    buffer[offset] = (if value then 0xc3 else 0xc2)
    return 1
  return encode(value.toJSON(), buffer, offset)  if "function" is typeof value.toJSON

  # Container Types
  if type is "object"
    size = 0
    isArray = Array.isArray(value)
    if isArray
      length = value.length
    else
      keys = encodeableKeys(value)
      length = keys.length

    # fixarray
    if length < 0x10
      buffer[offset] = length | ((if isArray then 0x90 else 0x80))
      size = 1

    # array 16 / map 16
    else if length < 0x10000
      buffer[offset] = (if isArray then 0xdc else 0xde)
      bops_writeUInt16BE buffer, length, offset + 1
      size = 3

    # array 32 / map 32
    else if length < 0x100000000
      buffer[offset] = (if isArray then 0xdd else 0xdf)
      bops_writeUInt32BE buffer, length, offset + 1
      size = 5
    if isArray
      i = 0

      while i < length
        size += encode(value[i], buffer, offset + size)
        i++
    else
      i = 0

      while i < length
        key = keys[i]
        size += encode(key, buffer, offset + size)
        size += encode(value[key], buffer, offset + size)
        i++
    return size
  return `undefined`  if type is "function"
  throw new Error("Unknown type " + type)
  return
sizeof = (value) ->
  type = typeof value
  length = undefined
  size = undefined

  # Raw Bytes
  if type is "string"

    # TODO: this creates a throw-away buffer which is probably expensive on browsers.
    length = bops_from(value).length
    return 1 + length  if length < 0x20
    return 2 + length  if length < 0x100
    return 3 + length  if length < 0x10000
    return 5 + length  if length < 0x100000000
  if bops_is(value)
    length = value.length
    return 2 + length  if length < 0x100
    return 3 + length  if length < 0x10000
    return 5 + length  if length < 0x100000000
  if type is "number"

    # Floating Point
    # double
    return 9  if value << 0 isnt value

    # Integers
    if value >= 0

      # positive fixnum
      return 1  if value < 0x80

      # uint 8
      return 2  if value < 0x100

      # uint 16
      return 3  if value < 0x10000

      # uint 32
      return 5  if value < 0x100000000

      # uint 64
      return 9  if value < 0x10000000000000000
      throw new Error("Number too big 0x" + value.toString(16))

    # negative fixnum
    return 1  if value >= -0x20

    # int 8
    return 2  if value >= -0x80

    # int 16
    return 3  if value >= -0x8000

    # int 32
    return 5  if value >= -0x80000000

    # int 64
    return 9  if value >= -0x8000000000000000
    throw new Error("Number too small -0x" + value.toString(16).substr(1))

  # Boolean, null
  return 1  if type is "boolean" or value is null
  return 3  if type is "undefined"
  return sizeof(value.toJSON())  if "function" is typeof value.toJSON

  # Container Types
  if type is "object"
    value = value.toJSON()  if "function" is typeof value.toJSON
    size = 0
    if Array.isArray(value)
      length = value.length
      i = 0

      while i < length
        size += sizeof(value[i])
        i++
    else
      keys = encodeableKeys(value)
      length = keys.length
      i = 0

      while i < length
        key = keys[i]
        size += sizeof(key) + sizeof(value[key])
        i++
    return 1 + size  if length < 0x10
    return 3 + size  if length < 0x10000
    return 5 + size  if length < 0x100000000
    throw new Error("Array or object too long 0x" + length.toString(16))
  return 0  if type is "function"
  throw new Error("Unknown type " + type)
  return
to_uint8array = (str) ->
  new Uint8Array(str);
str2ab = (str) ->
  bufView = new Uint8Array(str.length)
  i = 0
  strLen = str.length

  while i < strLen
    bufView[i] = str.charCodeAt(i)
    i++
  bufView

module.exports =
class VimState
  editor: null
  opStack: null
  mode: null
  submode: null

  constructor: (@editorView) ->
    @editor = @editorView.editor
    @opStack = []
    @history = []
    @marks = {}
    params = {}
    params.manager = this;
    params.id = 0;
    @sockets = []

    @setupCommandMode()
    @registerInsertIntercept()
    @registerInsertTransactionResets()
    if atom.config.get 'vim-mode.startInInsertMode'
      @activateInsertMode()
    else
      @activateCommandMode()


    atom.workspaceView.on 'focusout', ".editor:not(.mini)", (event) =>
      editor = $(event.target).closest('.editor').view()?.getModel()
      @destroy_sockets(editor)

    atom.workspaceView.on 'pane:before-item-destroyed', (event, paneItem) =>
      @destroy_sockets(paneItem)

    $(window).preempt 'beforeunload', =>
      for pane in atom.workspaceView.getPanes()
        @destroy_sockets(paneItem) for paneItem in pane.getItems()

    @height = 100
    @line_list = []
    for i in [0..@height-1]
      @line_list.push(i+1)

    @range_list = []
    @range_line_list = []

    @subscriptions = {}
    @subscriptions['redraw:cursor'] = false;
    @subscriptions['redraw:update_line'] = false;
    @subscriptions['redraw:layout'] = false;
    @subscriptions['redraw:foreground_color'] = false
    @subscriptions['redraw:background_color'] = false

    socket = new net.Socket()
    socket.connect('/Users/carlos/tmp/neovim14');

    socket.on('data', (data) =>
        {value:q,trailing} = decode_pub(to_uint8array(data))
        {value:qq,trailing} = decode_pub(str2ab(q[3][1]))
    )
    msg = encode_pub([0,1,0,[]])
    socket.write(msg)
    @sockets.push(socket)
    @neovim_send_message([0,1,39,[]])
    @neovim_send_message([0,1,23,['e! '+@editor.getUri()]])
    @neovim_send_message([0,1,23,['set scrolloff=2']])
    @neovim_send_message([0,1,23,['set nu']])

    # @neovim_send_message([0,1,22,['jjj']])
    # @neovim_send_message([0,1,22,['l']])
    atom.project.eachBuffer (buffer) =>
      @registerChangeHandler(buffer)

    @editorView.on 'editor:min-width-changed', @editorSizeChanged
    atom.workspaceView.on 'pane-container:active-pane-item-changed', @activePaneChanged

  destroy_sockets:(editor) =>
    if @subscriptions['redraw:cursor'] or @subscriptions['redraw:update_line']
      if editor.getUri() != @editor.getUri()
        for item in @sockets
          item.end()
          item.destroy()
        @sockets = []
        @subscriptions['redraw:cursor'] = false
        @subscriptions['redraw:update_line'] = false
        @subscriptions['redraw:layout'] = false
        @subscriptions['redraw:foreground_color'] = false
        @subscriptions['redraw:background_color'] = false


  activePaneChanged: =>

    @neovim_send_message([0,1,23,['e! '+atom.workspaceView.getActiveView().getEditor().getUri()]])
    @neovim_send_message([0,1,23,['set scrolloff=2']])
    @neovim_send_message([0,1,23,['set nu']])

    if not @subscriptions['redraw:background_color']
      @neovim_subscribe('redraw:background_color', (q) =>
        # console.log "r:bgc:"
        # console.log q
      )
    if not @subscriptions['redraw:foreground_color']
      @neovim_subscribe('redraw:foreground_color', (q) =>
        # console.log "r:fgc:"
        # console.log q
      )
    if not @subscriptions['redraw:layout']
      @neovim_subscribe('redraw:layout', (q) =>
        # console.log "r:lo:"
        # console.log q
      )

    if not @subscriptions['redraw:cursor']
      @neovim_subscribe('redraw:cursor', (q) =>
        # console.log q
        @editor.setCursorBufferPosition(new Point(parseInt(q.row),parseInt(q.col)))
        allempty = true
        for rng in @range_list
          if not rng.isEmpty()
            allempty = false
            break
        if not allempty
          @editor.setSelectedBufferRanges(@range_list)
      )

    if not @subscriptions['redraw:update_line']

      @neovim_subscribe('redraw:update_line', (q) =>
        try
          qline = q['line']
          lineno = parseInt(qline[0]['content'])
          linelen = qline[0]['content'].length
          qrow = parseInt(q['row'])
          @line_list[qrow] = lineno
          for i in [0..@height-1]
            if i != qrow
              @line_list[i] = lineno - (qrow - i)

          rng = (new Range(new Point(0,0), new Point(0,0)))

          if 'attributes' of q
            r = q['attributes']
            for key of r
              if key.indexOf('bg') == 0
                s = r[key]
                s0 = parseInt(s[0][0])
                if s[0].length > 1
                  s1 = parseInt(s[0][1])
                  rng = new Range(new Point(qrow+@line_list[0],s0-linelen), new Point(qrow+@line_list[0],s1-linelen))
                else
                  rng = new Range(new Point(qrow+@line_list[0],s0-linelen), new Point(qrow+@line_list[0],s0-linelen+1))
                break
          index = @range_line_list.indexOf(qrow+@line_list[0])
          if index isnt -1
            @range_line_list.splice(index,1)
            @range_list.splice(index,1)
          @range_line_list.push qrow+@line_list[0]
          @range_list.push rng
          @editor.setSelectedBufferRanges(@range_list,{})
        catch err
          console.log 'el error:'+err

        # console.log(@line_list)
      )
    @editorView.on 'editor:min-width-changed', @editorSizeChanged


  editorSizeChanged: =>
    @height = @editorView.getPageRows()
    @line_list = []
    for i in [0..@height-1]
      @line_list.push(i+1)
    @neovim_send_message([0,1,23,['set lines='+@height]])


  neovim_subscribe:(event,f) ->
    socket2 = new net.Socket()
    socket2.connect('/Users/carlos/tmp/neovim14');
    collected = new Buffer(0)
    socket2.on('data', (data) =>
        collected = Buffer.concat([collected, data]);
        i = 1
        while i <= collected.length
          try
            {value:q,trailing} = decode_pub(to_uint8array(collected.slice(0,i)))
            if trailing == 0
              collected = collected.slice(i,collected.length)
              if q[1] == event
                f(q[2])
              i = 1
            else
              if trailing < 0
                i = i - trailing
              else
                i = i + trailing
          catch err
            i = i + 1


    )
    msg2 = encode_pub([0,1,48,[event]])
    socket2.write(msg2)
    @sockets.push(socket2)
    @subscriptions[event] = true


  neovim_send_message:(message,f = undefined) ->
    socket2 = new net.Socket()
    socket2.connect('/Users/carlos/tmp/neovim14');
    socket2.on('data', (data) =>
        # console.log data.toString()
        # console.log data
        # console.log to_uint8array(data)
        {value:q, trailing:t} = decode_pub(to_uint8array(data))
        if f
          f(q)
        socket2.destroy()
        # console.log q
    )
    msg2 = encode_pub(message)
    socket2.write(msg2)

  # Private: Creates a handle to block insertion while in command mode.
  #
  # This is currently a bit of a hack. If a user is in command mode they
  # won't be able to type in any of Atom's dialogs (such as the command
  # palette). This also doesn't block non-printable characters such as
  # backspace.
  #
  # There should probably be a better API on the editor to handle this
  # but the requirements aren't clear yet, so this will have to suffice
  # for now.
  #
  # Returns nothing.
  registerInsertIntercept: ->
    @editorView.preempt 'textInput', (e) =>
      return if $(e.currentTarget).hasClass('mini')

      if @mode == 'insert'
        true
      else
        @clearOpStack()
        false

  # Private: Reset transactions on input for undo/redo/repeat on several
  # core and vim-mode events
  registerInsertTransactionResets: ->
    events = [ 'core:move-up'
               'core:move-down'
               'core:move-right'
               'core:move-left' ]
    @editorView.on events.join(' '), =>
      @resetInputTransactions()


  # Private: Watches for any deletes on the current buffer and places it in the
  # last deleted buffer.
  #
  # Returns nothing.
  registerChangeHandler: (buffer) ->
    buffer.on 'changed', ({newRange, newText, oldRange, oldText}) =>
      return unless @setRegister?
      if newText == ''
        @setRegister('"', text: oldText, type: Utils.copyType(oldText))

  # Private: Creates the plugin's bindings
  #
  # Returns nothing.
  setupCommandMode: ->
    @registerCommands
      'activate-command-mode': => @activateCommandMode()
      'activate-linewise-visual-mode': => @activateVisualMode('linewise')
      'activate-characterwise-visual-mode': => @activateVisualMode('characterwise')
      'activate-blockwise-visual-mode': => @activateVisualMode('blockwise')
      'reset-command-mode': => @resetCommandMode()
      'repeat-prefix': (e) => @repeatPrefix(e)

    @registerOperationCommands
      'activate-insert-mode': => new Operators.Insert(@editor, @)
      'substitute': => new Operators.Substitute(@editor, @)
      'substitute-line': => new Operators.SubstituteLine(@editor, @)
      'insert-after': => new Operators.InsertAfter(@editor, @)
      'insert-after-end-of-line': => [new Motions.MoveToLastCharacterOfLine(@editor), new Operators.InsertAfter(@editor, @)]
      'insert-at-beginning-of-line': => [new Motions.MoveToFirstCharacterOfLine(@editor), new Operators.Insert(@editor, @)]
      'insert-above-with-newline': => new Operators.InsertAboveWithNewline(@editor, @)
      'insert-below-with-newline': => new Operators.InsertBelowWithNewline(@editor, @)
      'delete': => @linewiseAliasedOperator(Operators.Delete)
      'change': => @linewiseAliasedOperator(Operators.Change)
      'change-to-last-character-of-line': => [new Operators.Change(@editor, @), new Motions.MoveToLastCharacterOfLine(@editor)]
      'delete-right': => [new Operators.Delete(@editor, @), new Motions.MoveRight(@editor)]
      'delete-left': => [new Operators.Delete(@editor, @), new Motions.MoveLeft(@editor)]
      'delete-to-last-character-of-line': => [new Operators.Delete(@editor, @), new Motions.MoveToLastCharacterOfLine(@editor)]
      'toggle-case': => new Operators.ToggleCase(@editor, @)
      'yank': => @linewiseAliasedOperator(Operators.Yank)
      'yank-line': => [new Operators.Yank(@editor, @), new Motions.MoveToLine(@editor)]
      'put-before': => new Operators.Put(@editor, @, location: 'before')
      'put-after': => new Operators.Put(@editor, @, location: 'after')
      'join': => new Operators.Join(@editor, @)
      'indent': => @linewiseAliasedOperator(Operators.Indent)
      'outdent': => @linewiseAliasedOperator(Operators.Outdent)
      'auto-indent': => @linewiseAliasedOperator(Operators.Autoindent)
      'move-left': => new Motions.MoveLeft(@editor, @)
      'move-up': => new Motions.MoveUp(@editor, @)
      'move-down': => new Motions.MoveDown(@editor, @)
      'move-right': => new Motions.MoveRight(@editor, @)
      'move-to-next-word': => new Motions.MoveToNextWord(@editor)
      'move-to-next-whole-word': => new Motions.MoveToNextWholeWord(@editor)
      'move-to-end-of-word': => new Motions.MoveToEndOfWord(@editor)
      'move-to-end-of-whole-word': => new Motions.MoveToEndOfWholeWord(@editor)
      'move-to-previous-word': => new Motions.MoveToPreviousWord(@editor)
      'move-to-previous-whole-word': => new Motions.MoveToPreviousWholeWord(@editor)
      'move-to-next-paragraph': => new Motions.MoveToNextParagraph(@editor)
      'move-to-previous-paragraph': => new Motions.MoveToPreviousParagraph(@editor)
      'move-to-first-character-of-line': => new Motions.MoveToFirstCharacterOfLine(@editor)
      'move-to-last-character-of-line': => new Motions.MoveToLastCharacterOfLine(@editor)
      'move-to-beginning-of-line': (e) => @moveOrRepeat(e)
      'move-to-start-of-file': => new Motions.MoveToStartOfFile(@editor)
      'move-to-line': => new Motions.MoveToLine(@editor)
      'move-to-top-of-screen': => new Motions.MoveToTopOfScreen(@editor, @editorView)
      'move-to-bottom-of-screen': => new Motions.MoveToBottomOfScreen(@editor, @editorView)
      'move-to-middle-of-screen': => new Motions.MoveToMiddleOfScreen(@editor, @editorView)
      'scroll-down': => new Scroll.ScrollDown(@editorView, @editor)
      'scroll-up': => new Scroll.ScrollUp(@editorView, @editor)
      'select-inside-word': => new TextObjects.SelectInsideWord(@editor)
      'select-inside-double-quotes': => new TextObjects.SelectInsideQuotes(@editor, '"')
      'select-inside-single-quotes': => new TextObjects.SelectInsideQuotes(@editor, '\'')
      'select-inside-curly-brackets': => new TextObjects.SelectInsideBrackets(@editor, '{', '}')
      'select-inside-angle-brackets': => new TextObjects.SelectInsideBrackets(@editor, '<', '>')
      'select-inside-parentheses': => new TextObjects.SelectInsideBrackets(@editor, '(', ')')
      'register-prefix': (e) => @registerPrefix(e)
      'repeat': (e) => new Operators.Repeat(@editor, @)
      'repeat-search': (e) => currentSearch.repeat() if (currentSearch = Motions.Search.currentSearch)?
      'repeat-search-backwards': (e) => currentSearch.repeat(backwards: true) if (currentSearch = Motions.Search.currentSearch)?
      'focus-pane-view-on-left': => new Panes.FocusPaneViewOnLeft()
      'focus-pane-view-on-right': => new Panes.FocusPaneViewOnRight()
      'focus-pane-view-above': => new Panes.FocusPaneViewAbove()
      'focus-pane-view-below': => new Panes.FocusPaneViewBelow()
      'focus-previous-pane-view': => new Panes.FocusPreviousPaneView()
      'move-to-mark': (e) => new Motions.MoveToMark(@editorView, @)
      'move-to-mark-literal': (e) => new Motions.MoveToMark(@editorView, @, false)
      'mark': (e) => new Operators.Mark(@editorView, @)
      'find': (e) => new Motions.Find(@editorView, @)
      'find-backwards': (e) => new Motions.Find(@editorView, @).reverse()
      'till': (e) => new Motions.Till(@editorView, @)
      'till-backwards': (e) => new Motions.Till(@editorView, @).reverse()
      'replace': (e) => new Operators.Replace(@editorView, @)
      'search': (e) => new Motions.Search(@editorView, @)
      'reverse-search': (e) => (new Motions.Search(@editorView, @)).reversed()
      'search-current-word': (e) => new Motions.SearchCurrentWord(@editorView, @)
      'bracket-matching-motion': (e) => new Motions.BracketMatchingMotion(@editorView,@)
      'reverse-search-current-word': (e) => (new Motions.SearchCurrentWord(@editorView, @)).reversed()

  # Private: Register multiple command handlers via an {Object} that maps
  # command names to command handler functions.
  #
  # Prefixes the given command names with 'vim-mode:' to reduce redundancy in
  # the provided object.
  registerCommands: (commands) ->
    for commandName, fn of commands
      do (fn) =>
        @editorView.command "vim-mode:#{commandName}.vim-mode", fn

  # Private: Register multiple Operators via an {Object} that
  # maps command names to functions that return operations to push.
  #
  # Prefixes the given command names with 'vim-mode:' to reduce redundancy in
  # the given object.
  registerOperationCommands: (operationCommands) ->
    commands = {}
    for commandName, operationFn of operationCommands
      do (operationFn) =>
        commands[commandName] = (event) => @pushOperations(operationFn(event))
    @registerCommands(commands)

  # Private: Push the given operations onto the operation stack, then process
  # it.
  pushOperations: (operations) ->
    return unless operations?
    operations = [operations] unless _.isArray(operations)

    for operation in operations
      # Motions in visual mode perform their selections.
      if @mode is 'visual' and (operation instanceof Motions.Motion or operation instanceof TextObjects.TextObject)
        operation.execute = operation.select

      # if we have started an operation that responds to canComposeWith check if it can compose
      # with the operation we're going to push onto the stack
      if (topOp = @topOperation())? and topOp.canComposeWith? and not topOp.canComposeWith(operation)
        @editorView.trigger 'vim-mode:compose-failure'
        @resetCommandMode()
        break

      @opStack.push(operation)

      # If we've received an operator in visual mode, mark the current
      # selection as the motion to operate on.
      if @mode is 'visual' and operation instanceof Operators.Operator
        @opStack.push(new Motions.CurrentSelection(@))

      @processOpStack()

  # Private: Removes all operations from the stack.
  #
  # Returns nothing.
  clearOpStack: ->
    @opStack = []

  # Private: Processes the command if the last operation is complete.
  #
  # Returns nothing.
  processOpStack: ->
    unless @opStack.length > 0
      return

    unless @topOperation().isComplete()
      if @mode is 'command' and @topOperation() instanceof Operators.Operator
        @activateOperatorPendingMode()
      return

    poppedOperation = @opStack.pop()
    if @opStack.length
      try
        @topOperation().compose(poppedOperation)
        @processOpStack()
      catch e
        ((e instanceof Operators.OperatorError) or (e instanceof Motions.MotionError)) and @resetCommandMode() or throw e
    else
      @history.unshift(poppedOperation) if poppedOperation.isRecordable()
      poppedOperation.execute()

  # Private: Fetches the last operation.
  #
  # Returns the last operation.
  topOperation: ->
    _.last @opStack

  # Private: Fetches the value of a given register.
  #
  # name - The name of the register to fetch.
  #
  # Returns the value of the given register or undefined if it hasn't
  # been set.
  getRegister: (name) ->
    if name in ['*', '+']
      text = atom.clipboard.read()
      type = Utils.copyType(text)
      {text, type}
    else if name == '%'
      text = @editor.getUri()
      type = Utils.copyType(text)
      {text, type}
    else if name == "_" # Blackhole always returns nothing
      text = ''
      type = Utils.copyType(text)
      {text, type}
    else
      atom.workspace.vimState.registers[name]

  # Private: Fetches the value of a given mark.
  #
  # name - The name of the mark to fetch.
  #
  # Returns the value of the given mark or undefined if it hasn't
  # been set.
  getMark: (name) ->
    if @marks[name]
      @marks[name].getBufferRange().start
    else
      undefined


  # Private: Sets the value of a given register.
  #
  # name  - The name of the register to fetch.
  # value - The value to set the register to.
  #
  # Returns nothing.
  setRegister: (name, value) ->
    if name in ['*', '+']
      atom.clipboard.write(value.text)
    else if name == '_'
      # Blackhole register, nothing to do
    else
      atom.workspace.vimState.registers[name] = value

  # Private: Sets the value of a given mark.
  #
  # name  - The name of the mark to fetch.
  # pos {Point} - The value to set the mark to.
  #
  # Returns nothing.
  setMark: (name, pos) ->
    # check to make sure name is in [a-z] or is `
    if (charCode = name.charCodeAt(0)) >= 96 and charCode <= 122
      marker = @editor.markBufferRange(new Range(pos,pos),{invalidate:'never',persistent:false})
      @marks[name] = marker

  # Public: Append a search to the search history.
  #
  # Motions.Search - The confirmed search motion to append
  #
  # Returns nothing
  pushSearchHistory: (search) ->
    atom.workspace.vimState.searchHistory.unshift search

  # Public: Get the search history item at the given index.
  #
  # index - the index of the search history item
  #
  # Returns a search motion
  getSearchHistoryItem: (index) ->
    atom.workspace.vimState.searchHistory[index]

  resetInputTransactions: ->
    return unless @mode == 'insert' && @history[0]?.inputOperator?()
    @deactivateInsertMode()
    @activateInsertMode()

  ##############################################################################
  # Mode Switching
  ##############################################################################

  # Private: Used to enable command mode.
  #
  # Returns nothing.
  activateCommandMode: ->
    @deactivateInsertMode()
    @mode = 'command'
    @submode = null

    if @editorView.is(".insert-mode")
      cursor = @editor.getCursor()
      cursor.moveLeft() unless cursor.isAtBeginningOfLine()

    @changeModeClass('command-mode')

    @clearOpStack()
    @editor.clearSelections()

    @updateStatusBar()

  # Private: Used to enable insert mode.
  #
  # Returns nothing.
  activateInsertMode: (transactionStarted = false)->
    @mode = 'insert'
    @editor.beginTransaction() unless transactionStarted
    @submode = null
    @changeModeClass('insert-mode')
    @updateStatusBar()

  deactivateInsertMode: ->
    return unless @mode == 'insert'
    @editor.commitTransaction()
    transaction = _.last(@editor.buffer.history.undoStack)
    item = @inputOperator(@history[0])
    if item? and transaction?
      item.confirmTransaction(transaction)

  # Private: Get the input operator that needs to be told about about the
  # typed undo transaction in a recently completed operation, if there
  # is one.
  inputOperator: (item) ->
    return item unless item?
    return item if item.inputOperator?()
    return item.composedObject if item.composedObject?.inputOperator?()


  # Private: Used to enable visual mode.
  #
  # type - One of 'characterwise', 'linewise' or 'blockwise'
  #
  # Returns nothing.
  activateVisualMode: (type) ->
    @deactivateInsertMode()
    @mode = 'visual'
    @submode = type
    @changeModeClass('visual-mode')

    if @submode == 'linewise'
      @editor.selectLine()

    @updateStatusBar()

  # Private: Used to enable operator-pending mode.
  activateOperatorPendingMode: ->
    @deactivateInsertMode()
    @mode = 'operator-pending'
    @submodule = null
    @changeModeClass('operator-pending-mode')

    @updateStatusBar()

  changeModeClass: (targetMode) ->
    for mode in ['command-mode', 'insert-mode', 'visual-mode', 'operator-pending-mode']
      if mode is targetMode
        @editorView.addClass(mode)
      else
        @editorView.removeClass(mode)

  # Private: Resets the command mode back to it's initial state.
  #
  # Returns nothing.
  resetCommandMode: ->
    @activateCommandMode()

  # Private: A generic way to create a Register prefix based on the event.
  #
  # e - The event that triggered the Register prefix.
  #
  # Returns nothing.
  registerPrefix: (e) ->
    name = atom.keymap.keystrokeStringForEvent(e.originalEvent)
    new Prefixes.Register(name)

  # Private: A generic way to create a Number prefix based on the event.
  #
  # e - The event that triggered the Number prefix.
  #
  # Returns nothing.
  repeatPrefix: (e) ->
    num = parseInt(atom.keymap.keystrokeStringForEvent(e.originalEvent))
    if @topOperation() instanceof Prefixes.Repeat
      @topOperation().addDigit(num)
    else
      if num is 0
        e.abortKeyBinding()
      else
        @pushOperations(new Prefixes.Repeat(num))

  # Private: Figure out whether or not we are in a repeat sequence or we just
  # want to move to the beginning of the line. If we are within a repeat
  # sequence, we pass control over to @repeatPrefix.
  #
  # e - The triggered event.
  #
  # Returns new motion or nothing.
  moveOrRepeat: (e) ->
    if @topOperation() instanceof Prefixes.Repeat
      @repeatPrefix(e)
      null
    else
      new Motions.MoveToBeginningOfLine(@editor)

  # Private: A generic way to handle Operators that can be repeated for
  # their linewise form.
  #
  # constructor - The constructor of the operator.
  #
  # Returns nothing.
  linewiseAliasedOperator: (constructor) ->
    if @isOperatorPending(constructor)
      new Motions.MoveToLine(@editor)
    else
      new constructor(@editor, @)

  # Private: Check if there is a pending operation of a certain type
  #
  # constructor - The constructor of the object type you're looking for.
  #
  # Returns nothing.
  isOperatorPending: (constructor) ->
    for op in @opStack
      return op if op instanceof constructor
    false

  updateStatusBar: ->
    if !$('#status-bar-vim-mode').length
      atom.packages.once 'activated', ->
        atom.workspaceView.statusBar?.prependRight("<div id='status-bar-vim-mode' class='inline-block'>Command</div>")

    if @mode is "insert"
      $('#status-bar-vim-mode').html("Insert")
    else if @mode is "command"
      $('#status-bar-vim-mode').html("Command")
    else if @mode is "visual"
      $('#status-bar-vim-mode').html("Visual")
