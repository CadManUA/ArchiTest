-- See www.lua.org for Lua manual.
-- Extension functions - see manual
-- Used to give IDs to planks based on the role in the element
-- To customize this:
-- Copy this file to user specific settings folder and give it a new name starting with ArchiFrameRenum, for example: ArchiFrameRenumOurRule.lua
-- Edit function RenumGetUI() to give a decent name
-- Edit function GetElemGroupName() to change grouping rule (for example to combine top and bottom plates into the same group)


gScriptUtf8=1		-- We work with unicode


function toLog(s)
	ac_environment("tolog", s)
end


-- Dumps given variable into string
function DumpTblInt(o)
  local s
  
  if type(o) == 'table' then
    s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. DumpTblInt(v) .. ','
    end
    s=s .. '} '
  else
    s=tostring(o)
  end
  return s
end


function DumpTbl(o)
  ac_environment("tolog", DumpTblInt(o))
end


-- Gives meaningful name for the plank in the element
-- isHor  Is it horizontal structure (false/nil=default) (rotated inside the element, in walls true if horizontal framing)
-- elemgroup  Parameter iElemGroup
-- nFloorRoof, nil=not known or a wall, 1=it is a floor, 2=it is a roof
function GetElemGroupName(isHor, elemgroup, nFloorRoof)
  local lang
  
  lang=af_request("aflang")
  if nFloorRoof and nFloorRoof==1 then
    -- It is a floor
    if elemgroup==nil then
      elemgroup=""
    elseif string.match(elemgroup, "^nogging.*") then
      elemgroup="N"

      if lang=="nor" then
        elemgroup="KU"	--"Kubbing"
      elseif lang=="fin" then
        elemgroup="NT"	--"Nurjahdustuki"
      elseif lang=="swe" then
        elemgroup="K"	--"Kortling"
      elseif lang=="por" then
        elemgroup="TA"	--"Tabique"
      end
    elseif elemgroup=="sideleft_spacing" or elemgroup=="sideright_spacing" then
      elemgroup="SB"
      if lang=="fin" then
        elemgroup="SP"	--"Sivupalkki"
      elseif lang=="nor" then
        elemgroup="SB"	--"Stikkbjelke"
      elseif lang=="swe" then
        elemgroup="ÄK"	--"Ändkortling"
      elseif lang=="por" then
        elemgroup="VL"	--"Vigas laterais"
      end
    elseif string.match(elemgroup, "^vertical_x.*") or string.match(elemgroup, "^contourtilted_opening.*") then
      elemgroup="J"		--"Joist"   -- Could be better
      if lang=="fin" then
        elemgroup="VP"	---"Vekselipalkki"
      elseif lang=="nor" then
        elemgroup="VB"	--"Vekselbjelke"
      elseif lang=="swe" then
        --elemgroup="Joist" -- Could be better
      elseif lang=="por" then
        elemgroup="V"	--"Viga"  -- Could be better
      end
    elseif string.match(elemgroup, "^vertical_spacing.*") or string.match(elemgroup, "^vertical_force.*") then
      elemgroup="J"		--"Joist"   -- Could be better
      if lang=="fin" then
        elemgroup="VA"	--"Vasa"
      elseif lang=="nor" then
        elemgroup="MB"	--"Modulbjelke"
      elseif lang=="swe" then
        --elemgroup="Joist" -- Could be better
      elseif lang=="por" then
        elemgroup="V"		--"Viga"  -- Could be better
      end
    elseif string.match(elemgroup, "^vertical_y.*") then
      elemgroup="J"	--"Joist"   -- Could be better
      if lang=="fin" then
        elemgroup="VA"	--"Vasa"
      elseif lang=="nor" then
        elemgroup="MB"	--"Sidebjelke"
      elseif lang=="swe" then
        --elemgroup="Joist" -- Could be better
      elseif lang=="por" then
        elemgroup="V"		--"Viga"  -- Could be better
      end
    elseif string.match(elemgroup, "^top.*") or string.match(elemgroup, "^2ndtop.*") or string.match(elemgroup, "^contour.*") or string.match(elemgroup, "^bottom.*") or string.match(elemgroup, "^2ndbottom.*") then
      elemgroup="C"		--"Contour piece"
      if lang=="fin" then
        elemgroup="R"	--"Reunakappale"
      elseif lang=="swe" then
        --elemgroup="Contour piece"
      elseif lang=="nor" then
        elemgroup="KB"	--"Kantbjelke"
      elseif lang=="por" then
        elemgroup="PC"	--"Peça de contorno"
      end
    else
      elemgroup=""
    end
  elseif nFloorRoof and nFloorRoof==2 then
    -- It is a roof
    if elemgroup==nil then
      elemgroup=""
    elseif string.match(elemgroup, "^top.*") or string.match(elemgroup, "^2ndtop.*") or string.match(elemgroup, "^contour.*") or string.match(elemgroup, "^bottom.*") or string.match(elemgroup, "^2ndbottom.*") then

      elemgroup="TB"	--"Top/bottom"
      if lang=="fin" then
        elemgroup="YA"	--"Ylä/alajuoksu"
      elseif lang=="swe" then
        --elemgroup="Top/bottom"
      elseif lang=="nor" then
        elemgroup="DR"	--"Drager"
      elseif lang=="por" then
        elemgroup="TB"	--"Topo/base"
      end
    else
      elemgroup="R"	--"Rafter"
      if lang=="fin" then
        elemgroup="V"	--"Vasa"
      elseif lang=="swe" then
        --elemgroup="Rafter"
      elseif lang=="nor" then
        elemgroup="SP"	--"Sperr"
      elseif lang=="por" then
        elemgroup="TR"	--"Trave"
      end
    end
  elseif isHor then
    -- Horizontal structure
    if elemgroup==nil then
      elemgroup=""
    elseif string.match(elemgroup, "^top%a*") or string.match(elemgroup, "^2ndtop%a*") or string.match(elemgroup, "^contour_x.*") or string.match(elemgroup, "^bottom%a*") or string.match(elemgroup, "^2ndbottom%a*") then
      elemgroup="ST"	--"Stud"
      if lang=="fin" then
        elemgroup="T"	--"Tolppa"
      elseif lang=="swe" then
        elemgroup="R"	--"Regel"
      elseif lang=="nor" then
        elemgroup="ST"	--"Stendere"
      elseif lang=="por" then
        elemgroup="ST"	--"Stud"
      end
    elseif string.match(elemgroup, "^vertical_x%a*") or string.match(elemgroup, "^vertical_y%a*") or string.match(elemgroup, "^contourtilted_opening%a*") then
      elemgroup="DW"	--"Door/win"
      if lang=="fin" then
        elemgroup="IO"	--"Ikk/ovi"
      elseif lang=="swe" then
        elemgroup="AV"	--"Avväxling"
      elseif lang=="nor" then
        elemgroup="LS"	--"Losholt" -- "Dør/vindu"
      elseif lang=="por" then
        elemgroup="PJ"	--"Porta/Janela"
      end
    elseif string.match(elemgroup, "^vertical%a*") then
      elemgroup="HOR"	--"Hor"
      if lang=="fin" then
        elemgroup=""	--"Vaaka"
      elseif lang=="nor" then
        elemgroup=""	--"Vannrett"
      elseif lang=="por" then
        elemgroup="HOR"	--"Hor"
      end
    elseif string.match(elemgroup, "^contourtilted%a*") then
      elemgroup=""	--"Angled"
--[[
      if lang=="fin" then
        elemgroup="Vinojuoksu"
      elseif lang=="swe" then
        elemgroup="Regel"
      elseif lang=="nor" then
        elemgroup="Vinklet"
      elseif lang=="por" then
        elemgroup="Angulado"
      end
]]
    elseif string.match(elemgroup, "^balk.*") then
      elemgroup="B"	--"Beam"
      if lang=="fin" then
        elemgroup="PA"	--"Palkki"
      elseif lang=="swe" then
        elemgroup="BÄ"	--"Bärlina"
      elseif lang=="nor" then
        elemgroup="BJ"	--"Bjelke"
      elseif lang=="por" then
        elemgroup="V"	--"Viga"
      end
    elseif string.match(elemgroup, "^lintel.*") then
      elemgroup="WDB"	--"W/D beam"
      if lang=="fin" then
        elemgroup="AP"	--"Aukkopalkki"
      elseif lang=="swe" then
        elemgroup="BP"	--"Bärplanka"
      elseif lang=="nor" then
        elemgroup="DR"	--"Dragere"   -- "Dør-/vindu-bjelke"
      elseif lang=="por" then
        elemgroup="VPJ"	--"Viga P/J"
      end
    elseif string.match(elemgroup, "^reinforce.*") then
      elemgroup="RF"	--"Reinforcement"
      if lang=="fin" then
        elemgroup="VA"	--"Vahvike"
      elseif lang=="swe" then
        elemgroup="FS"	--"Förstärkning"
      elseif lang=="nor" then
        elemgroup="FS"	--"Forsterkning"
      elseif lang=="por" then
        elemgroup="RF"	--"Reforço"
      end
    elseif string.match(elemgroup, "^nogging.*") then
      elemgroup="N"	--"Nogging"
      if lang=="nor" then
        elemgroup="KU"	--"Kubbing"
      elseif lang=="fin" then
        elemgroup="NT"	--"Nurjahdustuki"
      elseif lang=="swe" then
        elemgroup="K"	--"Kortling"
      elseif lang=="por" then
        elemgroup="TA"	--"Tabique"
      end
    elseif elemgroup=="sideleft_spacing" or elemgroup=="sideright_spacing" then
      elemgroup="SB"	--"Side beams"
      if lang=="fin" then
        elemgroup="SP"	--"Sivupalkki"
      elseif lang=="nor" then
        elemgroup="SB"	--"Stikkbjelke"
      elseif lang=="swe" then
        elemgroup="ÄK"	--"Ändkortling"
      elseif lang=="por" then
        elemgroup="VL"	--"Vigas laterais"
      end
    else
      elemgroup=""
    end
  else
    -- Vertical structure
    if elemgroup==nil then
      elemgroup=""
    elseif string.match(elemgroup, "^top%a*") or string.match(elemgroup, "^2ndtop%a*") then
      elemgroup="TP"	--"Top plate"
      if lang=="fin" then
        elemgroup="YJ"	--"Yläjuoksu"
      elseif lang=="swe" then
        elemgroup="HB"
      elseif lang=="nor" then
        elemgroup="TS"	--"Toppsvill"
      elseif lang=="por" then
        elemgroup="PT"	--"Placa de topo"
      end
    elseif string.match(elemgroup, "^bottom%a*") or string.match(elemgroup, "^2ndbottom%a*") then
      elemgroup="BP"	--"Bottom plate"
      if lang=="fin" then
        elemgroup="AJ"	--"Alajuoksu"
      elseif lang=="swe" then
        elemgroup="SY"	--"Syll"
      elseif lang=="nor" then
        elemgroup="BS"	--"Bunnsvill"
      elseif lang=="por" then
        elemgroup="PB"	--"Placa base"
      end
    elseif string.match(elemgroup, "^contour_x.*") then
      elemgroup="TBP"	--"Top/bottom plate"
      if lang=="fin" then
        elemgroup="YA"	--"Ylä/alajuoksu"
      elseif lang=="swe" then
        elemgroup="HB/SY"
      elseif lang=="nor" then
        elemgroup="TS/BS"	--"Topp-/Bunnsvill"
      elseif lang=="por" then
        elemgroup="PTB"	--"Placa Topo/base"
      end
    elseif string.match(elemgroup, "^vertical_x%a*") or string.match(elemgroup, "^contourtilted_opening%a*") then
      elemgroup="WD"	--"Win/door"
      if lang=="fin" then
        elemgroup="IO"	--"Ikk/ovi"
      elseif lang=="swe" then
        elemgroup="AV"	--"Avväxling"
      elseif lang=="nor" then
        elemgroup="LH"	--"Losholt" -- "Dør/vindu"
      elseif lang=="por" then
        elemgroup="Jp"	--"Janela/Porta"
      end
    elseif string.match(elemgroup, "^vertical%a*") or string.match(elemgroup, "^contour_y.*") then
      elemgroup="ST"	--"Stud"
      if lang=="fin" then
        elemgroup="T"	--"Tolppa"
      elseif lang=="swe" then
        elemgroup="R"	--"Regel"
      elseif lang=="nor" then
        elemgroup="ST"	--"Stendere"
      elseif lang=="por" then
        elemgroup="ST"	--"Stud"
      end
    elseif string.match(elemgroup, "^contourtilted%a*") then
      elemgroup="AN"	--"Angled"
      if lang=="fin" then
        elemgroup="VJ"	--"Vinojuoksu"
      elseif lang=="swe" then
        elemgroup="AN"	--Regel"
      elseif lang=="nor" then
        elemgroup="VI"	--"Vinklet"
      elseif lang=="por" then
        elemgroup="AN"	--"Angulado"
      end
    elseif string.match(elemgroup, "^balktop.*") or string.match(elemgroup, "^balkbot.*") then
      elemgroup="BE"	--"Beam top"
      if lang=="fin" then
        elemgroup="PA"	--"Palkki ylä"
      elseif lang=="swe" then
        elemgroup="BÄ"	--"Bärlina topp"
      elseif lang=="nor" then
        elemgroup="BJ"	--"Bjelke"
      elseif lang=="por" then
        elemgroup="V"	--"Viga topo"
      end
    elseif string.match(elemgroup, "^lintel.*") then
      elemgroup="WD BE"
      if lang=="fin" then
        elemgroup="AP"	--"Aukkopalkki"
      elseif lang=="swe" then
        elemgroup="BP"	--"Bärplanka"
      elseif lang=="nor" then
        elemgroup="OD"	--"Dragere" -- "Dør-/vindu-bjelke"
      elseif lang=="por" then
        elemgroup="VPJ"	--"Viga P/J"
      end
    elseif string.match(elemgroup, "^nogging.*") then
      elemgroup="N"	--"Nogging"
      if lang=="nor" then
        elemgroup="KU"	--"Kubbing"
      elseif lang=="fin" then
        elemgroup="NT"	--"Nurjahdustuki"
      elseif lang=="swe" then
        elemgroup="K"	--"Kortling"
      elseif lang=="por" then
        elemgroup="TA"	--"Tabique"
      end
    elseif elemgroup=="sideleft_spacing" or elemgroup=="sideright_spacing" then
      elemgroup="SB"	--"Side beams"
      if lang=="fin" then
        elemgroup="SP"	--"Sivupalkki"
      elseif lang=="nor" then
        elemgroup="SB"	--"Stikkbjelke"
      elseif lang=="swe" then
        elemgroup="ÄK"	--"Ändkortling"
      elseif lang=="por" then
        elemgroup="VL"	--"Vigas laterais"
      end
    else
      elemgroup=""
    end
  end
  
  return elemgroup
end



-- Makes a 1-based table having each plank separate. Causes error if other than plank/board objects in the input. Each table element has fields:
-- groupid		The unid of the group (originally index to tblGroupedElems). Having this same means the planks are identical (excluding the role in the element)
-- plankinfo	af_request("plankinfo") for the item, note that owning ArchiFrameElement is used to set field elemdata and its id is here in ownerelemid
-- elemgroup	Parameter iElemGroup telling the role in the element parsed by GetElemGroupName()
-- ownerElem	Information of the related element data or nil=not belonging to any element, fields
--  plankinfo	To be used to set main plankinfo.elemdata

-- Returns:
-- 1. The each element separate array
-- NOPE 2. 1-based array of GUIDs not processed because not planks/boards
function MakeLinearElems(tblGroupedElems, bUnique)
	local	tblRes
	local	tblElems		-- key=guid, value=ownerElem-data
	local	i1, i2, group, item, totcount
	
--toLog(string.format("bUnique=%s", tostring(bUnique)))

	totcount=0
	tblRes={}
	tblElems={}
	i1=1
	while true do
		group=tblGroupedElems[i1]
		if not group then
			break
		end
		i1=i1+1
		
		i2=1
		while true do
			item=group[i2]
			if not item  then
				break
			end
			i2=i2+1
			
			-- Create current item
			local	curr, elem
			
			curr={}
			curr.groupid=i1
			if bUnique then
				totcount=totcount+1
				curr.groupid=totcount
			end
			
			ac_objectopen(item)			-- Causes error if not an object
			curr.plankinfo=af_request("plankinfo")
			if curr.plankinfo and curr.plankinfo.ownerelemguid then
				-- Include element information which is cached
				elem=tblElems[curr.plankinfo.ownerelemguid]
				if not elem then
					elem={}
					elem.plankinfo=af_request("plankinfo", curr.plankinfo.ownerelemguid)
					tblElems[curr.plankinfo.ownerelemguid]=elem
				end
				curr.plankinfo=af_request("plankinfo", nil, elem.plankinfo)
				curr.ownerElem=elem
			end
			
			curr.elemgroup=""
			if elem then
				local isHor, nFloorRoof

				-- Say it is a floor if in zero deg angle and roof if non-90 deg
				-- isHor is customer specific stuff and should be detected by element type name or based on type
				isHor=false
				nFloorRoof=0
				if math.abs(elem.plankinfo.vecz.z)<0.001 then
					nFloorRoof=1
				elseif math.abs(elem.plankinfo.vecz.z)<0.90 then
					nFloorRoof=2
				end

				curr.elemgroup=GetElemGroupName(isHor, ac_objectget("iElemGroup", nFloorRoof))
--toLog(string.format("curr.elemgroup=%s elem.plankinfo.vecz.z=%f", curr.elemgroup, elem.plankinfo.vecz.z))
			end
	
			ac_objectclose()
			
			tblRes[#tblRes+1]=curr
		end
	end

	return tblRes
end


-- Called by renumber dialog to update UI fields
-- Returns table having fields:
-- name			Name to show in the list
-- NOT USED: enableUnique	true=check box Assign unique ID to every element should be enabled, if missing or false it is disabled
-- Order to assign IDs fields will be disabled for script based ID
function RenumGetUI()
	local s, t
	
	s=af_request("aflang")
	t={}
	t.name="Order planks by element ID and assign IDs based on the role in the element"
	if s=="fin" then
		t.name="Järjestä kapulat elementtitunnuksen mukaan ja liitä ID:hen kappaleen rooli elementissä"
	end
	--t.enableUnique=true
	return t
end


-- tblGroupedElems is 1-based array having grouped elements as GUIDs or @pointers again as 1-based array:
--   first item in first group is tblGroupedElems[1][1], second tblGroupedElems[1][2] etc.
-- tblSettings has fields
--   unique	Was unique checked or not
--   startid	What was entered into Starting ID edit-field
-- Returns: true=numbers given, false=error message shown and cancel further processing
-- If true, two additional ret values: how many elems processed and number of different IDs to status text field
function RenumDo(tblGroupedElems, tblSettings)
	local	tblElems, i1, startnum, elem, idformat
	
	-- Check number
	startnum=tonumber(tblSettings.startid)
	if not startnum then
		toLog("Please enter the starting number as number only")
		return false
	end
	idformat=string.format("%%0%dd", string.len(tblSettings.startid))
	
	-- Make flat table
	tblElems=MakeLinearElems(tblGroupedElems, tblSettings.unique)
	
	-- Sort by element ID etc. Primary sort key is element ID to assign plank IDs in element ID order
	table.sort(tblElems, function (t1, t2)
		if t1.plankinfo.ownerelemid and t2.plankinfo.ownerelemid then
			if t1.plankinfo.ownerelemid~=t2.plankinfo.ownerelemid then
				return t1.plankinfo.ownerelemid<t2.plankinfo.ownerelemid
			end
			-- Inside an element use original grouping order
		elseif t1.plankinfo.ownerelemid then
			return true		-- Elements first
		elseif t2.plankinfo.ownerelemid then
			return false	-- Elements first
		end
		
		-- Element comparison done, the sort by original grouping order
		if t1.groupid~=t2.groupid then
			return t1.groupid < t2.groupid
		end
		
		-- Similar planks, now order by elemgroup
		return t1.elemgroup < t2.elemgroup
	end)
	
	-- Build unique grouping strings and table from that to the indexes in tblElems
	local tblGroup2Elem, v
	
	tblGroup2Elem={}
	i1=1
	while true do
		elem=tblElems[i1]
		if not elem then
			break
		end
		elem.groupstr=string.format("%08d %s", elem.groupid, elem.elemgroup)
		
		-- Then from groupstr to indexes
		v=tblGroup2Elem[elem.groupstr]
		if not v then
			v={}
			tblGroup2Elem[elem.groupstr]=v
		end
		v[#v+1]=i1

		i1=i1+1
	end
	
--toLog("tblElems")
--DumpTbl(tblElems)

--toLog("tblGroup2Elem")
--DumpTbl(tblGroup2Elem)
	
	-- Keep numbering for each group, one group can be "" meaning it does not have any prefix
	local num, tblNums, i2, s			-- key=elemgroup, value=starting number
	local totElems, diffNums
	
	totElems = 0
	diffNums = 0
	tblNums={}
	i1=1
	while true do
		elem=tblElems[i1]
		if not elem then
			break
		end
		i1=i1+1
		
		if not elem.handled then
			local id
			
			num=tblNums[elem.elemgroup]
			if not num then
				num=startnum
			end
			tblNums[elem.elemgroup]=num+1			-- To be used next
			diffNums=diffNums+1
			
--toLog("ELEM")
--DumpTbl(elem)

--toLog("tblNums")
--DumpTbl(tblNums)

			id=string.format(idformat, num)	
			if elem.elemgroup~="" then
				id=string.format("%s %s", elem.elemgroup, id)
			end
--toLog(string.format("id=%s", id))
			
			-- Assign ID to all elements in this groupstr (it includes current item also, elem)
			v=tblGroup2Elem[elem.groupstr]
			i2=1
			while true do
				if not v[i2] then
					break
				end

				elem=tblElems[v[i2]]
				i2=i2+1
				
				elem.handled=true
				ac_objectopen(elem.plankinfo.ptr)
				ac_objectset("#id", id)
				ac_objectclose()
				totElems=totElems+1
			end
		end
	end

	return true, totElems, diffNums
end
