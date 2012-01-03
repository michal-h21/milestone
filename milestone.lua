--local node,texio,unicode,io,tex,dofile=node,texio,unicode,io,tex,dofile 
module("milestone",package.seeall)
-- Variables accessible from the outside
milestonefile = tex.jobname..".mil"   -- File, where all milestones are saved
pagenumber=""                         -- Pagenumbers must be saved in TeX, 
                                      -- in the output routine
hyphenchar=45
pageformat="//[%s]"
local glyph = node.id('glyph')
local milchecksum=0
local glyphpos=0
function calcChecksum(item,checksum,pos)
  val=item.char
  if val ~= hyphenchar and node.has_attribute(item,224)~=33 then
    if val==120 or val==88 or val > 128 then  
      return checksum,pos+1
    --elseif item.left==2 then  
    --  return checksum,pos+0.5
    else
      return checksum + val, pos + 1
    end
  end
  return checksum, pos
end

-- Item in the current list, where the page break mark should be inserted
function printPageBreak(item,page)
  local hi = node.new("glue")
  local mynode=mknodes(hi,unicode.utf8.format(pageformat,page))
  local pp=item.next
  item.next=hi
  node.tail(hi).next=pp
end

local milposition=1
--local mcheck=0
function insertPageBreaks(head,group)
  t=getMilestones()
  for item in node.traverse_id(glyph, head) do
    if milposition > #t then break end  
      if item.id == glyph then --and item.char ~= hyphenchar then
        -- Nodes created with function mknodes() have attribute 224 set to 33, 
        -- we must skip them
        if node.has_attribute(item,224)~=33 then
          milchecksum,glyphpos=calcChecksum(item,milchecksum,glyphpos)--milchecksum+item.char
        end
        if milchecksum==t[milposition]["checksum"] then
          texio.write_nl("Checksum equality: "..milchecksum.." page: "..t[milposition]["page"])       
          printPageBreak(item,t[milposition]["page"])
          milposition=milposition+1
        end
      end
  end
  texio.write_nl("Current checksum: "..milchecksum)
  return head
end

local function processLine(line)
  local lcontents=""
  for item in node.traverse(line.list) do
        if item.id == glyph then -- and item.char ~= 45 then
          lcontents = lcontents .. unicode.utf8.char(item.char) 
          milchecksum,glyphpos= calcChecksum(item,milchecksum,glyphpos)
        end
  end
  return lcontents
end

function getPageBreaks(head)
  local lcontents = ""
  for line in node.traverse_id(node.id("hlist"), head) do
    lcontents=processLine(line)
    --texio.write_nl(lcontents)
  end
  addMilestone(pagenumber,milchecksum,glyphpos,lcontents)
  return true
end

local miloutput=""
function addMilestone(page,checksum,pos,text)
  if text ~= "" then 
    miloutput = miloutput .. unicode.utf8.format("milestone{\n  page=\"%s\",\n  checksum=%d,\n  text=\"%s\",\n  glyphpos=%d\n}\n",page,checksum,text,pos)
    texio.write_nl(unicode.utf8.format("Page:%s checksum:%d text:%s",page,checksum,text))
  end
end

function writeMilestones()
  if(miloutput~="") then
    local f=io.open(milestonefile,"w")
    f:write(miloutput)
    f:close()
  else 
    texio.write("Package milestone: No milestones writen to the output")
  end
end


function import(name)
  local f,e = loadfile(name)
  if not f then error(e, 2) end
  setfenv(f, getfenv(2))
  return f()
end


function getMilestones()
    local t={}
    local i=1
    function milestone(b)
      --local function injectElements(el) t[#t+1][el]=b[el] end
      t[i]={}
      for k,v in pairs(b) do t[i][k] = v end
      i=i+1
    end 
    import(milestonefile)
    return t
end

function printMilestone(head,current,text)
  local message = mknodes("//["..text.."]")
  return node.insert_after(head,current,message)
end

function mknodes(head, text )
  local current_font = font.current()
  local font_parameters = font.getfont(current_font).parameters
  local n,  last
  -- we should insert the paragraph indentation at the beginning
  --[[
  head = node.new("glue")
  head.spec = node.new("glue_spec")
  head.spec.width = 5 * 2^16
  --]]
  last = node.tail(head)
  local count=0
  for s in string.utfvalues( text ) do
    local char = unicode.utf8.char(s)
    if unicode.utf8.match(char,"%s") then
      -- its a space
      n = node.new("glue")
      n.spec = node.new("glue_spec")
      n.spec.width   = font_parameters.space
      n.spec.shrink  = font_parameters.space_shrink
      n.spec.stretch = font_parameters.space_stretch
    else -- a glyph
      count=count+s
      n = node.new("glyph")
      n.font = current_font
      n.subtype = 1
      n.char = s
      n.lang = tex.language
      n.uchyph = 1
      n.left = tex.lefthyphenmin
      n.right = tex.righthyphenmin
    end
    node.set_attribute(n,224,33)
    last.next = n
    last = n
  end

  -- just to create the prev pointers for tex.linebreak
  node.slide(head)
  return head,count
end

local function printNodeList(head)
  for ii in node.traverse(head) do
    if ii.id == glyph then texio.write(string.char(ii.char)) 
    elseif ii.id == node.id("glue") then texio.write(" ")
    end
  end
end