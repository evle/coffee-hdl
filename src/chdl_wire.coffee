CircuitEl=require 'chdl_el'
_ = require 'lodash'
{packEl,toNumber}=require 'chdl_utils'

class Wire extends CircuitEl
  width: 0

  @bind: (channel_name)->
    wire=new Wire(0)
    wire.setBindChannel(channel_name)
    return wire

  setBindChannel: (c)-> @bindChannel=c
  isBinded: -> @bindChannel?

  @create: (width=1)-> new Wire(width)

  @create_array: (num,width=1)->
    ret = []
    for i in [0...num]
      ret.push (new Wire(width))
    return ret

  constructor: (width)->
    super()
    @width=width
    @value=0
    @pendingValue=null
    @lsb= -1
    @msb= -1
    @staticAssign=false
    @firstCondAssign=true
    @states=[]
    @bindChannel=null
    @fieldMap={}

  init: (v)->
    @value=v
    return this

  defaultValue: (v)->
    @pendingValue=v
    return this

  setField: (name,msb=0,lsb=0)=>
    if _.isString(name)
      @fieldMap[name]={msb:msb,lsb:lsb}
      return packEl('wire',this)
    else if _.isPlainObject(name)
      for k,v of name
        @fieldMap[k]={msb:v[0],lsb:v[1]}
      return packEl('wire',this)
    else
      return null

  field: (name,msb,lsb)=>
    item = @fieldMap[name]
    if item?
      msb=item.msb
      lsb=item.lsb
      return @slice(msb,lsb)
    else
      return null

  setLsb: (n)-> @lsb=toNumber(n)
  setMsb: (n)-> @msb=toNumber(n)

  getMsb: (n)=> @msb
  getLsb: (n)=> @lsb

  bit: (n)->
    wire= Wire.create(1)
    wire.link(@cell,@elName)
    if n.constructor.name=='Expr'
      wire.setLsb(n.str)
      wire.setMsb(n.str)
      return packEl('wire',wire)
    else
      wire.setLsb(n)
      wire.setMsb(n)
      return packEl('wire',wire)

  slice: (n,m)->
    if n.constructor.name=='Expr'
      wire= Wire.create(toNumber(n.str)-toNumber(m.str)+1)
      wire.link(@cell,@elName)
      wire.setLsb(m.str)
      wire.setMsb(n.str)
      return packEl('wire',wire)
    else
      wire= Wire.create(toNumber(n)-toNumber(m)+1)
      wire.link(@cell,@elName)
      wire.setLsb(m)
      wire.setMsb(n)
      return packEl('wire',wire)

  refName: =>
    if @lsb>=0
      if @width==1
        @elName+"["+@lsb+"]"
      else
        @elName+"["+@msb+":"+@lsb+"]"
    else
      @elName

  get: -> @value

  set: (v)-> @value=v

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  assign: (assignFunc)=>
    @cell.__assignWaiting=true
    if @cell.__assignInAlways
      if @staticAssign
        throw new Error("This wire have been static assigned")
      else if @firstCondAssign
        if @width==1
          @cell.__wireAssignList.push "reg _"+@elName+";"
        else
          @cell.__wireAssignList.push "reg ["+(@width-1)+":0] _"+@elName+";"
        @cell.__wireAssignList.push "assign #{@elName} = _#{@elName};"
        @firstCondAssign=false
      @cell.__regAssignList.push @getSpace()+"_#{@refName()} = #{assignFunc()};"
    else
      @cell.__wireAssignList.push "assign #{@refName()} = #{assignFunc()};"
      @staticAssign=true
    @cell.__assignWaiting=false
    @cell.__updateWires.push({type:'wire',name:@elName,pending:@pendingValue})


  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push "localparam "+@elName+'__'+i.state+"="+i.value+";"
    if @width==1
      list.push "wire "+@elName+";"
    else if @width>1
      list.push "wire ["+(@width-1)+":0] "+@elName+";"
    return list.join("\n")

  setWidth:(w)-> @width=w
  getWidth:()=> @width

  stateDef: (arg)=>
    @states=[] if @states==null
    if _.isArray(arg)
      for i,index in arg
        @states.push {state:i,value:index}
    else if _.isPlainObject(arg)
      for k,v of arg
        @states.push {state:k,value:v}
    else
      throw new Error('Set sateMap error')

  isState: (name)=>
    "#{@refName()}==#{@elName+'__'+name}"

  notState: (name)=>
    "#{@refName()}!=#{@elName+'__'+name}"

  setState: (name)=>
    @cell.__wireAssignList.push @getSpace()+"_#{@refName()}=#{@elName+'__'+name};"

  getState: (name)=> @elName+'__'+name

  reverse: ()=>
    wire= Wire.create(@width)
    list=[]
    for i in [0...@width]
      list.push @bit(i)
    name='{'+_.map(list,(i)=>i.refName()).join(',')+'}'
    wire.link(@cell,name)
    return packEl('wire',wire)

  select: (cb)=>
    wire= Wire.create(@width)
    list=[]
    for i in [0...@width]
      index = @width-1-i
      if cb(index)
        list.push @bit(index)
    name='{'+_.map(list,(i)=>i.refName()).join(',')+'}'
    wire.link(@cell,name)
    return packEl('wire',wire)

module.exports=Wire
