-- Handles certain parts of writing CNC-file. Please see OnXxxx functions for details.
-- See www.lua.org for Lua manual.
-- Extension functions - see manual


---------------------------------------------------------------------------
-- CODE SHARED WITH ARCHIFRAME START -->

EPS=0.0001
PI=3.141592653589793
PI2=PI/2.0
PI180=PI/180.0
PI1800=PI/1800.0

gbBvnForceUnid=false			-- For internal testing purposes

-- # Frame machinings types
EMcFrAngledBegOld	= 100
EMcFrAngledBeg		= 101
EMcFrAngledBegTenon = 110		-- Also dovetail (OLD)
EMcFrBegHiddenShoe	= 111
EMcFrAngledBegTenonMort = 112
EMcJointBeg			= 113
EMcVCutBeg			= 114
EMcFrAngledEndOld	= 200
EMcFrAngledEnd		= 201
EMcFrAngledEndTenon	= 210
EMcFrEndHiddenShoe	= 211
EMcFrAngledEndTenonMort = 212
EMcJointEnd			= 213
EMcVCutEnd			= 214



EMcFrOpening		= 300		-- Opening - unused now
EMcFrGroove			= 301		-- Logsin tapainen vapaa ura
EMcFrDrill			= 302		-- Drilling
EMcFrMarking		= 303		-- Marking
EMcFrReinforce		= 304
EMcFrSaw			= 305
EMcFrNailGroup		= 306
EMcFrNailLine		= 307

EMcFrTenonSide		= 400		-- Also dovetail
EMcFrBalkJoint		= 401		-- Narrowed balk

EMcFrBeamFemale		= 901		-- Ostlaft takås balk joint in log G2 etc

EMcFrBalkShoe		= 1000


gnSortPosLast=9999			-- If you want the machining to be the last one(s)

---------------------------------------------------------------------------
-- ARCHIFRAME & ARCHILOGS COMMON FUNCTIONS

function toLog(str)
	ac_environment("tolog", str)
end


-- Table copy values
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end



-- Returns 32bit binary number string "010011100..."
function NumToBin(nVal)
	local	nExp, sBin
	
	nExp=2147483648
	sBin=""
	repeat
		if nVal+0.1>=nExp then
			nVal=nVal-nExp
			sBin=sBin .. "1"
		else
			sBin=sBin .. "0"
		end	
		
		nExp=nExp/2
	until nExp<0.9
	
	if string.len(sBin)~=32 then
		error( "NumToBin failed" )
	end

	return sBin
end


function BitTest(nVal, nBit0based)
	local	s, s2
	
	s=NumToBin(nVal)
	s2=string.sub(s, 32-nBit0based, 32-nBit0based)
	if s2=="0" then
		return 0
	end
	if s2=="1" then
		return 1
	end

	error( string.format("BitTest failed (s=%s, s2=%s)", s, s2) )
end


-- Removes spaces from beg and end
function TrimStr(str)
	local	res, start, endIndex, len

	len=string.len(str)
	start=1
	while start<=len and string.sub(str,start,start)==" " do
		start=start+1
	end

	endIndex=len
	while endIndex>0 and string.sub(str,endIndex,endIndex)==" " do
		endIndex=endIndex-1
	end
	
	return string.sub(str,start, endIndex)
end


-- Finds key=val from string having \n as separator
-- Returns: nil=not found, str=value for requested key
function FindKeyVal(strData, keyFind)
	local i1,i2,s2,firstmsg

	firstmsg=true
	i1=1
	while i1<string.len(strData) do
		i2=string.find(strData, "\n", i1, true)
		if not i2 then
			i2=string.len(strData)+1
		end

		s2=string.sub(strData, i1, i2-1)
		i1=i2+1			-- Advance to next

		local key, val

		key,val=string.match(s2, "^%s*(.-)%s*=%s*(.-)%s*$")		-- Lua magic!!

--toLog(string.format("KEYVAL %s: key=%s val=%s", strData, key, val))
		if key and key==keyFind then
			return val
		end
	end
	return nil
end


-- Aiheuttaa virheilmoituksen, jonka Logs osaa tulkita käyttäjälle näytettäväksi viestiksi
-- Ilmoitus voi olla tyhjä, jolloin ei näytetä mitään (peruttu)
function RaiseError(msg)
	msg="###>" ..  msg .. "<###"
	error( msg )
end

gnCncErrCount=0			-- Notices for the log

-- Adds cnc error message to gTblCncErr
function AddErrMsg(sLogId, nPos, sText)
	if nPos==nil then error("AddCncErr/nPos") end
	if sText==nil then error("AddCncErr/sText") end

	if gnCncErrCount==0 then
		gTblCncErr={}
	end

	gnCncErrCount=gnCncErrCount+1
	gTblCncErr[gnCncErrCount] = {}
	gTblCncErr[gnCncErrCount].guid=gsCurrentLogGuid
	gTblCncErr[gnCncErrCount].logid=sLogId
	gTblCncErr[gnCncErrCount].pos=nPos
	gTblCncErr[gnCncErrCount].text=sText
end



-- Adds cnc error message to gTblCncErr
function AddCncErr(nPos, sText)
	AddErrMsg(gsCurrentLogId, nPos, sText)
end


-- Dumps given variable into string
function DumpTblInt(o, nIndent)
  local s,k,v
  
  if type(o) == 'table' then
    s = '{\n'
    for i = 0, nIndent do
      s = s .. '\t'
    end
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. DumpTblInt(v, nIndent + 1) .. ',\n'
      for i = 0, nIndent do
        s = s .. '\t'
      end
    end
    if string.len(s) > 1 then
      if string.sub(s, -1) == '\t' then
        s = string.sub(s, 1, -2)
      end
    end
    s=s .. '}'
  else
    s = ""
    for i = 0, nIndent do
      s = s .. '\t'
    end
    s=tostring(o)
  end
  return s
end


-- Dumps a table to the log window with indentation.
function DumpTbl(o)
  ac_environment("tolog", DumpTblInt(o, 0))
end


gtblUsedIds = {}				-- Tänne asetetaan ["id"]=1, että löydetään samalla ID:llä olevat hirret

function CheckId( sId )
	if sId=="" then
		AddCncErr( 0, string.format("LOG/FRAME EMPTY ID FOUND") )
	elseif gtblUsedIds[sId]~=null then
		AddCncErr( 0, string.format("LOG/FRAME ID %s USED AT LEAST TWICE", sId) )
	else
		gtblUsedIds[sId]=1
	end
end


-- User entered values may be small if millimeters were used
function NormalizeType(nNum)
	if math.abs(nNum)<0.1 then
		nNum=math.floor(nNum*1000+0.5)
	end
	return nNum
end



-- # Info field definitions (11/2017), same code shared in bvn&btl
EInfoNone			= 1			-- No text to this field
EInfoFullIDPlusUsage= 2			-- Full ID (usage)
EInfoShortID		= 3			-- For example EW01-07 will give only 07 excluding wall etc id
EInfoFullID			= 4			-- For example EW01-07 will give full EW01-07
EInfoElementID		= 5			-- The owning element's ID part (EW01)
EInfoUsage			= 6			-- Plank's usage
EInfoMatIdFull		= 7			-- Full material ID
EInfoMatIdShort		= 8			-- Material ID everything removed from last space bar
EInfoGrade			= 9			-- Find grade C24/C18/IMP from material type (any text after plank IDs last space bar)
EInfoMatIdIfNotSize	= 10		-- Add material ID if different from width x size
EInfoPlankRole		= 11		-- Role in element
EInfoPlankRoleFin	= 12		-- Role in element Finnish
EInfoPlankRoleNor	= 13		-- Role in element Norsk
EInfoPlankRoleShort	= 14		-- Stud=ST
EInfoPlankRoleShortFin= 15		-- Tolppa=TO
EInfoPlankRoleShortNor=16		-- Norsk short
EInfoPackageOrElemID=17			-- iPackage or if it is empty, EInfoElementID
EOwnerElemID		=18			-- Parenting element's ID
EInfoFloorNum		=19


-- Returns element ID, plank ID. For example for EW01-07 will return "EW01","07""
function SplitId(id, plankinfo)
	local elemid, s, pos

    s="-"     -- This is the master plank not showing the short ID probably: ac_objectget("iShowIDSep")
    if plankinfo.type==4 then
      s="#"   -- board
    end

	elemid=id
    -- Find element ID
    --pos=string.find(id, s, 1, true)   -- No reverse find in Lua
    pos=string.len(id)
    while pos>=1 do
		if string.sub(id,pos,pos)==s then
			break
		end
		pos=pos-1
    end

	elemid=""
	if pos>1 then
		elemid=string.sub(id, 1, pos-1)
	end

    id=string.sub(id, pos+1)
	return elemid, id
end


-- Splits material ID to two parts from last space. If no space, last part will be ""
function SplitMatId()
	local elemid, s, id, grade, pos

    s=" "     -- Separator
	id=ac_objectget("iMatId")

    pos=string.len(id)
    while pos>=1 do
		if string.sub(id,pos,pos)==s then
			break
		end
		pos=pos-1
    end
	grade=""
	if pos>1 then
		grade=string.sub(id, pos+1)
		id=string.sub(id, 1, pos-1)
	end

	return id, grade
end


-- COMMON FUNCTION IN A FEW PLACES IN DATA-FOLDER, UPDATE ALL IF UPDATING ONE
-- isHor  Is it horizontal structure (false/nil=default)
-- lang   eng/swe/fin
-- elemgroup  Parameter iElemGroup
function GetElemGroupName(isHor, elemgroup)
  local lang
  
  lang=af_request("aflang")
  if isHor then
    -- Horizontal structure
    if elemgroup==nil then
      elemgroup=""
    elseif string.match(elemgroup, "^top%a*") or string.match(elemgroup, "^2ndtop%a*") or string.match(elemgroup, "^contour_x.*") then
      elemgroup="Stud"
      if lang=="fin" then
        elemgroup="Tolppa"
      elseif lang=="swe" then
        elemgroup="Regel"
      end
    elseif string.match(elemgroup, "^bottom%a*") or string.match(elemgroup, "^2ndbottom%a*") then
      elemgroup="Stud"
      if lang=="fin" then
        elemgroup="Tolppa"
      elseif lang=="swe" then
        elemgroup="Regel"
      end
    elseif string.match(elemgroup, "^vertical_x%a*") or string.match(elemgroup, "^vertical_y%a*") or string.match(elemgroup, "^contourtilted_opening%a*") then
      elemgroup="Door/win"
      if lang=="fin" then
        elemgroup="Ikk/ovi"
      elseif lang=="swe" then
        elemgroup="Avväxling"
      end
    elseif string.match(elemgroup, "^vertical%a*") then
      elemgroup="Hor"
      if lang=="fin" then
        elemgroup="Vaaka"
      end
    elseif string.match(elemgroup, "^contourtilted%a*") then
      elemgroup="Angled"
      if lang=="fin" then
        elemgroup="Vinojuoksu"
      elseif lang=="swe" then
        elemgroup="Regel"
      end
    elseif string.match(elemgroup, "^balk.*") then
      elemgroup="Beam"
      if lang=="fin" then
        elemgroup="Palkki"
      elseif lang=="swe" then
        elemgroup="Bärlina"
      end
    elseif string.match(elemgroup, "^lintel.*") then
      elemgroup="W/D beam"
      if lang=="fin" then
        elemgroup="Aukkopalkki"
      elseif lang=="swe" then
        elemgroup="Bärplanka"
      end
    elseif string.match(elemgroup, "^reinforce.*") then
      elemgroup="Reinforcement"
      if lang=="fin" then
        elemgroup="Vahvike"
      elseif lang=="swe" then
        elemgroup="Förstärkning"
      end
    elseif string.match(elemgroup, "^nogging.*") then
      elemgroup="Nogging"
      if lang=="nor" then
        elemgroup="Kubbing"
      elseif lang=="fin" then
        elemgroup="Nurjahdustuki"
      elseif lang=="swe" then
        elemgroup="Kortling"
      end
    elseif elemgroup=="sideleft_spacing" or elemgroup=="sideright_spacing" then
      elemgroup="Side beams"
      if lang=="fin" then
        elemgroup="Sivupalkki"
      elseif lang=="swe" then
        elemgroup="Ändkortling"
      end
    else
      elemgroup=""    -- Just leave it empty, earlier was "? (elemgroup)"
    end
  else
    -- Vertical structure
    if elemgroup==nil then
      elemgroup=""
    elseif string.match(elemgroup, "^top%a*") or string.match(elemgroup, "^2ndtop%a*") then
      elemgroup="Top plate"
      if lang=="fin" then
        elemgroup="Yläjuoksu"
      elseif lang=="swe" then
        elemgroup="HB"
      end
    elseif string.match(elemgroup, "^bottom%a*") or string.match(elemgroup, "^2ndbottom%a*") then
      elemgroup="Bottom plate"
      if lang=="fin" then
        elemgroup="Alajuoksu"
      elseif lang=="swe" then
        elemgroup="Syll"
      end
    elseif string.match(elemgroup, "^contour_x.*") then
      elemgroup="Top/bottom plate"
      if lang=="fin" then
        elemgroup="Ylä/alajuoksu"
      elseif lang=="swe" then
        elemgroup="HB/Syll"
      end
    elseif string.match(elemgroup, "^vertical_x%a*") or string.match(elemgroup, "^contourtilted_opening%a*") then
      elemgroup="Win/door"
      if lang=="fin" then
        elemgroup="Ikk/ovi"
      elseif lang=="swe" then
        elemgroup="Avväxling"
      end
    elseif string.match(elemgroup, "^vertical%a*") or string.match(elemgroup, "^contour_y.*") then
      elemgroup="Stud"
      if lang=="fin" then
        elemgroup="Tolppa"
      elseif lang=="swe" then
        elemgroup="Regel"
      end
    elseif string.match(elemgroup, "^contourtilted%a*") then
      elemgroup="Angled"
      if lang=="fin" then
        elemgroup="Vinojuoksu"
      elseif lang=="swe" then
        elemgroup="Regel"
      end
    elseif string.match(elemgroup, "^balktop.*") then
      elemgroup="Beam top"
      if lang=="fin" then
        elemgroup="Palkki ylä"
      elseif lang=="swe" then
        elemgroup="Bärlina topp"
      end
    elseif string.match(elemgroup, "^balkbot.*") then
      elemgroup="Beam bottom"
      if lang=="fin" then
        elemgroup="Palkki ala"
      elseif lang=="swe" then
        elemgroup="Bärlina botten"
      end
    elseif string.match(elemgroup, "^lintel.*") then
      elemgroup="W/D beam"
      if lang=="fin" then
        elemgroup="Aukkopalkki"
      elseif lang=="swe" then
        elemgroup="Bärplanka"
      end
    elseif string.match(elemgroup, "^nogging.*") then
      elemgroup="Nogging"
      if lang=="nor" then
        elemgroup="Kubbing"
      elseif lang=="fin" then
        elemgroup="Nurjahdustuki"
      elseif lang=="swe" then
        elemgroup="Kortling"
      end
    elseif elemgroup=="sideleft_spacing" or elemgroup=="sideright_spacing" then
      elemgroup="Side beams"
      if lang=="fin" then
        elemgroup="Sivupalkki"
      elseif lang=="swe" then
        elemgroup="Ändkortling"
      end
    else
      elemgroup=""    -- Just leave it empty, earlier was "? (elemgroup)"
    end
  end
  
  return elemgroup
end


-- nInfo	One of EInfoXxxx
function GetInfoStr(nInfo, plankinfo)
	local	s, s2

	s=""
	if nInfo==EInfoFullIDPlusUsage then
		s=ac_objectget("iUsageId")
		if not s then
			s=""
		end
		if s~="" then
			s=string.format( "%s (%s)", gsCurrentLogId, s)
		else
			s=gsCurrentLogId
		end
	elseif nInfo==EInfoShortID then
		s2, s=SplitId(gsCurrentLogId, plankinfo)
	elseif nInfo==EInfoFullID then
		s=gsCurrentLogId
	elseif nInfo==EInfoElementID then
		s, s2=SplitId(gsCurrentLogId, plankinfo)
	elseif nInfo==EInfoPackageOrElemID then
		s=ac_objectget("iCncPackage")
		if s==nil or s=="" then
			s, s2=SplitId(gsCurrentLogId, plankinfo)
		end
	elseif nInfo==EInfoGrade then
		s2, s=SplitMatId()
	elseif nInfo==EInfoUsage then
		s=ac_objectget("iUsageId")
	elseif nInfo==EInfoMatIdFull then
		s=ac_objectget("iMatId")
	elseif nInfo==EInfoMatIdShort then
		s, s2=SplitMatId()
	elseif nInfo==EInfoMatIdIfNotSize then
		s=ac_objectget("iMatId")
		if s==string.format("%.0fx%.0f", gnCurrWidth*1000, gnCurrHeight*1000) then
			s=""
		end
	elseif nInfo==EInfoPlankRole then
		s=ac_objectget("iElemGroup")
		s=GetElemGroupName(false, s)
	elseif nInfo==EInfoPlankRoleShort then
		s=ac_objectget("iElemGroup")
        if s==nil then
          s=""
        elseif string.match(s, "^top%a*") or string.match(s, "^2ndtop%a*") then
          s="TP"
        elseif string.match(s, "^bottom%a*") or string.match(s, "^2ndbottom%a*") then
          s="BP"
        elseif string.match(s, "^vertical_x%a*") or string.match(s, "^contourtilted_opening%a*") then
          s="HO"
        elseif string.match(s, "^vertical%a*") then
          s="ST"
        elseif string.match(s, "^contourtilted%a*") then
          s="AN"
        elseif string.match(s, "^balk%a*") then
          s="BE"
        elseif string.match(s, "^lintel.*") then
          s="LI"
		else
		  s=""
		end
	elseif nInfo==EInfoPlankRoleFin then
		s=ac_objectget("iElemGroup")
        if s==nil then
          s=""
        elseif string.match(s, "^top%a*") or string.match(s, "^2ndtop%a*") then
          s="Yläjuoksu"
        elseif string.match(s, "^bottom%a*") or string.match(s, "^2ndbottom%a*") then
          s="Alajuoksu"
        elseif string.match(s, "^vertical_x%a*") or string.match(s, "^contourtilted_opening%a*") then
          s="Ikk/ovi"
        elseif string.match(s, "^vertical%a*") then
          s="Tolppa"
        elseif string.match(s, "^contourtilted%a*") then
          s="Vinojuoksu"
        elseif string.match(s, "^balk%a*") then
          s="Palkki"
        elseif string.match(s, "^lintel.*") then
          s="Aukkopalkki"
		end
	elseif nInfo==EInfoPlankRoleShortFin then
		s=ac_objectget("iElemGroup")
        if s==nil then
          s=""
        elseif string.match(s, "^top%a*") or string.match(s, "^2ndtop%a*") then
          s="YJ"
        elseif string.match(s, "^bottom%a*") or string.match(s, "^2ndbottom%a*") then
          s="AJ"
        elseif string.match(s, "^vertical_x%a*") or string.match(s, "^contourtilted_opening%a*") then
          s="VA"
        elseif string.match(s, "^vertical%a*") then
          s="T"
        elseif string.match(s, "^contourtilted%a*") then
          s="VI"
        elseif string.match(s, "^balk%a*") then
          s="PA"
        elseif string.match(s, "^lintel.*") then
          s="AU"
		else
		  s=""
		end
	elseif nInfo==EInfoPlankRoleNor then
		s=ac_objectget("iElemGroup")
        if s==nil then
          s=""
        elseif string.match(s, "^top%a*") or string.match(s, "^2ndtop%a*") then
          s="Toppsvill"
        elseif string.match(s, "^bottom%a*") or string.match(s, "^2ndbottom%a*") then
          s="Bunnsvill"
        elseif string.match(s, "^vertical_x%a*") or string.match(s, "^contourtilted_opening%a*") then
          s="Vindu/dør"
        elseif string.match(s, "^vertical%a*") then
          s="Stender"
        elseif string.match(s, "^contourtilted%a*") then
          s="Vinkel"
        elseif string.match(s, "^balk%a*") then
          s="Bjelke"
        elseif string.match(s, "^lintel.*") then
          s="Overdekning"
		end
	elseif nInfo==EInfoPlankRoleShortNor then
		s=ac_objectget("iElemGroup")
        if s==nil then
          s=""
        elseif string.match(s, "^top%a*") or string.match(s, "^2ndtop%a*") then
          s="TS"
        elseif string.match(s, "^bottom%a*") or string.match(s, "^2ndbottom%a*") then
          s="BS"
        elseif string.match(s, "^vertical_x%a*") or string.match(s, "^contourtilted_opening%a*") then
          s="LH"
        elseif string.match(s, "^vertical%a*") then
          s="ST"
        elseif string.match(s, "^contourtilted%a*") then
          s="LH"
        elseif string.match(s, "^balk%a*") then
          s="BJ"
        elseif string.match(s, "^lintel.*") then
          s="OD"
		else
		  s=""
		end
	elseif nInfo==EOwnerElemID then
		local info

		info=af_request("plankinfo")
		if info.ownerelemguid then
			s=ac_getobjparam(info.ownerelemguid, "#id")
		end
	elseif nInfo==EInfoFloorNum then
		local info

		s=string.format("%d", ac_objectget("#floor"))
	end

	if s==nil then
		s=""
	end
	return s
end


---------------------------------------------------------------------------
-- ARCHIFRAME & ARCHILOGS GEOMETRY FUNCTIONS

-- ### Alustaa muuttujan tranTbl[] pyörittämään ja siirtämään pistettä
-- Katso http://gregs-blog.com/category/3d-mathematics/
-- in:
-- 	vecX,vecY,vecZ	Vektori, jonka ympärillä pyöritellään. Yksikkövektori!!
-- 	addX,addY,addZ	Siirto
-- 	angle			Pyörityskulma
-- out:
--	tranTbl[12]
function Rotate3Dinit(vecX, vecY, vecZ, addX, addY, addZ, angle)
	local	cosAngle, sinAngle, ucosAngle, tranTbl

	cosAngle=math.cos(angle)
	sinAngle=math.sin(angle)
	ucosAngle=1-cosAngle
	tranTbl={}

	-- Tehdään yksikkövektori
	--_ulen=1/sqr(vecX*vecX+vecY*vecY+vecZ*vecZ)
	--vecX=vecX*_ulen
	--vecY=vecY*_ulen
	--vecZ=vecZ*_ulen

	tranTbl[1]=ucosAngle*vecX*vecX+cosAngle
	tranTbl[2]=ucosAngle*vecX*vecY-vecZ*sinAngle
	tranTbl[3]=ucosAngle*vecZ*vecX+vecY*sinAngle
	tranTbl[4]=addX

	tranTbl[5]=ucosAngle*vecX*vecY+vecZ*sinAngle
	tranTbl[6]=ucosAngle*vecY*vecY+cosAngle
	tranTbl[7]=ucosAngle*vecY*vecZ-vecX*sinAngle
	tranTbl[8]=addY

	tranTbl[9]=ucosAngle*vecZ*vecX-vecY*sinAngle
	tranTbl[10]=ucosAngle*vecY*vecZ+vecX*sinAngle
	tranTbl[11]=ucosAngle*vecZ*vecZ+cosAngle
	tranTbl[12]=addZ

	--tranTbl[13]=0
	--tranTbl[14]=0
	--tranTbl[15]=0
	--tranTbl[16]=1
	return tranTbl
end


-- ### Pyörittää 3D-pistettä annetun vektorin ympäri. Kutsu Rotate3Dinit ennen tätä.
-- in:
-- xin, yin, zin
-- out:
-- x, y, z
function Rotate3D(tranTbl, xin, yin, zin)
	local	x, y, z
	
	x=tranTbl[1]*xin + tranTbl[2]*yin + tranTbl[3]*zin	+ tranTbl[4]
	y=tranTbl[5]*xin + tranTbl[6]*yin + tranTbl[7]*zin + tranTbl[8]
	z=tranTbl[9]*xin + tranTbl[10]*yin + tranTbl[11]*zin + tranTbl[12]
	return x,y,z
end



-- ### Pyörittää 3D-pistettä annetun vektorin ympäri pitäen edellisen Rotate3DInit-arvot kuosissa
-- in:
-- xin, yin, zin, angle
-- vecX, vecY, vecZ	Minkä vektorin ympäri pyöritellään
-- out:
-- _x, _y, _z
function RotateSingle3D(xin, yin, zin, vecX, vecY, vecZ, angle)
	local	x, y, z, tranTbl

	tranTbl = Rotate3Dinit(vecX, vecY, vecZ, 0, 0, 0, angle)
	x,y,z=Rotate3D(tranTbl,xin, yin, zin)
	return x,y,z
end



-- Calculates cross product of two vectors
-- Katsele http://en.wikipedia.org/wiki/Cross_product: On se suunta tälläkin tiedossa: vec1 on oikean käden etusormi, vec2 keskari ja refRes on sitten peukalo ylös
-- returns x,y,z
function CalcCross3D( x1, y1, z1, x2, y2, z2 )
	local x,y,z
	
	x = y1 * z2 - z1 * y2
	y = z1 * x2 - x1 * z2
	z = x1 * y2 - y1 * x2
	return x,y,z
end


-- Sets len to 1
-- Returns x,y,z,bOkVec (true/false=zero len)
function ToUnitVec3(x, y, z)
	local	d
	
	d=math.sqrt(x*x+y*y+z*z)
	if d<0.0001 then
		return 0,0,0,false
	end
	d=1/d
	return x*d,y*d,z*d,true
end


-- ## Calculates 3D point distance from plane
-- pos=in normal vector's dir, neg=on the back side
function DistFromPlane(x, y, z, pa, pb, pc, pd)
	return pa * x + pb * y + pc * z + pd
end


-- Calculates plane equation from normal vector and a point on the plane x1, y1, z1
-- Note! Plane constant having different sign compared to Wykobi
-- in:
--	tnx, tny, tnz	Plane normal, calculated to unit vec here
--	x1,y1,z1		Point on the plane
-- Returns:
--	ta, tb, tc, td	Plane equation (ta,tb,tc=normal vector of the plane as unit)
function MakePlaneNormal(tnx, tny, tnz, x1, y1, z1)
	--   template<typename T>
	--   inline plane<T,3> make_plane(const T& x1, const T& y1, const T& z1,
	--								const T& x2, const T& y2, const T& z2,
	--								const T& x3, const T& y3, const T& z3)
	--   {
	--	  plane<T,3> plane_;
	--	  vector3d<T> v1 = makevector(x2 - x1, y2 - y1, z2 - z1);
	--	  vector3d<T> v2 = makevector(x3 - x1, y3 - y1, z3 - z1);
	--	  plane_.normal   = normalize(v1 * v2);
	--	  plane_.constant = dot_product(plane_.normal,makevector(x1,y1,z1));
	--	  return plane_;
	--   }
	local mul, ta, tb, tc, td

	-- Tässä hypätään suoraan vakion laskentaan
	mul=math.sqrt(tnx*tnx+tny*tny+tnz*tnz)
	if math.abs(mul)<0.00001 then
		return 0, 0, 0, 0
	end

	mul=1/mul
	ta=tnx*mul
	tb=tny*mul
	tc=tnz*mul
	td=-(ta*x1+tb*y1+tc*z1)
	return ta, tb, tc, td
end



-- ### Sector and plane intersection
-- in: 
--	ta,tb,tc,td		Plane equation, a-c=normal, d=distance from zero
--   x1, y1, z1		sector
--   x2, y2, z2		sector
-- out:
--	hasX			Was there an intersection
--	x, y, z			Point
--   dist			Distance from point x1,y1,z1 in line's dir (relative to the sector's length 0...1!)
function LinePlaneX(ta, tb, tc, td, x1, y1, z1, x2, y2, z2 )
	-- Tuollainen koodi "käännetty" wykobi-kirjastosta
	--   template<typename T>
	--   inline point3d<T> intersection_point(const line<T,3>&  line,
	--										const plane<T,3>& plane)
	--   {
	--	  vector3d<T> linevec = line[1] - line[0];
	--	  T denom = dot_product(linevec,plane.normal);
	--	  point3d<T> ipoint = degenerate_point3d<T>();
	--	  if (not_equal(denom,T(0.0)))
	--	  {
	--		 T t = -distance(line[0],plane) / denom;
	--		 ipoint = line[0] + t * (line[1] - line[0]);
	--	  }
	--	  return ipoint;
	--   }
	local x, y, z, dist, denom


	dist=0

	x=x2-x1
	y=y2-y1
	z=z2-z1

	denom=x*ta + y*tb + z*tc		-- Pistetulo suora ja tason normaali
	if math.abs(denom)<1E-5 then
		-- Tason suuntainen suora
		return false
	end

	-- Pisteen etäisyys tasolta
	-- (plane.normal.x * point.x + plane.normal.y * point.y + plane.normal.z * point.z ) - plane.constant;

	dist=-(ta*x1 + tb*y1 + tc*z1 + td)/denom		-- Huom-- td eri etumerkillä kuin wykobissa (kun siellä oli puki)
	x=x1 + x*dist
	y=y1 + y*dist
	z=z1 + z*dist
	return true, x, y, z, dist
	-- To return correct dist: return true, x, y, z, dist*math.abs(denom)
end

-- Returns unit vector 90 degrees left x,y for given vector
function GetUnitVecLeft(x, y)
	local	len
	
	len=math.sqrt(x*x+y*y)
	if len<EPS then
		return 0,0
	end
	return -y/len,x/len
end


function GetSqr(x)
	return x*x
end


-- Calculates intersection of two infinite lines
-- Line1 is (x1,y1)->(x2,y2) and line2 is (x3,y3)->(x4,y4)
-- See http://local.wasp.uwa.edu.au/~pbourke/geometry/lineline2d/
-- Returns three values:
-- 1. bool, true=has intersection
-- 2. number, x
-- 3. number, y
function GetLinesX( x1, y1, x2, y2, x3, y3, x4, y4 )
	local ua, divisor

	divisor=(y4-y3)*(x2-x1)-(x4-x3)*(y2-y1)
	if math.abs(divisor)<EPS then
		return false,0,0
	end

	ua=((x4-x3)*(y1-y3)-(y4-y3)*(x1-x3))/divisor
	return true, x1+ua*(x2-x1), y1+ua*(y2-y1)
end


function AngleTo2PI(a)
	if a<0 then
		a=2*PI+a
	end
	return a
end

-- Checks if point (rx1,ry1) is in given angle of circle having center x1,y1
function PointInArc(x1, y1, rx1, ry1, limita, limitalen)
	local	a, a1, a2

	a=AngleTo2PI(math.atan2(ry1-y1, rx1-x1))
	a1=AngleTo2PI(limita)
	a2=AngleTo2PI(limita+limitalen)
	if a1>a2 then
		a1,a2=a2,a1
	end

	if a>a1-EPS and a<a2+EPS then
		return true
	end

--toLog(string.format("Point not in arc a1=%f a2=%f a=%f", a1, a2, a))
	return false
end


-- limita		If given, limit for circle1 arc's starting angle
-- limitalen	If given, length of arc's angle
-- Returns intersection points x1,y1, x2,y2 (all nil if no intersection, just x1,y1 if just one intersection)
function GetCirclesX(x1, y1, r1, x2, y2, r2, limita, limitalen)
	local d, dx, dy, x, y

	dx=x2-x1
	dy=y2-y1
	d=math.sqrt(dx*dx + dy*dy)
	if d<EPS or d>r1+r2 or d<math.abs(r1-r2) then
--toLog(string.format("x1=%f y1=%f r1=%f x2=%f y2=%f r2=%f: NO X", x1, y1, r1, x2, y2, r2))
		return		-- Too far or inside each other
	end

	dx=dx/d
	dy=dy/d

	x=(r1 * r1 - r2 * r2 + d * d) / (d + d)
	y=math.sqrt(r1*r1 - x * x)

	local rx1, ry1, rx2, ry2

	rx1=x1 + x*dx - y*dy
	ry1=y1 + x*dy + y*dx

	rx2=x1 + x*dx + y*dy
	ry2=x1 + x*dy - y*dx

	if math.sqrt(GetSqr(rx2-rx1) + GetSqr(ry2-ry1))<EPS then
		-- Single point
		rx2=nil
		ry2=nil
	end

	if limita then
		-- Discard angles not in range
		if rx2 and not PointInArc(x1, y1, rx2, ry2, limita, limitalen) then
			rx2=nil
			ry2=nil
		end
		if rx1 and not PointInArc(x1, y1, rx1, ry1, limita, limitalen) then
			rx1=rx2
			ry1=ry2
			rx2=nil
			ry2=nil
		end
	end

--toLog(string.format("x1=%f y1=%f r1=%f x2=%f y2=%f r2=%f rx1=%f ry1=%f rx2=%s ry2=%s", x1, y1, r1, x2, y2, r2, rx1, ry1, tostring(rx2), tostring(ry2)))
	return rx1, ry1, rx2, ry2
end


-- cx,cy,cr	Circle
-- Returns intersection points x1,y1, x2,y2 (all nil if no intersection, just x1,y1 if just one intersection)
function GetLineCircleX(x1, y1, x2, y2, cx, cy, cr)
	local dx, dy, rx1, ry1, rx2, ry2
	local A,B,C,det,t

    dx = x2 - x1
    dy = y2 - y1

    A = dx * dx + dy * dy
    B = 2 * (dx * (x1 - cx) + dy * (y1 - cy))
    C = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy) - cr * cr

    det = B * B - 4 * A * C
    if A<EPS or det<0 then
		-- No real solutions
--toLog(string.format("x1=%f, y1=%f, x2=%f, y2=%f, cx=%f, cy=%f, cr=%f: NO", x1, y1, x2, y2, cx, cy, cr))
		return
	end

	-- First point
    t = (-B + math.sqrt(det)) / (A+A)
    rx1=x1 + t * dx
	ry1=y1 + t * dy
    if math.abs(det)>1E-10 then
        -- Two solutions.
        t = (-B - math.sqrt(det)) / (A+A)
        rx2=x1 + t * dx
		ry2=y1 + t * dy
	end

--toLog(string.format("x1=%f, y1=%f, x2=%f, y2=%f, cx=%f, cy=%f, cr=%f: rx1=%f, ry1=%f, rx2=%s, ry2=%s det=%f EPS=%f", x1, y1, x2, y2, cx, cy, cr, rx1, ry1, tostring(rx2), tostring(ry2), det, EPS))
	return rx1, ry1, rx2, ry2
end


-- Laskee viistetyn kapulan päälle, paljonko viisteystasoa pitää siirtää sisäänpäin kapulaa, että leikkaisi oikein.
-- in:
--	tasoTbl[n][4]
--	tasoCount
-- out:
--	cutOffsets[5], [5]=refviiva
--	maxEt
function CutEndingWithPlanes(tasoTbl, tasoCount, width, height)
	local taso, cutOffsets, maxEt, yoff, zoff, x1, y1, z1, x2, y2, z2, ta, tb, tc, td
	local hasX, x, y, z, dist

	cutOffsets={}
	
	-- Nurkkapisteet
	yoff={}
	zoff={}
	
	yoff[1]=width*0.5
	zoff[1]=0

	yoff[2]=width*0.5
	zoff[2]=height

	yoff[3]=-width*0.5
	zoff[3]=height

	yoff[4]=-width*0.5
	zoff[4]=0
	
	yoff[5]=0
	zoff[5]=0
	
	for i=1,5 do
		cutOffsets[i]=1E10
	end

	-- Lasketaan paljonko kauimmainen pää jää tasosta (antaa keskipisteen tulla mukaan laskentaan)
	maxEt=0
	for taso=1, tasoCount do
		for i=1,5 do
			x1=0
			y1=yoff[i]
			z1 = zoff[i]
			x2=-1
			y2=y1
			z2=z1
			ta=tasoTbl[taso][1]
			tb=tasoTbl[taso][2]
			tc=tasoTbl[taso][3]
			td=tasoTbl[taso][4]
			hasX, x, y, z, dist = LinePlaneX(ta, tb, tc, td, x1, y1, z1, x2, y2, z2 )
			
			if hasX then
				-- Pitäisi aina olla, mutta... Haetaan sis lähin taso jokaiselle pisteelle
				if dist<cutOffsets[i] then 
					cutOffsets[i]=dist
				end
			end
		end
	end

	maxEt=-1e10
	for i=1,5 do
		if cutOffsets[i]>maxEt then 
			maxEt=cutOffsets[i]
		end
	end

	return cutOffsets, maxEt
end

-- GEOMETRY FUNCTIONS
---------------------------------------------------------------------------


-----------------------------------------------------------------------------
--                  HUNDEGGER BVN COMMON WITH ARCHIFRAME                   --
-----------------------------------------------------------------------------


-- Which side of the log is against the machine's base plate (not the table, suomeksi "vaste")
EBvnMale=0				-- Log top
EBvnFrontSide=1
EBvnFemale=2			-- Log bottom
EBvnBackSide=3
gnBvnPlateSide=EBvnFrontSide
gbK2Tenon=true			-- Rounded if true, oval if false

-- Which end goes first to the machine
EBvnDirBeg=0
EBvnDirEnd=1
gnBvnLogDir=EBvnDirBeg	-- Also for AF plank

-- Settings
gnBvnYoffset=0					-- Value to add to y-coordinate (in faces 2,4) to get current log's/plank's bottom. May be negative if overlap is below the piece.
gnBvnTopOverlap=0				-- Overlap at top of log (zero if lower half and always zero if overlap below the log)

--gbOpeningsWith0300=true			-- Use code 0300 for openings in addition with 0109
gbBvnNoSplinterFree=false		-- Set to true to never produce splinter free codes

gbDoveWith1700=false			-- true=make dovetail with 1700, false=use 1701
gnBvnLowerHalf=0				-- Does the topmost half of the wall have its own material (no halfing): 0=nope, 1=yes half material used (not fully supported)

gnBvnSawMaxDepth=0.250			-- Maximum depth for saw groove 0109, Hundegger blade diameter is about 700 mm and some of it is lost for table etc.
gnBvnSawR=0.375					-- Used with previous: Radius of 0109 blade


-- Hundegger writer globals
gnBvnPieceNum=1					-- Global piece number


-- true=xc needs to be mirrored, (end head goes first), false=nope
function BvnIsMirrorXc()
	return gnBvnLogDir==EBvnDirEnd
end


-- Kääntää jos menee loppu edellä
function BvnGetXc(nCoord)
	if gnBvnLogDir==EBvnDirBeg then
		return nCoord
	end
	return gnCurrTotLen-nCoord
end


-- bDoMirror	Optional: missing or true=mirror, false=do not mirror
function BvnMirrorYc(nCoord, logFace, bDoMirror)
	if bDoMirror==nil or bDoMirror==true then
		if logFace==1 or logFace==3 then
			return gnCurrWidth - nCoord
		end
	
		return gnProfHeight - nCoord
	end
	return nCoord
end


-- Returns +-1...4 for the log's beginning head (left side) depending on gnBvnLogDir and side
-- Second value: bool to mirror x-coordinates for the end face OK ONLY IF USING FACE 3 (bottom)
-- Third value: bool to mirror y-coordinates
function BvnGetLogBegBvnSide(logFace)
	local	mirrorX, mirrorY		-- nBvnSide was global earlier - don't take a risk making it local

	mirrorX=false
	mirrorY=false
	nBvnSide=BvnGetSide(logFace)
	if gnBvnLogDir==EBvnDirEnd then
		nBvnSide=-nBvnSide
	else
		mirrorX=true
	end
	return nBvnSide, mirrorX, mirrorY
end


-- Returns +-1...4 for the log's end head (right side) depending on gnBvnLogDir and side
function BvnGetLogEndBvnSide(logFace)
	local	face, mirrorX, mirrorY

	face, mirrorX, mirrorY = BvnGetLogBegBvnSide(logFace)
	return -face, mirrorX, mirrorY
end

-- For BvnGetBegEndMirrorY, first index is the log side against the machine (EBvnFemale etc), second is direction EBvnDirBeg/end
gBvnBegEndSides={
	[EBvnMale]		= { [EBvnDirBeg]=true,	[EBvnDirEnd]=true },
	[EBvnFrontSide]	= { [EBvnDirBeg]=false,	[EBvnDirEnd]=true },
	[EBvnFemale]	= { [EBvnDirBeg]=false,	[EBvnDirEnd]=false },
	[EBvnBackSide]	= { [EBvnDirBeg]=true,	[EBvnDirEnd]=false }
}

-- For machinins using -+3 face (beg/end)
function BvnGetBegEndMirrorY()
	return gBvnBegEndSides[gnBvnPlateSide][gnBvnLogDir]
end


-- For BvnGetSide, first index is ArchiLogs side 1...4 (top, front, bottom, back), second is the log side against the machine (EBvnFemale etc), third is direction EBvnDirBeg/end
gBvnSides={
	-- log top
	[1] = { 
			[EBvnMale]		= { [EBvnDirBeg]={4, true},	[EBvnDirEnd]={4, false} },
			[EBvnFrontSide]	= { [EBvnDirBeg]={1, true},	[EBvnDirEnd]={3, false} },
			[EBvnFemale]	= { [EBvnDirBeg]={2, true},	[EBvnDirEnd]={2, false} },	
			[EBvnBackSide]	= { [EBvnDirBeg]={3, true},	[EBvnDirEnd]={1, false} }
		  },

	-- log front
	[2] = {
			[EBvnMale]		= { [EBvnDirBeg]={3, true},	[EBvnDirEnd]={1, false} },
			[EBvnFrontSide]	= { [EBvnDirBeg]={4, true},	[EBvnDirEnd]={4, false} },
			[EBvnFemale]	= { [EBvnDirBeg]={1, true},	[EBvnDirEnd]={3, false} },
			[EBvnBackSide]	= { [EBvnDirBeg]={2, true},	[EBvnDirEnd]={2, false} }
		  },

	-- log bottom
	[3] = { 
			[EBvnMale]		= { [EBvnDirBeg]={2, false},	[EBvnDirEnd]={2, true } },
			[EBvnFrontSide]	= { [EBvnDirBeg]={3, false},	[EBvnDirEnd]={1, true} },
			[EBvnFemale]	= { [EBvnDirBeg]={4, false},	[EBvnDirEnd]={4, true} },
			[EBvnBackSide]	= { [EBvnDirBeg]={1, false},	[EBvnDirEnd]={3, true} }
		  },

	-- log back
	[4] = {
			[EBvnMale]		= { [EBvnDirBeg]={1, false},	[EBvnDirEnd]={3, true } },
			[EBvnFrontSide]	= { [EBvnDirBeg]={2, false},	[EBvnDirEnd]={2, true} },
			[EBvnFemale]	= { [EBvnDirBeg]={3, false},	[EBvnDirEnd]={1, true} },
			[EBvnBackSide]	= { [EBvnDirBeg]={4, false},	[EBvnDirEnd]={4, true} }
		  }
}


-- Returns two values:
-- first: bvn side is: 1=top, 2=not against plate, 3=bottom against the table, 4=against the plate
-- second: true=need to mirror coordinates in y-direction, false=nope. x-direction must be swapped if gnBvnLogDir==EBvnDirEnd
function BvnGetSide(logFace)
	return gBvnSides[logFace][gnBvnPlateSide][gnBvnLogDir][1], gBvnSides[logFace][gnBvnPlateSide][gnBvnLogDir][2]
end


-- Adds cnc position and content to table. Table will be sorted at the end.
function BvnAddLine(nPos, sText, bSkipLenCheck)
	local	i

	if nPos==nil then error("BvnAddLine/nPos") end
	if sText==nil then error("BvnAddLine/sText") end
	if not bSkipLenCheck then
		i=string.len(sText)
		if i~=126 then
			toLog( string.format("TOO LONG: [%s]", sText) );
			error( string.format("BVN saving: Line lenght must be 126, now it is %d (%s)", i, sText) )
		end
	end

	if gnCncCount==0 then
		gTblCnc={}
	end

	gnCncCount=gnCncCount+1
	gTblCnc[gnCncCount] = {}
	gTblCnc[gnCncCount].pos	=nPos
	gTblCnc[gnCncCount].count	=gnCncCount
	gTblCnc[gnCncCount].text	=sText
end



function BvnAddBeveledDrilling(sPieceNum, side, params)
	BvnAddOperation(
		sPieceNum, 
		402, 
		side, 
		{
			p1=params.length,
			p2=params.xMeas1,
			p3=params.xMeas2,
			p4=params.drillDiameter,
			p5=params.depth,
			p6=params.angle,
			p7=params.bevel,
			p8=params.counterSinkDepth,
			p9=params.counterSinkDiameter,
			p10=params.counterSinkSide,
			p11_splinterFree=gsSplinterFree
		})
end



function BvnLength(value)
	return value*10000.0
end


function BvnAngle(value)
	return value*10.0
end

-- Hide away string formating of operations, use this in the future.
-- BVN-Spec: https://warsztat.doleczek.pl/example.pdf
function BvnAddOperation(partNumber, id, side, params)
	BvnAddLine(0, string.format(
			"%s %04d %02d %8.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %d%d%d                           ", 
			partNumber, 
			id, 
			side, 
			ZeroIfNil(params.p1), 
			ZeroIfNil(params.p2),
			ZeroIfNil(params.p3),
			ZeroIfNil(params.p4),
			ZeroIfNil(params.p5),
			ZeroIfNil(params.p6),
			ZeroIfNil(params.p7),
			ZeroIfNil(params.p8),
			ZeroIfNil(params.p9),
			ZeroIfNil(params.p10),
			ZeroIfNil(params.p11_splinterFree),
			ZeroIfNil(params.p11_various),
			ZeroIfNil(params.p11_emReserved)
		)
	)
end


function ZeroIfNil(value)
	return TernaryIf(value==nil, 0, value)
end

-- THIS IS FOR BACKWARDS COMPATIBILITY & FOR LOG OBJECT FROM 3/2012
-- Side is tilted to front/back face, Top is to top/bottom
-- Angles: 90deg=straight. All rules from log object
-- xc: in plank's coordinates (total length or 0)
-- nBegEnd: +-3
function BvnAddBegEndAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop, xc, nBegEnd )
	local xSide, xTop, temp
	local bMirrorY


	if nAngleTop==nil then
		nAngleTop=PI/2
	end
	if nStraightTop==nil then
		nStraightTop=0
	end

	if gnBvnLogDir==EBvnDirEnd then
		nBegEnd=-nBegEnd
	else
		nAngleTop=-nAngleTop
	end

	bMirrorY=BvnGetBegEndMirrorY()

	xc=BvnGetXc(xc)
	xTop=0
	
	if gnBvnYoffset~=0 then
		-- Upper half is own material - need to adjust xSide to half log coordinates
		if nAngleSide>0 then
			-- Straight at bottom side
			nStraightSide=nStraightSide-gnBvnYoffset
		end	
	end

	if bMirrorY then
		nAngleSide=-nAngleSide
	end


	--if bMirrorY then
		--if nAngleSide<0 then
			--xSide=nStraightSide
			--nAngleSide=-nAngleSide
		--else
			--xSide=gnProfHeight-nStraightSide
			--nAngleSide=PI-nAngleSide
		--end
	--else
	
	xSide=nStraightSide
	if math.abs(nAngleSide)<EPS then
		nAngleSide=0
	end
	if nAngleSide<0 then
		xSide=gnProfHeight-xSide
		nAngleSide=PI+nAngleSide
	end
	
	xTop=nStraightTop
	if math.abs(nAngleTop)<EPS then
		nAngleTop=0
	end
	if nAngleTop<0 then
		xTop=gnCurrWidth-xTop
		nAngleTop=PI+nAngleTop
	end
	--end
	
	if gnBvnPlateSide==EBvnFrontSide or gnBvnPlateSide==EBvnBackSide then
		-- Table 90 deg, tilt the saw (bevel)
		temp=nAngleTop
		nAngleTop=nAngleSide
		nAngleSide=temp

		temp=xTop
		xTop=xSide
		xSide=temp
	end

	BvnAddLine( 0, string.format( "%s 0100 %02d %8.0f %7.0f %7.0f %7.0f %7.0f       0       0       0       0       0 000                           ",
							sPieceNum, nBegEnd, 10000*xc, 10000*xSide, 10000*xTop, 10*180*nAngleSide/PI, 10*180*nAngleTop/PI) )
end


-- Adds angled ending to beginning
function BvnAddBegAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop )
	BvnAddBegEndAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop, 0, 3 )
end


function BvnAddEndAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop )
	BvnAddBegEndAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop, gnCurrTotLen, -3 )
end


-- Table 
gBvnCutAdjustAngleTbl={
	[EBvnMale]		= { [EBvnDirBeg]=false,	[EBvnDirEnd]=true },
	[EBvnFrontSide]	= { [EBvnDirBeg]=false,	[EBvnDirEnd]=false },
	[EBvnFemale]	= { [EBvnDirBeg]=true,	[EBvnDirEnd]=false },
	[EBvnBackSide]	= { [EBvnDirBeg]=true,	[EBvnDirEnd]=true }
}

-- NEW ANGLED ENDING STARTING FROM 3/2012 FOR iMc
-- Angles: As for 101 in plank object
-- xoff,yff,zoff: Offset from the plank end refline, y-offset must have been set to zoff
-- xc: in plank's coordinates (total length or 0)
function BvnAddBegEndAngled( sPieceNum, nAngle, nBevel, xoff, yoff, zoff, isBeg )
	local xc, nBegEnd
	local temp
	local bMirrorY,bMirrorTopY

	if isBeg then
		xc=xoff
		nBegEnd=BvnGetLogBegBvnSide(3)
	else
		xc=gnCurrTotLen-xoff
		nBegEnd=BvnGetLogEndBvnSide(3)
	end

	xc=BvnGetXc(xc)
	yoff=yoff+gnCurrWidth*0.5

	if gnBvnLogDir==EBvnDirEnd then
		nAngle=PI-nAngle
		yoff=gnCurrWidth-yoff
	end

	BvnAddLine( 0, string.format( "%s 0100 %02d %8.0f %7.0f %7.0f %7.0f %7.0f       0       0       0       0       0 000                           ",
							sPieceNum, nBegEnd, 10000*xc, 10000*yoff, 10000*zoff, 10*180*nAngle/PI, 10*180*nBevel/PI) )
end



-- use1603	nil or false=use 1601
function BvnAddBegEndL( sPieceNum, bToBeg, dLen, dAngleDeg, cutBot, cutTop, use1603 )
	-- "000005 1601 04     3000       0       0      10    1905    1270     318     127       0       0 000                           "
	
	local side, toLeft, nSide, nPos, nBvnDir, depth1, depth2, depth3
	

	if use1603==nil then
		use1603=false
	end

	-- Kulma: Hirren keskeltä päähän katsottaessa: neg=oikealle, pos=vasemmalle
	if math.abs(dAngleDeg-PI2) < PI2/90.0+EPS then
		toLeft=true
	elseif math.abs(dAngleDeg+PI2) < PI2/90.0+EPS then
		toLeft=false
	else
		AddCncErr( 0, "BVN: ONLY 90 DEG L-ENDINGS SUPPORTED" )
		return
	end

	-- Set for end ending
	nSide=1
	nBvnDir=0
	if toLeft then
		--nSide=4
		nBvnDir=10
	end
	
	if bToBeg then
		nPos=BvnGetXc(0)+dLen
		nSide = BvnGetLogBegBvnSide(nSide)
	else
		nPos=BvnGetXc(gnCurrTotLen-dLen)
		nSide = BvnGetLogEndBvnSide(nSide)
	end

	-- From the example: widht&height of the log=190,5, depth1=127,0 depth2=31,8, depth3=12,7
	-- Clear seeming relation: depth1=2/3*log height
	-- It seems that there is relation: depth2/(depth1+depth2)=20% <--> depth2=depth1/4
	-- depth3 can probably be changed as wished, but let's keep it 10% of depth1

	depth1=gnFullHeight*2.0/3.0				-- Always calculate values from full profile and
	depth2=depth1/4.0
	depth3=0								-- depth1/10.0: Nope, let the log object's shorten (negative=extend) parameter define overhang

	if gnHalfing==EHalfingLower and gnBvnLowerHalf~=0 then
		depth1=depth1-gnCurrHeight				-- Offset the machining half log above the current piece
	end

	if use1603 then
--000009 1603 04     1340     900     900     900    1340       0      10       0       0       0 000           8               
--                   len     width   height   angle  counterdim protru.0=l,10=r 

		nBvnDir=10-nBvnDir
		BvnAddLine( nPos,  string.format( "%s 1603 %02d %8.0f     900     900     900 %7.0f       0      %2d       0       0       0 000           8               ",
											sPieceNum, nSide, 10000*BvnGetXc(nPos), 10000*BvnGetXc(dLen), nBvnDir ) )

	else
	BvnAddLine( nPos,  string.format( "%s 1601 %02d %8.0f       0       0      %2d %7.0f %7.0f %7.0f %7.0f       0       0 000                           ",
										sPieceNum, nSide, 10000*BvnGetXc(nPos), nBvnDir, 10000*BvnGetXc(dLen), 10000*depth1, 10000*depth2, 10000*depth3) )
	end
										

	-- Cut bot/top
	if bToBeg then
		nPos=BvnGetXc(dLen)
	else
		nPos=BvnGetXc(gnCurrTotLen)
	end

	if cutTop then
		-- Cut away top side of the joint
		depth1 = gnCurrHeight * 0.5
		depth1 = gnProfHeight-(depth1-gnBvnYoffset)
		BvnAddGro(sPieceNum, nPos, 0, nPos, gnCurrWidth, depth1, dLen, 0, 1, 0)
	end

	if cutBot then
		-- Cut away bottom side of the joint
		depth1 = gnCurrHeight * 0.5
		depth1 = depth1-gnBvnYoffset

		BvnAddGro(sPieceNum, nPos, 0, nPos, gnCurrWidth, depth1, dLen, 0, 3, 0)
	end
end


-- Rotates refline to next side
function BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
	local	tblGro

	tblGro={}
	tblGro.guid	= gsCurrentLogGuid
	tblGro.x1	= x1
	tblGro.y1	= y1
	tblGro.x2	= x2
	tblGro.y2	= y2
	tblGro.depth	= groDepth
	tblGro.width	= groWidth
	tblGro.groAngleRad	= groAngle
	tblGro.face			= groFace
	tblGro.groTiltAngleRad	= groAngleLen

	af_request("mc_rotgro", tblGro)
	return tblGro.x1, tblGro.y1, tblGro.x2, tblGro.y2, tblGro.depth, tblGro.width, tblGro.groAngleRad, tblGro.groTiltAngleRad
end


function BvnAddGroAsBird(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
	local	tblGro, i

	if BvnAddGroAsBirdInt(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen) then
		return true
	end

	-- Try with bottom changed to ref line
	local tblGroInfo, tblGro


	tblGro={}
	tblGro.guid	= gsCurrentLogGuid
	tblGro.x1	= x1
	tblGro.y1	= y1
	tblGro.x2	= x2
	tblGro.y2	= y2
	tblGro.depth	= groDepth
	tblGro.width	= groWidth
	tblGro.groAngleRad	= groAngle
	tblGro.face			= groFace
	tblGro.groTiltAngleRad	= groAngleLen
	tblGroInfo = af_request("mc_getgroinfo", tblGro)

	if tblGroInfo.birdAltGro==nil then
		return
	end

--AddCncErr( 0, "@@@ALT GRO" )
	if BvnAddGroAsBirdInt(sPieceNum, tblGroInfo.birdAltGro.x1, tblGroInfo.birdAltGro.y1, tblGroInfo.birdAltGro.x2, tblGroInfo.birdAltGro.y2, tblGroInfo.birdAltGro.depth, tblGroInfo.birdAltGro.width, tblGroInfo.birdAltGro.groAngleRad, tblGroInfo.birdAltGro.face, tblGroInfo.birdAltGro.groTiltAngleRad) then
		return true
	end

	if false then
		tblGro={}
		tblGro.guid	= gsCurrentLogGuid
		tblGro.x1	= x1
		tblGro.y1	= y1
		tblGro.x2	= x2
		tblGro.y2	= y2
		tblGro.depth	= groDepth
		tblGro.width	= groWidth
		tblGro.groAngleRad	= groAngle
		tblGro.face			= groFace
		tblGro.groTiltAngleRad	= groAngleLen

		-- Try all three ways
		for i=1,3 do
			af_request("mc_rotgro", tblGro)
			if BvnAddGroAsBirdInt(sPieceNum, tblGro.x1, tblGro.y1, tblGro.x2, tblGro.y2, tblGro.depth, tblGro.width, tblGro.groAngleRad, groFace, tblGro.groTiltAngleRad) then
				return true
			end
		end
	end

	return false
end


-- Adds groove as birds mouth if possible
-- Returns: true=saved, false=not saved
function BvnAddGroAsBirdInt(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
	local d, dxDir, dyDir, dzDir, dxDown, dyDown, dzDown, dxBot, dyBot, dzBot, yBot2
	local x,y,z, nAngle7, nAngle8, nBegEnd, groLen, dx, dy, dz
	local nBvnSide,bMirrorY


	-- Must be tilted in both ways to use this machining
	if math.abs(groAngle)<PI/180 or math.abs(groAngleLen)<PI/180 then 
		return false
	end

	-- Cannot be straight
	if math.abs(x2-x1)<0.001 then 
		return false
	end

	-- Not to beg/end
	if groFace>4 then
		return false
	end
	
	-- Looks like birdsmouth - check if really is
	--AddCncErr( x1, string.format("@@@ x1=%f, y1=%f, x2=%f, y2=%f, groDepth=%f, groWidth=%f, groAngle=%f, groAngleLen=%f", x1, y1, x2, y2, groDepth, groWidth, groAngle*180/PI, groAngleLen*180/PI) )

	local tblGroInfo, tblGro


	tblGro={}
	tblGro.guid	= gsCurrentLogGuid
	tblGro.x1	= x1
	tblGro.y1	= y1
	tblGro.x2	= x2
	tblGro.y2	= y2
	tblGro.depth	= groDepth
	tblGro.width	= groWidth
	tblGro.groAngleRad	= groAngle
	tblGro.face			= groFace
	tblGro.groTiltAngleRad	= groAngleLen

	if y1>y2 then
		--AddCncErr( x1, "y1>y2" )

		-- To have positive angle
		af_request("mc_swapgroref", tblGro)
		x1	= tblGro.x1
		y1	= tblGro.y1
		x2	= tblGro.x2
		y2	= tblGro.y2
		groDepth	= tblGro.depth
		groAngle	= tblGro.groAngleRad
		groAngleLen	= tblGro.groTiltAngleRad
	end

	tblGroInfo = af_request("mc_getgroinfo", tblGro)
	
	if tblGroInfo==nil or tblGroInfo.isBird==false then
		return false
	end

	-- On surface, z neg=inside the plank
	dxDir=(x2-x1)
	dyDir=(y2-y1)
	dzDir=0
	dxDir,dyDir,dzDir,d=ToUnitVec3(dxDir,dyDir,0)
	if d==false then
		return false
	end

	-- To left from surface
	dxBot,dyBot,dzBot=RotateSingle3D(-dyDir, dxDir, 0, dxDir, dyDir, 0, groAngle)
	dxDir,dyDir,dzDir=RotateSingle3D(dxDir, dyDir, 0, dxBot,dyBot,dzBot, groAngleLen)
	dxDown,dyDown,dzDown=CalcCross3D(dxBot, dyBot, dzBot, dxDir, dyDir, dzDir)

	--AddCncErr(0, string.format("dxDir=%f, dyDir=%f, dzDir=%f, dxDown=%f, dyDown=%f, dzDown=%f, dxBot=%f, dyBot=%f, dzBot=%f", dxDir, dyDir, dzDir, dxDown, dyDown, dzDown, dxBot, dyBot, dzBot))
	--AddCncErr(0, string.format("tblGroInfo.isBird=%s tblGroInfo.isBirdBeg90=%s tblGroInfo.isBirdEnd90=%s tblGroInfo.birdBegCutFace=%d tblGroInfo.birdEndCutFace=%d", tostring(tblGroInfo.isBird), tostring(tblGroInfo.isBirdBeg90), tostring(tblGroInfo.isBirdEnd90), tblGroInfo.birdBegCutFace, tblGroInfo.birdEndCutFace))

	-- Calculate groove bottom (y1<y2)
	local	angleBeg, angleEnd, angleGro
	local   xBot1, yBot1, zBot1, xBot2, yBot2, zBot2
	local	nLeft, begZ, endZ

	xBot1=x1+dxDown*groDepth
	yBot1=y1+dyDown*groDepth
	zBot1=0-dzDown*groDepth

	xBot2=xBot1+dxBot*groWidth
	yBot2=yBot1+dyBot*groWidth
	zBot2=zBot1-dzBot*groWidth

	--AddCncErr(0, string.format("xBot1=%f yBot1=%f zBot1=%f xBot2=%f yBot2=%f zBot2=%f", xBot1, yBot1, zBot1, xBot2, yBot2, zBot2))

	-- Calc side projection angles (valid angle for birdmouth 1...89 deg)
	if tblGroInfo.birdBegCutFace==2 then
		angleBeg=math.atan2(dzBot, -dxBot)			-- Positive if cutting the wood (should be always)
		x=xBot1
		y=yBot1
		z=zBot1
	else
		angleBeg=math.atan2(-dzDown, dxDown)
		x=xBot2
		y=yBot2
		z=zBot2
	end

	if tblGroInfo.birdEndCutFace==2 then
		angleEnd=math.atan2(-dzBot, -dxBot)			-- Positive if cutting the wood (should be always)
	else
		angleEnd=math.atan2(-dzDown, -dxDown)
	end

	if angleBeg<PI/180 or angleBeg>PI*89/180 or angleEnd<PI/180 or angleEnd>PI*89/180 then
		--AddCncErr(x1, string.format("CANNOT SAVE AS BIRDSMOUTH angleBeg=%f angleEnd=%f", angleBeg*180/PI, angleEnd*180/PI))
		return false
	end

	-- Anchor to y0 (may be swapped later)
	if math.abs(dyDir)>0.001 then		-- Should be always
		x=x-y/dyDir*dxDir
		z=z+y/dyDir*dzDir
		y=0
	end

	-- Gro angle (=angle in k2.exe) relative to bottom plane
	dx=-dxBot
	dz=-dzBot
	d=math.sqrt(dx*dx+dz*dz)
	if d<0.0001 then
		AddCncErr(x1, string.format("INTERNAL ERROR IN BIRDSMOUTH: d<0.0001, SAVED AS NORMAL GROOVE"))
		return false
	end
	dx=dx/d
	dz=dz/d
	angleGro=math.acos(dx*dxDir + dz*dzDir)

	--AddCncErr(0, string.format("x=%f y=%f z=%f angleGro=%f angleBeg=%f angleEnd=%f", x, y, z, angleGro/PI*180, angleBeg/PI*180, angleEnd/PI*180))

	nLeft=0
	if groAngleLen<0 then
		nLeft=1-nLeft
	end
	
	nBvnSide,bMirrorY=BvnGetSide(groFace)
	if gnBvnLogDir==EBvnDirBeg then
		nBvnSide=-nBvnSide
		nLeft=1-nLeft
	end
	
	-- Is end not 90 deg?
	if tblGroInfo.isBirdEnd90==false then
		if tblGroInfo.isBirdBeg90==false then
			-- Cannot use birdsmouth to save this
			return false
		end
		
		nBvnSide=-nBvnSide
		angleBeg,angleEnd=angleEnd,angleBeg
		nLeft=1-nLeft
	end

	if angleGro>PI2 then	
		angleGro=PI2-(angleGro-PI2)
	end
	if angleGro<PI/180 or angleGro>PI*89/180  then
		--AddCncErr(x1, string.format("CANNOT SAVE AS BIRDSMOUTH angleGro=%f", angleGro*180/PI))
		return false
	end
	
	if z<0.0011 then
		-- Change anchor side to face width
		local dy
		
		dy=gnProfHeight
		if logFace==1 or logFace==3 then
			dy=gnCurrWidth
		end

		y=dy-y
		x=x+y/dyDir*dxDir
		z=z-y/dyDir*dzDir
		y=dy
	end

	x=BvnGetXc(x)
	if bMirrorY then
		y=BvnMirrorYc(y, groFace)
		nLeft=1-nLeft
	end

	--0202 -3    35381    1130             158     450     549       0      10       0         000                           
	BvnAddLine( x, string.format( "%s 0202 %02d %8.0f %7.0f         %7.0f %7.0f %7.0f       0      %2d       0         000                           ",
								  sPieceNum, nBvnSide, 10000*x, 10000*y, angleEnd/PI*1800, angleGro/PI*1800, z*10000, nLeft*10 ) )

	-- 3D pocket tested 12/2012: Cannot do any other angle but 90 deg - no use
	return true
end




-- Adds groove as vcut at beg/end if possible
-- Returns: true=saved, false=not saved
function BvnAddGroAsVCut(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
	local d, dxDir, dyDir, dzDir, dxDown, dyDown, dzDown, dxBot, dyBot, dzBot, yBot2
	local x,y,z, nAngle7, nAngle8, nBegEnd, groLen, dx, dy, dz
	local nBvnSide,bMirrorY
	local vSideOrg, bSwapLR
	local tblGroInfo, tblGro

	
	tblGro={}
	tblGro.guid	= gsCurrentLogGuid
	tblGro.x1	= x1
	tblGro.y1	= y1
	tblGro.x2	= x2
	tblGro.y2	= y2
	tblGro.depth	= groDepth
	tblGro.width	= groWidth
	tblGro.groAngleRad	= groAngle
	tblGro.face			= groFace
	tblGro.groTiltAngleRad	= groAngleLen

	bSwapLR=false
	if groFace>4 then
		if math.abs(x2-x1)>math.abs(y1-y2) then
			if x1>x2 then
				bSwapLR=true
			end
		elseif y1>y2 then
			bSwapLR=true
		end
	elseif y1>y2 then
		bSwapLR=true
	end
	if bSwapLR then
		--AddCncErr( x1, "y1>y2" )
		af_request("mc_swapgroref", tblGro)
		x1	= tblGro.x1
		y1	= tblGro.y1
		x2	= tblGro.x2
		y2	= tblGro.y2
		groDepth	= tblGro.depth
		groAngle	= tblGro.groAngleRad
		groAngleLen	= tblGro.groTiltAngleRad
	end

	tblGroInfo = af_request("mc_getgroinfo", tblGro)

	if tblGroInfo==nil then
		return false
	end

	if tblGroInfo.vHun~=1 then
		return false
	end

	-- To ends try always, for other sides use only if double angle
	if groFace<5 and (math.abs(groAngle)<PI/180 or math.abs(groAngleLen)<PI/180) then
		return false
	end

	--tblGroInfo.vBevelL = PI - tblGroInfo.vBevelL		-- Move to top side
	if tblGroInfo.vBeg~=0 then
		vSideOrg=tblGroInfo.vBeg
		nBvnSide=BvnGetLogBegBvnSide(tblGroInfo.vBeg)
	elseif tblGroInfo.vEnd~=0 then
		vSideOrg=tblGroInfo.vEnd
		nBvnSide=BvnGetLogEndBvnSide(tblGroInfo.vEnd)
	else
		return false
	end

	dummy,bMirrorY=BvnGetSide(vSideOrg)

	bSwapLR=true
	if vSideOrg==4 or vSideOrg==3 then
		-- Need to swap upper&lower
		bSwapLR=false
	end
	
	x=BvnGetXc(tblGroInfo.vFaceX)
	y=tblGroInfo.vFaceY
	if bMirrorY then
		y=BvnMirrorYc(y, vSideOrg)
		bSwapLR=not bSwapLR
	end

	-- Hundegger uses the target face as origin when valley height is equal to thickness
	dx=gnCurrWidth
	if vSideOrg==1 or vSideOrg==3 then
		dx=gnProfHeight
	end
	
	--AddCncErr(x1, string.format("vSideOrg=%f vAngleL=%f vAngleR=%f vBevelL=%f vBevelR=%f", vSideOrg, tblGroInfo.vAngleL/PI*180, tblGroInfo.vAngleR/PI*180, tblGroInfo.vBevelL/PI*180, tblGroInfo.vBevelR/PI*180))

	-- Trial & error:
	tblGroInfo.vAngleL=PI-tblGroInfo.vAngleL
	tblGroInfo.vAngleR=PI-tblGroInfo.vAngleR
	
	if vSideOrg==1 then

	elseif vSideOrg==2 then
	
	elseif vSideOrg==3 then
		bSwapLR=not bSwapLR
		tblGroInfo.vBevelL=PI-tblGroInfo.vBevelL
		tblGroInfo.vBevelR=PI-tblGroInfo.vBevelR
	elseif vSideOrg==4 then
		bSwapLR=not bSwapLR
		tblGroInfo.vBevelL=PI-tblGroInfo.vBevelL
		tblGroInfo.vBevelR=PI-tblGroInfo.vBevelR
	else
		AddCncErr(x1, string.format("WARNING: BvnAddGroAsVCut, unsupported vSideOrg=%f SAVED AS NORMAL GROVE", vSideOrg))
		return false
	end
	
	if bSwapLR then
		tblGroInfo.vAngleR, tblGroInfo.vBevelR, tblGroInfo.vAngleL, tblGroInfo.vBevelL = tblGroInfo.vAngleL, tblGroInfo.vBevelL, tblGroInfo.vAngleR, tblGroInfo.vBevelR
	end

	-- 000101 0103 01     3000     565       0     100    1350     300    1000     600       0       0 000                           
	--										(Valley height)
	BvnAddLine( x, string.format( "%s 0103 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7.0f       0       0 000                           ",
								  sPieceNum, nBvnSide, 10000*x, 10000*y, 10000*dx, tblGroInfo.vAngleR/PI*1800, tblGroInfo.vBevelR/PI*1800, tblGroInfo.vAngleL/PI*1800, tblGroInfo.vBevelL/PI*1800 ) )

	return true
end


-- Saves using codes 1500 or 1501 (groType 4-7)
function BvnSaveGroAs15(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen, groType)
	local is1500, inside, nBvnSide, bMirrorY

	if math.abs(groAngle)>PI180 or math.abs(groAngleLen)>PI180 then
		AddCncErr(x1, string.format("WARNING: Groove 150x, skipping angle(s) - writing with zero angle(s)"))
	end

	if groFace>4 then
		AddCncErr(x1, string.format("WARNING: Groove 150x can be only on surfaces 1-4 (set to %d), writing as normal groove", groFace))
		return false
	end


	is1500=true
	inside=0
	if groType==5 or groType==7 then
		is1500=false
	end
	if groType==6 or groType==7 then
		inside=10
	end

	-- Calculate coordinates so that x-coordinates are changing and y remains the same (in plank's direction)
	if math.abs(y1-y2)>0.0005 then
		-- Swap direction
		if math.abs(x2-x1)>0.0005 then
			AddCncErr(x1, string.format("WARNING: Groove 150x can only be in plank's direction (x1=%f y1=%f x2=%f y2=%f), writing as normal groove", x1, y1, x2, y2))
			return false
		end

		if y1>y2 then
			-- Oops, y1 smaller
			x2=x1+groWidth
			groWidth=y1-y2
			y1=y2
		else
			x1=x2-groWidth
			groWidth=y2-y1
			y2=y1
		end
	end

	-- x to bvn
	x1=BvnGetXc(x1)
	x2=BvnGetXc(x2)
	if x1>x2 then
		x1,x2=x2,x1
	end
	nBvnSide,bMirrorY=BvnGetSide(groFace)

	-- x1<x2 and y1==y2
	if is1500 then
		-- Move line to middle of the groove
		y1=y1+groWidth*0.5
		y2=y1

		if bMirrorY then
			y1=BvnMirrorYc(y1, groFace)
		end

		BvnAddLine( x1, string.format( "%s 1500 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f      %2d       0       0       0 000                           ",
									   sPieceNum, nBvnSide, 10000*x1, 10000*y1, 10000*(x2-x1), 10000*groDepth, 10000*groWidth, inside) )
	else
		-- This must be at the side of the piece
		local faceHeight, edge

		faceHeight=gnProfHeight
		if groFace==1 or groFace==3 then
			faceHeight=gnCurrWidth
		end

		edge=0
		if y1>0.001 then
			if y1+groWidth+0.001<faceHeight then
				AddCncErr(x1, string.format("WARNING: Groove 1501 can only be at the edge of the plank (x1=%f y1=%f x2=%f y2=%f), writing as normal groove", x1, y1, x2, y2))
				return false
			end
			edge=10
		end

--000003 1501 -1    13506      10       0   10867     200     100       0       0       0       0 000                           
		if bMirrorY then
			edge=10-edge
		end
		BvnAddLine( x1, string.format( "%s 1501 %02d %8.0f %7d       0 %7.0f %7.0f %7.0f %7d       0       0       0 000                           ",
									   sPieceNum, nBvnSide, 10000*x1, edge, 10000*(x2-x1), 10000*groDepth, 10000*groWidth, inside) )
	end

	return true
end


function CheckGroWarn(x1,y1,x2,y2,groWidth,dx,dy)
--ac_environment("tolog", string.format("x1=%f, y1=%f, x2=%f, y2=%f, groWidth=%f, dx=%f, dy=%f", x1,y1,x2,y2,groWidth,dx,dy) )

	if gdBvnWarnGroWidth<EPS or groWidth+EPS>gdBvnWarnGroWidth then
		return
	end

	if math.abs(x2-x1)<0.001 then
		if x1+0.001>dx or x1-groWidth-0.001<0 then
			return
		end
	end

	if math.abs(y2-y1)<0.001 then
		if y1+0.001>dy or y1-groWidth-0.001<0 then
			return
		end
	end

	AddCncErr(x1, string.format("WARNING: Groove width is %s - please check", ac_environment ("ntos", groWidth, "length", "work")))
end


-- Returns: true=is at end, false=nope
function GroAtEnd(x1,x2,y1,y2,groWidth)
	if math.abs(x2-x1)<EPS then
		if y1<y2 then
			x1=x2-groWidth
		else
			x2=x1+groWidth
		end
	elseif x1>x2 then
		x1,x2=x2,x1
	end

	local res

	if x1<0.001 or x2>gnCurrTotLen-0.001 then
		res=true
	end

	return res
end


function BvnDirToAngles(dirUpX, dirUpY, dirUpZ)
	local angle=math.atan2(dirUpX, dirUpZ)
	local bevel=-math.asin(dirUpY)
	return angle, bevel
end


function BvnAddGroAsDrilling(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)

	if groFace==5 or groFace==6 then
		local dx=x2-x1
		local dy=y2-y1
		local length=math.sqrt(dx*dx+dy*dy)
		local ux=dx/length
		local uy=dy/length
		local x=x1+ux*length/2-uy*groWidth/2
		local y=y1+uy*length/2+ux*groWidth/2
		local diameter=TernaryIf(length<groWidth, length, groWidth)
		return BvnAddDrill(sPieceNum, x, y, diameter, groDepth, groFace)
	end

	local tblGro={}
	tblGro.guid	= gsCurrentLogGuid
	tblGro.x1	= x1
	tblGro.y1	= y1
	tblGro.x2	= x2
	tblGro.y2	= y2
	tblGro.depth	= groDepth
	tblGro.width	= groWidth
	tblGro.groAngleRad	= groAngle
	tblGro.face			= groFace
	tblGro.groTiltAngleRad	= groAngleLen
	tblGroInfo = af_request("mc_getgroinfo", tblGro)

	local lenBot=tblGroInfo.lenBot
	local midPtBotX=x1+tblGroInfo.vecDownSurf.x*groDepth + tblGroInfo.vecLeftSurf.x*groWidth/2 + tblGroInfo.vecLenSurf.x*lenBot/2
	local midPtBotY=y1+tblGroInfo.vecDownSurf.y*groDepth + tblGroInfo.vecLeftSurf.y*groWidth/2 + tblGroInfo.vecLenSurf.y*lenBot/2
	local midPtBotZ=   tblGroInfo.vecDownSurf.z*groDepth + tblGroInfo.vecLeftSurf.z*groWidth/2 + tblGroInfo.vecLenSurf.z*lenBot/2

	local hasX, x, y, _z, distToPlane=LinePlaneX(
		0, 0, 1, 0,
		midPtBotX, midPtBotY, midPtBotZ,
		midPtBotX-tblGroInfo.vecDownSurf.x,
		midPtBotY-tblGroInfo.vecDownSurf.y,
		midPtBotZ-tblGroInfo.vecDownSurf.z
	)

	if not hasX then
		AddCncErr(x1, string.format("ERROR: Drilling does intersect plane"))
		return
	end

	local side, mirrorY=BvnGetSide(groFace)
	local vecUpX=-tblGroInfo.vecDownSurf.x
	local vecUpY=-tblGroInfo.vecDownSurf.y
	local vecUpZ=-tblGroInfo.vecDownSurf.z
	if mirrorY then
		y=BvnMirrorYc(y, groFace)
		vecUpY=-vecUpY
	end

	if gnBvnLogDir==EBvnDirEnd then
		vecUpX=-vecUpX
	end

	local angle, bevel=BvnDirToAngles(
		vecUpX,
		vecUpY,
		vecUpZ
	)

	local groDiameter=TernaryIf(lenBot<groWidth, lenBot, groWidth)

	BvnAddBeveledDrilling(
		sPieceNum,
		side, {
			length=BvnLength(BvnGetXc(x)),
			xMeas1=BvnLength(y),
			drillDiameter=BvnLength(groDiameter),
			depth=BvnLength(distToPlane),
			angle=BvnAngle(angle*180/PI),
			bevel=BvnAngle(bevel*180/PI)
		}
	)
end


-- Adds one groove in Logs coordinates to bvn-file. Adds notice if not possible.
-- groFace: 1=top, 2=front, 3=bottom, 4=back, 5=beg, 6=end
-- groType: 0=Normal, 1=Round width/2=rounding radius, 2=Drip groove, 3=Saw groove/dado, 4=Hun 1500 in, 5=Hun 1501 in, 6=Hun 1500 out, 7=Hun 1501 out
-- Coordinates are always to whole log!
function BvnAddGro(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen, groType)
	local nBvnSide, bMirrorXEnd, bMirrorY, temp
	local ux, uy, unx, uny, cosSub, minY, maxY, orgY1, x, y, a, len, faceHeight, faceDepth
	local atEnd

	atEnd=GroAtEnd(x1,x2,y1,y2,groWidth)

	if groType==nil then
		groType=0			-- Parameter added 4/2020
	end

	faceHeight=gnProfHeight
	faceDepth=gnCurrWidth
	if groFace==1 or groFace==3 then
		faceHeight=gnCurrWidth
		faceDepth=gnProfHeight
	end

	if groType==8 then
		BvnAddGroAsDrilling(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
		return
	elseif groType<4 or groType>7 then
		if BvnAddGroAsBird(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen) then
			return
		end

		if BvnAddGroAsVCut(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen) then
			return
		end
	end
	if groType<4 or groType>7 then
		if BvnAddGroAsBird(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen) then
			return
		end

		if BvnAddGroAsVCut(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen) then
			return
		end
	end

	if x1<-1 or x1>gnCurrTotLen+1 or y1<-1 or y1>faceHeight+1 or x2<-1 or x2>gnCurrTotLen+1 or y2<-1 or y2>faceHeight+1 or groDepth>1 then
		AddCncErr( x1, string.format("WARNING: GROOVE WITH SUSPICIOUS BIG COORDINATES/DEPTH - WRITTEN INTO BVN FILE ANYWAY: x1=%.0f y1=%.0f x2=%.0f y2=%.0f depth=%.0f", x1*1000, y1*1000, x2*1000, y2*1000, groDepth*1000) )
	end

	if groType>=4 and groType<=7 then
		-- With codes 1500 or 1501
		if BvnSaveGroAs15(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen, groType) then
			return
		end
	end

	local nSplinter, nGroLen, dx, dy

	if gbHonkaDt==true then
		if groWidth<0.0599 then
			AddCncErr( x1, string.format("VAROITUS/VIRHE: HONKA NOLLANURKKA, URAN LEVEYS<60 MM (%.2f), TEHDÄÄN MAHDOLLISESTI NOLLANURKKATYÖKALULLA", groWidth*1000) )
		end
	end
	
	nSplinter=100
	if gbBvnNoSplinterFree then
		nSplinter=0
	end

	--toLog( string.format( "GRO1, x1=%.3f y1=%.3f x2=%.3f y2=%.3f groDepth==%.3f groWidth=%.3f groAngle=%.3f groFace=%.3f groAngleLen=%.3f", x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen ) )
	if math.abs(y2-y1)<EPS and groFace<=4 then
		-- This condition added 8/2021 because it makes lengthwise angled groove bad
		if math.abs(groAngle)<PI1800 then
			if math.abs(x2-x1)<EPS then
				return
			end

			-- Need to rotate groove since 0301 needs y2-y1 > EPS
			x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen = BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
		end
	end
	
	-- y1<y2 in plank coordinates
	if y1>y2+EPS then
		x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen = BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
		x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen = BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
	end

	orgY1=y1
	minY=y1
	maxY=y2

	-- Unit vector for the groove
	ux=x2-x1
	uy=y2-y1
	nGroLen=math.sqrt(ux*ux + uy*uy)
	if nGroLen<EPS then
		return
	end
	ux=ux/nGroLen
	uy=uy/nGroLen

	if math.abs(y1-y2)>0.001 and (groFace==2 or groFace==4) then
		-- Not a horizontal groove, check if to top of the log (=rise) and adjust to profile height if yes (1 mm threshold)
		if y1+0.001>gnCurrHeight and y1<gnProfHeight and y1>y2 then
			x1=x1-ux*(gnProfHeight-y1)
			y1=gnProfHeight
		end
		if y2+0.001>gnCurrHeight and y2<gnProfHeight and y2>y1 then
			x2=x2+ux*(gnProfHeight-y2)
			y2=gnProfHeight
		end
	end

	if gnBvnYoffset~=0 then
		-- Groove coordinates are always to whole log but we have half log raw material.
		if groFace==2 or groFace==4 or groFace==5 or groFace==6 then
			y1=y1-gnBvnYoffset
			y2=y2-gnBvnYoffset
		end

		if groFace==3 then
			-- Bottom face
			--5/2011, values to real profile: groDepth=groDepth-gnBvnYoffset
		end
	end

	if groFace>4 then
		-- Beg/end
		local anchorSide, isHor, anchorHeight, anchorWidth
		local tblGroInfo, tblGro, bMirrorXEnd2

		tblGro={}
		tblGro.guid	= gsCurrentLogGuid
		tblGro.x1	= x1
		tblGro.y1	= y1
		tblGro.x2	= x2
		tblGro.y2	= y2
		tblGro.depth	= groDepth
		tblGro.width	= groWidth
		tblGro.groAngleRad	= groAngle
		tblGro.face			= groFace
		tblGro.groTiltAngleRad	= groAngleLen
		tblGroInfo = af_request("mc_getgroinfo", tblGro)

		-- Alkupää tai loppupää
		-- beg/end anchored to log/plank bottom face
		-- Beg&End, adjust to midline
		cosSub=math.cos(groAngle)
		if cosSub<0.001 then
			cosSub=0.001		-- Impossible groove anyway
		end

		CheckGroWarn(x1,y1,x2,y2,groWidth,gnCurrWidth,gnProfHeight)

		unx=-uy*groWidth*0.5/cosSub
		uny=ux*groWidth*0.5/cosSub

		-- Move to the center line
		x1=x1+unx
		y1=y1+uny
		x2=x2+unx
		y2=y2+uny
		groDepth=groDepth-groWidth*0.5*math.tan(groAngle)

		if groFace==5 then
			ux=0
		else
			ux=gnCurrTotLen
		end

		anchorSide=3		-- In Frame sides
		anchorHeight=gnProfHeight
		anchorWidth=gnCurrWidth
		isHor=false
		if math.abs(x2-x1)>0.001 then
			-- Horizontal at begin/end, swap coordinates
			if math.abs(y2-y1)>0.001 then
				AddCncErr( 0, "BVN ERROR: GROOVE AT THE END OF A PIECE SKIPPED - ONLY VERTICAL AND HORIZONTAL GROOVES ARE SUPPORTED" )
				return
			end
			y1,x1,y2,x2=x1,gnProfHeight-y1,x2,gnProfHeight-y2
			--groAngleLen=-groAngleLen
			anchorSide=4
			anchorHeight=gnCurrWidth
			anchorWidth=gnProfHeight
			isHor=true
		end

		if groFace==5 then
			nBvnSide,bMirrorXEnd,bMirrorY=BvnGetLogBegBvnSide(anchorSide)
		else
			nBvnSide,bMirrorXEnd,bMirrorY=BvnGetLogEndBvnSide(anchorSide)
		end

		if math.abs(groAngleLen)>PI1800 then
			-- Lengthwise angled at the end - check if infinite
			if tblGroInfo.begIn and tblGroInfo.endIn then
				nGroLen=0
			end

			if math.abs(groAngle)>PI1800 then
				AddCncErr( x1, "BVN ERROR: ANGLED GROOVE NOT SUPPORTED BEG/END - GROOVE NOT ANGLED ***" )
			end

			-- Adjust params to mid point
			a = PI2 + groAngleLen 
			y=y1
			if isHor then
				temp=3
				if gnBvnLogDir==EBvnDirEnd then
					temp=1
				end
			else
				temp=2
				if gnBvnLogDir==EBvnDirEnd then
					temp=4
				end
			end
			if groFace==5 then
				nBvnSide,bMirrorXEnd2,bMirrorY=BvnGetLogBegBvnSide(temp)
			else
				nBvnSide,bMirrorXEnd2,bMirrorY=BvnGetLogEndBvnSide(temp)
			end

			if bMirrorY then
				a=PI-a
			else
				y=anchorHeight - y
			end

			x = (x1+x2)*0.5
			groDepth=groDepth+(x-x1)*math.sin(groAngleLen)
			if bMirrorXEnd then
				x=anchorWidth-x
			end
			if bMirrorY then
				y=anchorHeight-y
			end
			--y = (y1+y2)*0.5
			ux=BvnGetXc(ux)
			BvnAddLine( ux, string.format( "%s 0304 %02d %8.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f       0       0       0 %3.0f                           ", 
										sPieceNum, nBvnSide, 10000*ux, 10000*y, 10000*x, 10000*nGroLen, 10000*groWidth, 10000*groDepth, 1800*a/PI, nSplinter  ) )
		else
			-- OLD GROOVE EXPAND HERE
			if y1<0.001 then
				-- Expand >tool radius below
				y1=-0.030
			end

			if y2>gnCurrHeight-0.001 then
				-- Expand >tool radius above
				y2=anchorHeight+0.030
			end

			if (y1<0.001 and y2>gnCurrHeight-0.001) or (minY <0.001 and maxY>gnCurrHeight-0.001) then
				nGroLen=0		-- Through
			else
				nGroLen=y2-y1	-- Limited
			end

			x = (x1+x2)*0.5
			if bMirrorXEnd then
				x=anchorWidth-x
			end
			y = (y1+y2)*0.5
			if bMirrorY then
				y=anchorHeight-y
			end
			
			ux=BvnGetXc(ux)
			a=PI2+groAngle
--[[
Fixed and tested 8/2020
			if math.abs(groAngle)>PI1800 then
				AddCncErr( x1, "BVN WARNING: ANGLED GROOVE BEG/END NOT FULLY CHECKED - CHECK CAREFULLY ***" )
			end
]]
			BvnAddLine( ux, string.format( "%s 0304 %02d %8.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f       0       0       0 %3.0f                           ", 
										sPieceNum, nBvnSide, 10000*ux, 10000*x, 10000*y, 10000*groWidth, 10000*nGroLen, 10000*groDepth, 1800*a/PI, nSplinter  ) )
		end
		
		return
	end

	-- # Groove to side
	local tblGroInfo, tblGro

	nBvnSide,bMirrorY=BvnGetSide(groFace)

	tblGro={}
	tblGro.guid	= gsCurrentLogGuid
	tblGro.x1	= x1
	tblGro.y1	= y1
	tblGro.x2	= x2
	tblGro.y2	= y2
	tblGro.depth	= groDepth
	tblGro.width	= groWidth
	tblGro.groAngleRad	= groAngle
	tblGro.face			= groFace
	tblGro.groTiltAngleRad	= groAngleLen
	tblGroInfo = af_request("mc_getgroinfo", tblGro)

	-- Use general 0306? (could actually make all grooves with this)
	local use0306

	use0306=false
	if math.abs(groAngleLen)>PI1800 and (math.abs(groAngle)>PI1800 or math.abs(x2-x1)>0.001 or y2-y1<0.001) then
		use0306=true
	end

	if math.abs(groAngle)>PI1800 and math.abs(x2-x1)>0.0001 then
		use0306=true
	end

	if groFace==2 or groFace==4 then
		CheckGroWarn(x1,y1,x2,y2,groWidth,gnCurrTotLen,gnProfHeight)
	else
		CheckGroWarn(x1,y1,x2,y2,groWidth,gnCurrTotLen,gnCurrWidth)
	end

	if use0306 then
		-- Groove still in Frame coordinates
		local aLen, aSurf, tblGro90, lenNow, len90, info90

		-- Gives just length of y-component
		local fnGetLenOnSurf = function(groFace, y1, y2)
			if y1>y2 then
				y2, y1 = y1, y2
			end

			if y1<0 then
				y1=0
			end
			if y1>faceHeight then
				y1=faceHeight
			end

			if y2<0 then
				y2=0
			end
			if y2>faceHeight then
				y2=faceHeight
			end

			return y2-y1
		end

		-- 0306 always makes infinite cut - check if rotated 90 gives longer intersection with the target surface (just checking y-coords)
		-- Since it is infinite cut, the ends may not be inside the plank to use 0306
		local nowGood, rotGood

		tblGro90=deepcopy(tblGro)
		af_request("mc_rotgro", tblGro90)
		info90 = af_request("mc_getgroinfo", tblGro90)

		nowGood=(tblGroInfo.begIn==0 and tblGroInfo.endIn==0)
		rotGood=(info90.begIn==0 and info90.endIn==0)

--ac_environment("tolog", string.format("PRE: tblGroInfo.begIn=%d, tblGroInfo.endIn=%d, nowGood=%s, info90.begIn=%d, info90.endIn=%d, rotGood=%s", tblGroInfo.begIn, tblGroInfo.endIn, tostring(nowGood), info90.begIn, info90.endIn, tostring(rotGood)))
--ac_environment("tolog", string.format("x1=%f, y1=%f, x2=%f, y2=%f, groDepth=%f, groWidth=%f, groAngle=%f, groAngleLen=%f", x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen))
		lenNow=fnGetLenOnSurf(groFace, y1, y2)
		len90=fnGetLenOnSurf(groFace, tblGro90.y1, tblGro90.y2)
		if rotGood and (len90>lenNow or nowGood==false) then
			-- We have rotated in tblGro90 already but this is nicer way to set all gro pars
			x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen = BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
			tblGroInfo = af_request("mc_getgroinfo", tblGro90)
			nowGood=rotGood
		end

		if not nowGood then
			-- This is a limited groove, cannot use 0306, use 0308 (3D pocket) instead
			-- tblGro is unrotated and tblGro90 is the rotated one, select the one not having lengthwise angle

			if math.abs(tblGro.groTiltAngleRad)>PI1800 then
				tblGro=tblGro90
				tblGroInfo=info90

				if math.abs(tblGro.groTiltAngleRad)>PI1800 then
					AddCncErr( x1, "BVN ERROR: DOUBLE ANGLED GROOVE WRITTEN WITHOUT LENGTHWISE ANGLE" )
					tblGro.groTiltAngleRad=0
				end
			end

--DumpTbl(tblGroInfo)
			-- # Use tblGro values since we may be using rotated one!!!
			-- 0308 takes center point of the bottom projected to the surface
			-- Calculate it
			x=tblGro.x1 + tblGroInfo.vecDownSurf.x * tblGro.depth
			y=tblGro.y1 + tblGroInfo.vecDownSurf.y * tblGro.depth
			z=tblGroInfo.vecDownSurf.z * tblGro.depth					-- Negative inside the plank

			x=x+tblGroInfo.vecLeftSurf.x * tblGro.width*0.5
			y=y+tblGroInfo.vecLeftSurf.y * tblGro.width*0.5
			z=z+tblGroInfo.vecLeftSurf.z * tblGro.width*0.5

			-- Lengthwise angle is zero, we can use length of the groove as it is
			dx=tblGro.x2 - tblGro.x1
			dy=tblGro.y2 - tblGro.y1
			nGroLen=math.sqrt(dx*dx+dy*dy)

			x=x+tblGroInfo.vecLenSurf.x * nGroLen*0.5
			y=y+tblGroInfo.vecLenSurf.y * nGroLen*0.5
			z=z+tblGroInfo.vecLenSurf.z * nGroLen*0.5

			a		=tblGro.groAngleRad*180/PI
			ux		=tblGroInfo.vecLenSurf.x
			uy		=tblGroInfo.vecLenSurf.y

			x=BvnGetXc(x)
			if gnBvnLogDir==EBvnDirEnd then
				ux=-ux
			end

			if bMirrorY then
				y=BvnMirrorYc(y, groFace)
				uy=-uy
			end

			--AddCncErr( 0, string.format("bMirrorY=%s nBvnSide=%d", tostring(bMirrorY), nBvnSide) )

			aSurf=math.atan2(ux, uy)
			if groFace==3 or groFace==4 then
				--a=-a
				aSurf=-math.atan2(ux, -uy)
			end
			aSurf=aSurf*180.0/PI
			if aSurf<0 then
				aSurf=360+aSurf
			end

--ac_environment("tolog", string.format("x=%f y=%f z=%f aSurf=%f a=%f", x, y, z, aSurf, a))

			-- 000006 0308 01     5000    1820     300    4000     500       0     890      30     110       0 000                           
			BvnAddLine( x1, string.format( "%s 0308 %02d %8.0f %7.0f %7.0f %7.0f %7.0f       0 %7.0f       0 %7.0f       0 000                           ",
									   sPieceNum, nBvnSide, 10000*x, 10000*y, -10000*z, 10000*nGroLen, 10000*tblGro.width, 10*aSurf, 10*a ) )

			return
		end

		-- 0306 takes gro bottom edge coordinate projected to surface, calc x,y,z at gro beg
		x=x1+tblGroInfo.vecDownSurf.x*groDepth
		y=y1+tblGroInfo.vecDownSurf.y*groDepth
		z=-tblGroInfo.vecDownSurf.z*groDepth

		a		=-groAngle*180/PI
		
		--aLen	=groAngleLen*180/PI
		aLen	=math.atan2(-tblGroInfo.vecLenSurf.z, math.sqrt(tblGroInfo.vecLenSurf.x*tblGroInfo.vecLenSurf.x + tblGroInfo.vecLenSurf.y*tblGroInfo.vecLenSurf.y))
		a=a/math.abs(math.cos(aLen))			-- Cannot really understand this, but this gives right angle
		aLen	=aLen*180/PI
		

		ux		=tblGroInfo.vecLenSurf.x
		uy		=tblGroInfo.vecLenSurf.y

		x=BvnGetXc(x)
		if gnBvnLogDir==EBvnDirEnd then
			ux=-ux
		end

		if bMirrorY then
			y=BvnMirrorYc(y, groFace)
			uy=-uy
		end

		--AddCncErr( 0, string.format("bMirrorY=%s nBvnSide=%d", tostring(bMirrorY), nBvnSide) )

		aSurf=math.atan2(uy, -ux)
		if groFace==3 or groFace==4 then
			--a=-a
			aLen=-aLen
			aSurf=-math.atan2(uy, ux)
		end
		aSurf=aSurf*180.0/PI
--toLog(string.format("groFace=%f aLen=%f aSurf=%f a=%f x=%f y=%f z=%f", groFace, aLen, aSurf, a, x, y, z))
		if aSurf<-90 then
			aSurf=360+aSurf
		elseif aSurf>270 and aSurf<360.1 then
			aSurf=-(360-aSurf)
		end
		
		BvnAddLine( x, string.format( "%s 0306 %02d %8.0f %7.0f       0 %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0 %3.0f                           ", 
									sPieceNum, nBvnSide, 10000*x, 10000*y, 10000*groWidth, 10000*z, aSurf*10, a*10, aLen*10, nSplinter  ) )

		return
	end

	-- Make y1<y2
	if (y1>y2 and not bMirrorY) or (y1<y2 and bMirrorY) then
		x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen = BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
		x1, y1, x2, y2, groDepth, groWidth, groAngle, groAngleLen = BvnGroRotateToNext(x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
	end

	x1=BvnGetXc(x1)
	x2=BvnGetXc(x2)

	if bMirrorY then
		y1=BvnMirrorYc(y1, groFace)
		y2=BvnMirrorYc(y2, groFace)
	end

	dx=x2-x1
	dy=y2-y1
	nGroLen=math.sqrt(dx*dx+dy*dy)
	
	if groFace==2 or groFace==4 then
		if (y1<0.001 and y2>gnCurrHeight-0.001) or (minY <0.001 and maxY>gnCurrHeight-0.001) then
			nGroLen=0
		end
	elseif groFace==1 or groFace==3 then
		if (y1<0.001 and y2>gnCurrWidth-0.001) or (minY <0.001 and maxY>gnCurrWidth-0.001) then
			nGroLen=0
		end
	end
	--toLog( string.format("y1=%f y2=%f nGroLen=%f", y1, y2, nGroLen) )

	if bMirrorY == BvnIsMirrorXc() then
		-- Change the side of the groove line. In bvn we anchor the right side of the groove
		cosSub=math.cos(groAngle)
		if cosSub<0.001 then
			cosSub=0.001		-- Impossible groove anyway
		end

		unx=-uy*groWidth/cosSub
		uny=ux*groWidth/cosSub

		-- Move the ref line
		x1=x1+unx
		y1=y1+uny
		x2=x2+unx
		y2=y2+uny

		-- Change depth (neg makes deeper, pos shallower)
		groDepth=groDepth-math.sin(groAngle)*groWidth/cosSub
		groAngle=-groAngle
	end
	
	if math.abs(groAngleLen)>PI1800 then
		if math.abs(groAngle)>PI1800 or math.abs(x2-x1)>0.001 or y2-y1<0.001 then
			-- After 0306 never reached
			AddCncErr( x1, "BVN ERROR: LENGTHWISE TILTED GROOVE NOT SUPPORTED WITH GIVEN PARAMETERS - GROOVE SKIPPED" )
			return
		else
			-- Straight cut angled lengthwise
			-- Use cutter
			-- "000001 0302 01     2989       0       0    3000     387    -387  -300.1       0       0       0 000                           "
			local	d1, d2

			len=gnCurrWidth
			if groFace==2 or groFace==4 then
				len=gnProfHeight
			end

			-- Depth if y1 is zero
			d1=groDepth/math.cos(groAngleLen)

			-- Adjust according to y1
			nTan=math.tan(groAngleLen)
			d1=d1-nTan*y1	--orgY1
			d2=d1+nTan*len

--toLog(string.format("groAngleLen=%f d1=%f d2=%f len=%f nTan=%f", groAngleLen, d1, d2, len, nTan))
			-- k2.exe feature/bug: zero depth means something else
			if math.abs(d1)<0.0001 then
				d1=0.0001
			end
			if math.abs(d2)<0.0001 then
				d2=0.0001
			end

			if false and bMirrorY then
				temp=d1
				d1=d2
				d2=temp
				groAngleLen=-groAngleLen
			end

			BvnAddLine( x1, string.format( "%s 0302 %02d %8.0f       0       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 %3.0f                           ", 
										sPieceNum, nBvnSide, 10000*x1, 10000*groWidth, 10000*d1, 10000*d2, 10*groAngleLen, nSplinter) )

			return
		end
	end

--ac_environment("tolog", string.format("tblGroInfo.begIn=%d, tblGroInfo.endIn=%d", tblGroInfo.begIn, tblGroInfo.endIn))
	local	groMaxDepth=0.159
	local	mcEnv

	mcEnv=af_request("mc_getenv")
	if mcEnv and mcEnv.gromaxdepth then
		groMaxDepth=mcEnv.gromaxdepth+EPS
	end

	--toLog( string.format( "GRO1, x1=%.3f y1=%.3f x2=%.3f y2=%.3f groDepth==%.3f groWidth=%.3f groAngle=%.3f groFace=%.3f groAngleLen=%.3f nGroLen=%.3f", x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen, nGroLen ) )
	if (nGroLen>0 and nGroLen<0.0196) and math.abs(groAngleLen)<PI180 and math.abs(groAngle)<PI180 and math.abs(x1-x2)<0.001 and y1<y2 then
		-- <20 mm lengthwise groove with chainsaw/0502
		-- groove to left from given x-coordinates, y1<y2, x1=x2
		local	x, y, d

		x=x1
		--if gnBvnLogDir==EBvnDirBeg then
		--	x=x-groWidth
		--end

		d=groDepth
		if d+0.001>faceDepth then
			d=0
		end

		BvnAddLine( x, string.format(	"%s 0502 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f              10       0       0 000                           ",
									sPieceNum, nBvnSide, 10000*x, 10000*(y1 + y2)*0.5, 10000*groWidth, 10000*d, 10000*(y2-y1) ) )

	elseif groDepth>groMaxDepth and math.abs(groAngleLen)<PI180 and math.abs(groAngle)<PI180 and nGroLen==0 and math.abs(x2-x1)<0.001 and not atEnd then
		-- Cutter cannot do this deep grooves, two sawings and chainsaw for the bottom
		local w, chainFace, chainFaceBvn, yBottom, chainThick

		-- Saw beg&end
		-- 000001 0109 03     4215       0       0    4215    1820    1765       0       0      10       0 000                           
		w=groWidth/math.abs(math.cos(math.atan2(x2-x1, y2-y1)))
		BvnAddLine( x1, string.format( "%s 0109 %02d %8.0f       0       0 %7.0f %7.0f %7.0f       0       0      10       0 000                           ",
								   sPieceNum, nBvnSide, 10000*x1, 10000*x2, 10000*y2, 10000*groDepth ) )

		BvnAddLine( x1+w, string.format( "%s 0109 %02d %8.0f       0       0 %7.0f %7.0f %7.0f       0       0       0       0 000                           ",
								   sPieceNum, nBvnSide, 10000*(x1+w), 10000*(x2+w), 10000*y2, 10000*groDepth ) )
								   

		-- Chainsaw bottom. THIS LIMITS THE GROOVE TO 90 DEG
		chainThick=0.008			-- Must match the machine
		chainFace=groFace+1
		if chainFace>4 then
			chainFace=1
		end
		
		yBottom=groDepth
		yBottom=yBottom-chainThick*0.5
		if groFace==1 then
			yBottom=gnProfHeight-yBottom
		elseif groFace==4 then
			yBottom=gnCurrWidth-yBottom
		end

		chainFaceBvn,bMirrorY=BvnGetSide(chainFace)
		if bMirrorY then
			yBottom=BvnMirrorYc(yBottom, chainFace)
		end

		-- 000001 0800 04     4220    1040       0    1640       0      80       0       0       0       0 000                           
		BvnAddLine( x1, string.format( "%s 0800 %02d %8.0f %7.0f       0 %7.0f       0 %7.0f       0       0       0       0 000                           ",
								   sPieceNum, chainFaceBvn, 10000*(x1+0.0005), 10000*yBottom, 10000*(groWidth-0.001), 10000*chainThick) )

	elseif (tblGroInfo.begIn==1 or tblGroInfo.endIn==1) and (math.abs(groAngleLen)<PI1800 and math.abs(groAngle)<PI1800 and math.abs(x2-x1)>EPS) then
		-- 5/2016: Groove where x1<>x2, 0301 made top and bottom always in plank's dir
		-- 000333 0305 01     8000    1550       0     400    1000     200    2000       0      10     900 000                           
		-- 8000 pos
		-- 1550 y-coordinate
		--  400 width of the groove
		-- 1000 length of the groove
		--  200 depth
		-- 2000 angle
		--   10 with corner drill
		--  900 inner angle
		--  000 splinter free

		a=1800*math.atan2(y1-y2, x1-x2)/PI
		BvnAddLine( x1, string.format( "%s 0305 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0      10     900 %3.0f                           ",
								   sPieceNum, nBvnSide, 10000*x2, 10000*y2, 10000*groWidth, 10000*nGroLen, 10000*groDepth, a, nSplinter ) )

	else
		local	d, a2
		
		if math.abs(groAngleLen)>PI1800 then
			-- After 0306 never reached
			AddCncErr( x1, "BVN ERROR: LENGTHWISE TILTED GROOVE NOT SUPPORTED WITH GIVEN PARAMETERS - GROOVE SKIPPED" )
			return
		end

		groAngle=-groAngle
		-- 0301 ottaa koordinaatit uran pohjaan, syvyys kappaleen pinnasta
		x=(x1+x2)*0.5
		y=(y1+y2)*0.5
		a=math.atan2(y2-y1, x1-x2)

		-- Move center pt (normal to left)
		dx=-(y2-y1)
		dy=x2-x1
		len=math.sqrt(dx*dx+dy*dy)
		d=groDepth*math.sin(groAngle)
		x=x+dx/len*d
		y=y+dy/len*d

		groDepth=groDepth*math.cos(groAngle)

		--toLog( string.format( "GRO2, x1=%.3f y1=%.3f x2=%.3f y2=%.3f groDepth==%.3f groWidth=%.3f groAngle=%.3f groFace=%.3f groAngleLen=%.3f x=%.3f y=%.3f", x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen, x, y ) )

		a=1800*a/PI
		if math.abs(a)<1 then
			a=0
		end
		a2=1800*groAngle/PI
		if math.abs(a2)<1 then
			a2=0
		end
		BvnAddLine( x1, string.format( "%s 0301 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0 %7.0f       0 %3.0f                           ",
								   sPieceNum, nBvnSide, 10000*x, 10000*y, 10000*groWidth, 10000*nGroLen, 10000*groDepth, a, a2, nSplinter ) )
	end
end


-- Calculates y-offset here!
function BvnAddDrill(sPieceNum, x1, y1, diameter, depth, face)
	local	nBvnSide, bMirrorX, bMirrorY, pos

	if face~=1 and face~=3 then
		y1=y1-gnBvnYoffset
	end

	if face==5 or face==6 then
		-- To beg
		-- 000001 0401 03        0    1025    1025     400    1600     900       0       0       0       0 000                           
		if face==5 then
			nBvnSide,bMirrorX,bMirrorY=BvnGetLogBegBvnSide(3)
			pos=BvnGetXc(0)
		else
			nBvnSide,bMirrorX,bMirrorY=BvnGetLogEndBvnSide(3)
			pos=BvnGetXc(gnCurrTotLen)
		end

		if bMirrorX then
			x1=gnCurrWidth-x1
		end

		if bMirrorY then
			y1=gnProfHeight-y1
		end

		BvnAddLine( pos, string.format( "%s 0401 %02d %8.0f %7.0f %7.0f %7.0f %7.0f     900       0       0       0       0 000                           ",
								   sPieceNum, nBvnSide, 10000*pos, 10000*x1, 10000*y1, 10000*diameter, 10000*depth) )
		
		if diameter<0.040-EPS then
			AddCncErr( 0, "BVN WARNING: DRILLING TO THE BEG OR END MINIMUM DRILL DIAMETER IS 40 MM - SAVED TO BVN ANYWAY" )
		end
		return
	end

	nBvnSide,bMirrorY=BvnGetSide(face)
	x1=BvnGetXc(x1)

	if bMirrorY then
		y1=BvnMirrorYc(y1, face)
	end

	BvnAddLine( x1, string.format(	"%s 0400 %02d %8.0f %7.0f         %7.0f %7.0f                                         000                           ",
									sPieceNum, nBvnSide, 10000*x1, 10000*y1, 10000*diameter, 10000*depth) )
end


-- Adds marking to bvn-file
function BvnAddMarking(sPieceNum, groFace, x1, y1, x2, y2, xPosText, yPosText, fontSize, textOff, strText, bAddLine, bInLineDir)
-- 0600 Line without text, angle possible if inkjet
-- 0601 Text with straight line
--000001 0600 -3     4000     200       0       0     300       0       0       0       0       0 000                           
--000001 0601 -3     4000       0      10       0       0      10 TXT                             050                           
	local	nBvnSide, bMirrorY, pos, res, x, y, angle, orgy1, orgy2

	if groFace>=5 then
		AddCncErr(0, string.format("BVN: MARKINGS NOT SUPPORTED TO THE BEGIN/END OF THE PIECE - SKIPPED") )
		return
	end

	if nTextHeight==nil then
		nTextHeight=0
	end
	orgy1=y1
	orgy2=y2
	nBvnSide,bMirrorY=BvnGetSide(groFace)
	nBvnSide=-nBvnSide
	x1=BvnGetXc(x1)
	x2=BvnGetXc(x2)
	if bMirrorY then
		y1=BvnMirrorYc(y1, groFace)
		y2=BvnMirrorYc(y2, groFace)
	end
	
	if y1>y2 then
		-- swap
		x1,x2=x2,x1
		y1,y2=y2,y1
	end
	
	if bAddLine==nil then
		bAddLine=true
	end

	-- Extend to line so that y is 0
	
-- 1. bool, true=has intersection
-- 2. number, x
-- 3. number, y
	x=x1
	y=y1
	res,x1,y1=GetLinesX( x1, y1, x2, y2, 0, 0, 1, 0 )
	if res==false and bAddLine then
		AddCncErr( x1, string.format("BVN WARNING: MARKER DOES NOT CROSS THE PLANK - SKIPPED (X1=%.3f Y1=%.3f X2=%.3f Y2=%.3f)", x, y, x2, y2) )
		return
	end
	if res==false then
		x1=x
		y1=y
	end
	
	angle=math.atan2(x2-x1, y2-y1)
	if math.abs(angle)<PI/180.0 then
		angle=0
	end

	if bAddLine==true and (strText=="" or angle~=0) then
		-- Line with angle or no text
		BvnAddLine( x1, string.format(	"%s 0600 %02d %8.0f %7.0f       0       0 %7.0f       0       0       0       0       0 000                           ",
										sPieceNum, nBvnSide, 10000*x1, 10000*y1, 10*180*angle/PI) )
	end
	
	if strText~="" then
		-- Line with no angle and/or text
		local	scribing, txtDir
		
		scribing=10
		if angle~=0 or bAddLine==false then
			scribing=0
		end

		if math.abs(x2-x1)<0.0001 and math.abs(orgy2-orgy1)>0.001 and bInLineDir then
			-- 90deg to the plank
			xPosText,yPosText=yPosText,xPosText			-- Swap - alignment
			if orgy1<orgy2 then
				if bMirrorY then
					txtDir=20
				else
					txtDir=40
				end
			else
				if bMirrorY then
					txtDir=40
				else
					txtDir=20
				end
			end
		else
			txtDir=0
			if bMirrorY then
				txtDir=10
			end
		end
		
--toLog( string.format("strText=%s xPosText=%d, x1=%f, x2=%f, bInLineDir=%s", strText, xPosText, x1, x2, tostring(bInLineDir)) )
		if gnBvnLogDir==EBvnDirEnd then
			-- txtDir 0/10 not affected by this (bMirrorY must be set already)
			if xPosText==1 then
				xPosText=3
			elseif xPosText==3 then
				xPosText=1
			end
		end

		if xPosText==1 then
			-- To beg
			xPosText=0
			if gnBvnLogDir==EBvnDirEnd then
				x=x2
			else
				x=x1
			end
		elseif xPosText==2 then
			-- Center
			xPosText=20
			x=(x1+x2)*0.5
		else
			-- To end
			xPosText=10
			if gnBvnLogDir==EBvnDirEnd then
				x=x1
			else
				x=x2
			end
		end

		if yPosText==1 then
			-- To bot
			yPosText=0
			if bMirrorY then
				yPosText=10
			end
				
		elseif yPosText==2 then
			-- Center
			yPosText=20
		else
			-- To top
			yPosText=10
			if bMirrorY then
				yPosText=0
			end
		end
		
		if gnBvnForceTextSize~=nil then
			fontSize=gnBvnForceTextSize*10000/100
		end

		BvnAddLine( x, string.format(	"%s 0601 %02d %8.0f %7.0f %7.0f       0 %7.0f %7.0f %-20.20s            %03d                           ",
										sPieceNum, nBvnSide, 10000*x, 100*fontSize, scribing, yPosText, xPosText, strText, txtDir) )
	end
end


-- nAngleTopDeg, angle from top 0=straight cut
function BvnAddBegEndTenon( sPieceNum, nBvnSide, bDove, tenonLen, tenonWidth, tenonHeight, borderBot, 
							nAngleSideDeg, nAngleTopDeg, roundingRadius, angleDoveDeg )

	-- Esim: "000911 0500 -3    17440     670             900    1140     670      50     -10    1600         000                           "
	--		  000001 0500 -3    18320     560             900     680     440      50     -10    1600         000                           
	
	local xc, nWidth, bMirrorY, x, y, z, ta, tb, tc, td


	-- Lohenpyrstön ja tapin koordinaatti on bvn-tiedostossa tapin alapuolen pinnassa tapin keskellä
	-- Seuraava toimii, jos ei ole sivukallistusta
	-- xc=tenonLen
	-- xc=xc/math.cos(nAngleTopDeg*PI/180.0)+math.tan(math.abs(nAngleTopDeg)*PI/180.0)*gnCurrWidth*0.5
	
	-- Lasketaan kapulan perusviivan etäisyys leikkaamattomasta päästä
	
	-- Pään tason kohtisuora. Rotate-vektori on kohtisuora vasemmalle päältä kallistetun normaalista.
	x=math.cos(nAngleTopDeg*PI/180.0)
	y=math.sin(nAngleTopDeg*PI/180.0)
	x,y,z=RotateSingle3D(x, y, 0, -y, x, 0, -nAngleSideDeg*PI/180.0)

	ta, tb, tc, td=MakePlaneNormal(x, y, z, -x*tenonLen, -y*tenonLen, -z*tenonLen)

	-- Paljonko tasoa pitää siirtää, että koko pääty saa sopivan muodon (ei optimoida, jos tappi mahtuisi viistossa ilman tapin verran pidennystä)
	local tasoTbl, tasoCount, cutOffsets, maxDist

	tasoTbl={}
	tasoTbl[1]={}
	tasoCount=1
	tasoTbl[1][1]=ta
	tasoTbl[1][2]=tb
	tasoTbl[1][3]=tc
	tasoTbl[1][4]=td

	cutOffsets, maxDist=CutEndingWithPlanes(tasoTbl, tasoCount, gnCurrWidth, gnProfHeight)
	xc=maxDist


	if nBvnSide<0 then
		-- At the left side/end in bvn-coordinates
		xc=gnCurrTotLen-xc
	end

	bMirrorY=BvnGetBegEndMirrorY()
	if bMirrorY then
		nAngleSideDeg=-nAngleSideDeg
	end

	local	b90Side, b90Top, sRoundType
	
	b90Side=false
	b90Top=false
	
	if gnBvnLogDir==EBvnDirEnd then
		nAngleTopDeg=-nAngleTopDeg
	end

	if math.abs(nAngleTopDeg)<0.5 then 
		nAngleTopDeg=0
		b90Top=true
	end

	if math.abs(nAngleSideDeg)<0.5 then 
		nAngleSideDeg=0
		b90Side=true
	end

	if not b90Side then
		AddCncErr(xc, string.format("BVN: TILTED ENDINGS NOT TESTED - CHECK CAREFULLY (top=%f, side=%f)", nAngleTopDeg, nAngleSideDeg) )
	end

	-- From -89...89 to 1...179
	nAngleTopDeg=nAngleTopDeg+90
	nAngleSideDeg=nAngleSideDeg+90

	sRoundType="  0"		-- Ovaali
	if gbK2Tenon then
		if roundingRadius<0.023 then
			sRoundType="-10"	-- Rounded
		else
			sRoundType=string.format("%7.0f", 10000*roundingRadius)		-- 9/2020: Added rounding radius to Hundegger
		end
	end
	if roundingRadius<EPS then
		sRoundType=" 10"	-- Square
	end

	if bDove then
		-- Dovetail
		if borderBot<0 then
			tenonHeight=tenonHeight-borderBot
			borderBot=0
		end
		if gbDoveWith1700 or not b90Side then
			-- 000921 1700 -2    17440     670       0     900     600     250      60       0    1600     380 000                           
			BvnAddLine( xc, string.format(	"%s 1700 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f 000                           ",
											sPieceNum, nBvnSide, 10000*xc, 10000*gnCurrWidth*0.5, 10*nAngleSideDeg, 10000*tenonWidth, 10000*borderBot, 10*angleDoveDeg, 10*(nAngleTopDeg-90), 10000*tenonHeight, 10000*tenonLen ) )
		else
			BvnAddLine( xc, string.format(	"%s 1701 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f 000                           ",
											sPieceNum, nBvnSide, 10000*xc, 10000*gnCurrWidth*0.5, 10*nAngleTopDeg,  10000*tenonWidth, 10000*borderBot, 10*angleDoveDeg, 10*nAngleSideDeg, 10000*tenonHeight, 10000*tenonLen ) )
		end
		
		return
	end

	-- Tenon
	if not b90Side and not b90Top then
		-- Double titled
		BvnAddLine( xc, string.format(	"%s 0500 %02d %8.0f %7.0f         %7.0f %7.0f %7.0f %7.0f %7s %7.0f %7.0f 000                           ",
										sPieceNum, nBvnSide, 10000*xc, 10000*gnCurrWidth*0.5, 10*nAngleSideDeg, 10000*tenonWidth, 10000*tenonLen, 10000*borderBot, sRoundType, 10000*tenonHeight, 10*(nAngleTopDeg-90) ) )
	elseif b90Top then
		-- Tilted from side
		BvnAddLine( xc, string.format(	"%s 0500 %02d %8.0f %7.0f         %7.0f %7.0f %7.0f %7.0f %7s %7.0f         000                           ",
											sPieceNum, nBvnSide, 10000*xc, 10000*gnCurrWidth*0.5, 10*nAngleSideDeg, 10000*tenonWidth, 10000*tenonLen, 10000*borderBot, sRoundType, 10000*tenonHeight ) )
	else
		-- Tilted looking from top
		BvnAddLine( xc, string.format(	"%s 0501 %02d %8.0f %7.0f         %7.0f %7.0f %7.0f %7.0f %7s %7.0f         000                           ",
										sPieceNum, nBvnSide, 10000*xc, 10000*gnCurrWidth*0.5, 10*nAngleTopDeg, 10000*tenonWidth, 10000*tenonLen, 10000*borderBot, sRoundType, 10000*tenonHeight ) )
	end
end



-- nType ETypeXXX: 1=tenon, 2=dt, 3=mortise, 4=dt-pocket
function BvnAddBegEndTenonMortNewInt(	sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, x, y, z, nSide, nType, nRotAngleDeg, 
									tenonLen, tenonWidth, tenonHeight, roundingRadius, nAngleTenonDeg )

	local nBvnSide, bMirrorY, faceDy, sRoundType, tblInfo, tblTenonRes, angleHun, bevelHun, rotHun, b


	-- Get 
	tblInfo={}
	tblInfo.guid		= gsCurrentLogGuid
	tblInfo.isBeg		= isBeg
	tblInfo.angleTopDeg	= nAngleTopDeg
	tblInfo.angleSideDeg= nAngleSideDeg
	tblInfo.x			= x
	tblInfo.y			= y
	tblInfo.z			= z
	tblInfo.side		= nSide
	tblInfo.type		= nType
	tblInfo.rotAngleDeg	= nRotAngleDeg
	tblInfo.tenonLen	= tenonLen
	tblInfo.tenonWidth	= tenonWidth
	tblInfo.tenonHeight	= tenonHeight

	tblTenonRes = af_request("mc_gettenoninfo", tblInfo)
	--DumpTbl(tblTenonRes)
	
	-- Hundegger has tenon anchor at anchor surface (instead of tenon bottom)
	x = tblTenonRes.xBot
	y = tblTenonRes.yBot
	-- z = tblTenonRes.hunBackCut

	-- Anchor
	nBvnSide,bMirrorY=BvnGetSide(nSide)
	if isBeg==false then
		nBvnSide=-nBvnSide
	end
	if gnBvnLogDir==EBvnDirEnd then
		nBvnSide=-nBvnSide
	end

	-- Tenon bottom mid
	if isBeg==false then
		x=gnCurrTotLen-x
	end
	x=BvnGetXc(x)

	faceDy=gnCurrWidth
	if nSide==2 or nSide==4 then
		faceDy=gnProfHeight
	end
	y=faceDy*0.5+y			-- Saved as offset from middle

	-- Shape
	sRoundType="  0"		-- Ovaali
	if gbK2Tenon then
		if roundingRadius<0.023 then
			sRoundType="-10"	-- Rounded
		else
			sRoundType=string.format("%7.0f", 10000*roundingRadius)		-- 9/2020: Added rounding radius to Hundegger
		end
	end
	if roundingRadius<EPS then
		sRoundType=" 10"	-- Square
	end

	-- Adjust values for tenon
	angleHun = tblTenonRes.hunAngleDeg
	bevelHun = tblTenonRes.hunBevelDeg
	rotHun = tblTenonRes.hunRotDeg

	--AddCncErr( 0, string.format("bMirrorY=%s angleHun=%f", tostring(bMirrorY), angleHun) )

	b=bMirrorY
	if nSide==1 or nSide==2 then
		b=not b
	end
	if b then
		nAngleTopDeg=180-nAngleTopDeg
		angleHun=180-angleHun
		y=faceDy-y
	end

	if isBeg then
		rotHun=-rotHun
	end
	if gnBvnLogDir==EBvnDirEnd then
		rotHun=-rotHun
	end

	if not gMortHousing then		-- Housing added 12/2019
		gMortHousing=0
	end

	if nType==1 then
		-- Tenon
		BvnAddLine( x, string.format(	"%s 0500 %02d %8.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7s %7.0f %7.0f 000                           ",
										sPieceNum, nBvnSide, 10000*x, 10000*y, 10*rotHun, 10*bevelHun, 10000*tenonWidth, 10000*tenonLen, 10000*tblTenonRes.hunBackCut, sRoundType, 10000*tenonHeight, 10*(angleHun-90) ) )
	elseif nType==2 then
		-- DT
		if math.abs(rotHun)>0.5 then
			AddCncErr( x, string.format("ERROR: ROTATED DOVETAIL NOT SUPPORTED IN HUNDEGGER - SKIPPED (rot angle=%.3f) ***", rotHun) )
		else
			local borderBot

			borderBot=tblTenonRes.hunBackCut
			if borderBot<0 then
				tenonHeight=tenonHeight+borderBot
				borderBot=0
			end
			BvnAddLine( x, string.format(	"%s 1700 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f 000                           ",
											sPieceNum, nBvnSide, 10000*x, 10000*y, 10*bevelHun, 10000*tenonWidth, 10000*borderBot, 10*nAngleTenonDeg, 10*(angleHun-90), 10000*tenonHeight, 10000*tenonLen ) )
		end
	elseif nType==3 then
		-- Mortise
		if math.abs(rotHun)>0.5 then
			AddCncErr( x, string.format("ERROR: ROTATED MORTISE AT END NOT SUPPORTED IN HUNDEGGER - SKIPPED ***") )
		else
			--Known limitation: len must be > width. No workaround
			if tenonWidth>tenonHeight+0.0001 then
				AddCncErr( x, string.format("ERROR: MORTISE WIDTH > HEIGHT, NOT SUPPORTED IN HUNDEGGER (SAVED INTO FILE ANYWAY)") )
			end

			tenonLen=tenonLen+gMortHousing

			if math.abs(nAngleTopDeg-90)>0.5 then
				if math.abs(nAngleSideDeg-90)>0.5 then
					AddCncErr( x, string.format("ERROR: DOUBLE TILTED MORTISE END NOT SUPPORTED IN HUNDEGGER - SKIPPED ***") )
					return
				end

				-- Top angle only
				BvnAddLine( x, string.format(	"%s 0505 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7s %7.0f       0 000                           ",
											sPieceNum, nBvnSide, 10000*x, 10000*y, 10*nAngleTopDeg, 10000*tenonWidth, 10000*tenonLen, 10000*tblTenonRes.hunBackCut, sRoundType, 10000*tenonHeight ) )
			else
				-- Bevel only or straight. 
				BvnAddLine( x, string.format(	"%s 0504 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7s %7.0f       0 000                           ",
											sPieceNum, nBvnSide, 10000*x, 10000*y, 10*nAngleSideDeg, 10000*tenonWidth, 10000*tenonLen, 10000*tblTenonRes.hunBackCut, sRoundType, 10000*tenonHeight ) )
			end
		end

	elseif nType==4 then
		-- DT Mortise
		if math.abs(rotHun)>0.5 then
			AddCncErr( x, string.format("ERROR: ROTATED DT-MORTISE AT END NOT SUPPORTED IN HUNDEGGER - SKIPPED ***") )
		else
			--Known limitation: len must be > width. No workaround
			--if tenonWidth>tenonHeight+0.0001 then
			--	AddCncErr( x, string.format("ERROR: MORTISE WIDTH > HEIGHT, NOT SUPPORTED IN HUNDEGGER (SAVED INTO FILE ANYWAY)") )
			--end

			if gMortHousing~=0 then
				AddCncErr( x, string.format("ERROR: HOUSING VALUE NONZERO AT THE END OF THE PIECE FOR DT-MORTISE - HOUSING SKIPPED ***") )
			end

			if math.abs(nAngleTopDeg-90)>0.5 then
				if math.abs(nAngleSideDeg-90)>0.5 then
					AddCncErr( x, string.format("ERROR: DOUBLE TILTED DT-MORTISE END NOT SUPPORTED IN HUNDEGGER - SKIPPED ***") )
					return
				end

				-- Top angle only
				BvnAddLine( x, string.format(	"%s 1705 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0       0 %7.0f 000                           ",
											sPieceNum, nBvnSide, 10000*x, 10000*y, 10*nAngleTopDeg, 10000*tenonWidth, 10000*tblTenonRes.hunBackCut, 10*nAngleTenonDeg, 10000*tenonLen ) )
			else
				-- Bevel only or straight. 
				BvnAddLine( x, string.format(	"%s 1704 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0       0 %7.0f 000                           ",
											sPieceNum, nBvnSide, 10000*x, 10000*y, 10*nAngleSideDeg, 10000*tenonWidth, 10000*tblTenonRes.hunBackCut, 10*nAngleTenonDeg, 10000*tenonLen ) )
			end
		end
	end
end


-- nType ETypeXXX: 1=tenon, 2=dt, 3=mortise, 4=dt-pocket, 5=Honka dove, 6=Honka mortise
function BvnAddBegEndTenonMortNew(	sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, x, y, z, nSide, nType, nRotAngleDeg, 
									tenonLen, tenonWidth, tenonHeight, roundingRadius, nAngleTenonDeg )

	if nType==5 then
		-- Honka DT corner tenon
		local	sType, toR, x

		nType=3						-- Made with mortise tool
		sType = ac_objectget( "hirsityyppi")
		if sType==nil then
			sType="?"
		end

		-- Convert to top
		if nSide~=3 then
			AddCncErr( 0, string.format("VIRHE NOLLANURKKA: ALKUPERÄINEN TAPPI PITÄÄ OLLA ANKKUROITU ALAPINTAAN (3), TYÖSTÖ OHITETTU") )
			return
		end
		nSide=1
		nAngleTopDeg=180-nAngleTopDeg

		if math.abs(nAngleTopDeg-45)<1 then
			toR=true
		elseif math.abs(nAngleTopDeg-135)<1 then
			toR=false
		else
			AddCncErr( 0, string.format("VIRHE NOLLANURKKA: NURKKA EI OLE 90 ASTEEN NURKKA (%f)", nAngleTopDeg) )
			return
		end

		-- Calculate offsets to add to x-coordinate (dir=from end inside the plank) and to y-coordinate (towards middle of the plank)
		local gapx, gapy

		gapx=0
		gapy=0
		if gnZeroTailGap~=nil then
			-- Honka Logs cnc-writer, now only 90 deg corners
			gapx=gnZeroTailGap/1.4142
			gapy=gapx
		end

		if math.abs(gnCurrWidth-0.204)<EPS then
			-- MLL 204xxx
			if sType=="MLL 204N" then
				-- For gro
				x=0.012
				if isBeg then
					x=x+0.060
				else
					x=gnCurrTotLen-x
				end

				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, -0.0180+gapx, -0.0546+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1426-gapx, 0.1061-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.082, 0.060, 0, 2, 0)
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, -0.0180+gapx, 0.0546-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1426-gapx, -0.1061+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.082, 0.060, 0, 4, 0)
				end
			else
				if sType~="FXL 204N" then
					AddCncErr( 0, string.format("VAROITUS NOLLANURKKA: EI MÄÄRITYSTÄ MATERIAALILLE %s, TEHDÄÄN KUTEN FXL 204", sType) )
				end

				-- For gro
				x=0.023
				if isBeg then
					x=x+0.060
				else
					x=gnCurrTotLen-x
				end

				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, -0.0079+gapx, -0.0655+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1634-gapx, 0.1059-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.092, 0.060, 0, 2, 0)
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, -0.0079+gapx, 0.0655-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1634-gapx, -0.1059+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.022, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.092, 0.060, 0, 4, 0)
				end
			end
		elseif math.abs(gnCurrWidth-0.134)<EPS then
			-- MLL 134xxx
			if sType=="MLL 134N" then
				-- For gro
				x=-0.015
				if isBeg then
					x=x+0.060
				else
					x=gnCurrTotLen-x
				end

				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, -0.0263+gapx, -0.0361+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0944-gapx, 0.0847-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.048, 0.060, 0, 2, 0)
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, -0.0263+gapx, 0.0361-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0944-gapx, -0.0847+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.048, 0.060, 0, 4, 0)
				end
			else
				if sType~="FXL 134N" then
					AddCncErr( 0, string.format("VAROITUS NOLLANURKKA: EI MÄÄRITYSTÄ MATERIAALILLE %s, TEHDÄÄN KUTEN FXL 134N", sType) )
				end

				x=0.011
				if isBeg then
					x=x+0.060
				else
					x=gnCurrTotLen-x
				end

				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0055+gapx, -0.0361+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1263-gapx, 0.0847-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.053, 0.060, 0, 2, 0)
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0055+gapx, 0.0361-gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1263-gapx, -0.0847+gapy, -0.100, nSide, nType, nRotAngleDeg,
												0.018, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )

					BvnAddGro(sPieceNum, x, 0, x, gnProfHeight, 0.053, 0.060, 0, 4, 0)
				end
			end
		else
			AddCncErr( 0, string.format("VIRHE NOLLANURKKA: EI MÄÄRITYSTÄ MATERIAALILLE %s LEV=%.0f mm, TYÖSTÖ OHITETTU", sType, gnCurrWidth*1000) )
		end

	elseif nType==6 then
		-- Honka DT corner pocket
		local	sType, toR

		nType=3						-- Made with mortise tool
		sType = ac_objectget( "hirsityyppi")
		if sType==nil then
			sType="?"
		end

		-- Convert to top
		if nSide~=3 then
			AddCncErr( 0, string.format("VIRHE NOLLANURKKA: ALKUPERÄINEN TASKU PITÄÄ OLLA ANKKUROITU ALAPINTAAN (3), TYÖSTÖ OHITETTU") )
			return
		end
		nSide=1
		nAngleTopDeg=180-nAngleTopDeg

		if math.abs(nAngleTopDeg-45)<1 then
			toR=true
		elseif math.abs(nAngleTopDeg-135)<1 then
			toR=false
		else
			AddCncErr( 0, string.format("VIRHE NOLLANURKKA: NURKKA EI OLE 90 ASTEEN NURKKA (%f)", nAngleTopDeg) )
			return
		end

		if math.abs(gnCurrWidth-0.204)<EPS then
			-- MLL 204xxx
			if sType=="MLL 204N" then
				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0593, -0.0147, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1006, 0.0266, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				else
					-- To left from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0593, 0.0147, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1006, -0.0266, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				end

			else
				if sType~="FXL 204N" then
					AddCncErr( 0, string.format("VAROITUS NOLLANURKKA: EI MÄÄRITYSTÄ MATERIAALILLE %s, TEHDÄÄN KUTEN FXL 204", sType) )
				end

				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0628, -0.0258, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1152, 0.0266, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0628, 0.0258, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.1152, -0.0266, -0.100, nSide, nType, nRotAngleDeg,
												0.0354, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				end
			end
		elseif math.abs(gnCurrWidth-0.134)<EPS then
			-- MLL/FXL 134xxx
			local xoff

			if sType=="MLL 134N" then
				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0475, 0.0079, -0.100, nSide, nType, nRotAngleDeg,
												0.0314, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0475, -0.0079, -0.100, nSide, nType, nRotAngleDeg,
												0.0314, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				end

			else
				if sType~="FXL 134N" then
					AddCncErr( 0, string.format("VAROITUS NOLLANURKKA: EI MÄÄRITYSTÄ MATERIAALILLE %s, TEHDÄÄN KUTEN FXL 134N", sType) )
				end

				if toR then
					-- To right from plank's dir
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0499, 0.0079, -0.100, nSide, nType, nRotAngleDeg,
												0.0314, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				else
					BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, 0.0499, -0.0079, -0.100, nSide, nType, nRotAngleDeg,
												0.0314, 0.040, gnProfHeight+0.150, 0, nAngleTenonDeg )
				end
			end
		else
			AddCncErr( 0, string.format("VIRHE NOLLANURKKA: EI MÄÄRITYSTÄ MATERIAALILLE %s, TYÖSTÖ OHITETTU", sType) )
		end
	else
		BvnAddBegEndTenonMortNewInt(sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, x, y, z, nSide, nType, nRotAngleDeg, 
									tenonLen, tenonWidth, tenonHeight, roundingRadius, nAngleTenonDeg )
	end
end


-- x	distance from the end of the plank to the joint machining (excluding len), usually or always 0
function BvnAddBegEndJoint( sPieceNum, isBeg, x, nSide, len, straight, jointType )
	local nBvnSide, nPos

	if isBeg then
		nPos=x
	else
		nPos=gnCurrTotLen-x
	end
	if isBeg then
		nBvnSide = BvnGetLogBegBvnSide(1+(nSide+1)%4)
	else
		nBvnSide = BvnGetLogEndBvnSide(1+(nSide+1)%4)
	end

-- Last 100 is splinter free
	nPos = BvnGetXc(nPos)
	if jointType==0 then
		--000100 1200 02        0       0       0     750     750    6000      20     120       0       0 100
		BvnAddLine( nPos, string.format(	"%s 1200 %02d %8.0f       0       0 %7.0f %7.0f %7.0f       0       0       0       0 100                           ",
			sPieceNum, nBvnSide, 10000*nPos, 10000*straight, 10000*straight, 10000*len ) )
	elseif jointType==1 then
		-- 000001 1300 -2     8289       0       0     495    3960     120       0       0       0       0 100
		BvnAddLine( nPos, string.format(	"%s 1300 %02d %8.0f       0       0 %7.0f %7.0f       0       0       0               0 100                           ",
			sPieceNum, nBvnSide, 10000*nPos, 10000*straight, 10000*len ) )
	else
		AddCncErr( 0, string.format("ERROR: UNSUPPORTED BEG/END JOINT TYPE (%d) -SKIPPED", jointType))
	end
end


function TernaryIf(condition, yes, no)
	if condition then
		return yes
	else
		return no
	end
end


function BvnFormatDaboSawCut(sPieceNum, side, x, y, width, angle, sawLocation)
	return string.format(
		"%s 0109 %02d %8.0f       0       0 %7.0f %7.0f %7.0f %7.0f       0      %02d       0 010                           ",
		sPieceNum, side, 10000*x, 10000*x, 10000*width, 10000*y, 10*angle, sawLocation)
end


function BvnFormatBirdsMouthCut(sPieceNum, side, length, roofPitch, depth)

	--000000 0103 02      131     184       0       0     900      92     900    1523       0       0 000                           
	--  P   CODE  SIDE LENGTH                PTCH  DPTH  DRILL RFT HEIGHT
	return string.format(
		"%s 0200 %02d %8.0f       0       0 %7.0f %7.0f       0       0       0       0       0 000                           ",
		sPieceNum, side, 10000*length, 10*roofPitch, 10000*depth)
end

-- Hip ridge cut
-- function BvnFormatHipRidgeCut(sPieceNum, side, x, width, y, area)
-- 	return string.format(
-- 		"%s 0102 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 000                           ",
-- 		sPieceNum, side, 10000*x, 10000*width, 0, 0, 10000*y, area)
-- end


function BvnAddVCutUsingBirdsMouthAndLapJoint(sPieceNum, isBeg, nSide, x, y, bevelDegL, bevelDegR)
	
	local faceHeight=gnProfHeight
	local faceWidth=gnCurrWidth
	if nSide==1 or nSide==3 then
		faceWidth, faceHeight=faceHeight, faceWidth
	end

	nSide=(nSide+1)%4 
	if nSide==0 then nSide=1 end

	x=TernaryIf(isBeg, x, gnCurrTotLen-x)
	y=TernaryIf(isBeg, faceHeight/2-y, faceHeight/2+y)

	local birdsMouthAngle=nil
	local mirrorY=nil
	if math.abs(bevelDegL)<EPS then
		birdsMouthAngle=bevelDegR
		mirrorY=isBeg
	elseif math.abs(bevelDegR)<EPS then
		birdsMouthAngle=bevelDegL
		mirrorY=not isBeg
	else
		AddCncErr(0, "Birds mouth and lap joint should only be used if any bevel angle is ~= 0.0")
		return
	end	

	-- Anchor to opposite side
	if mirrorY then
		if nSide==1 then 
			nSide=3
		elseif nSide==3 then
			nSide=1
		elseif nSide==2 then
			nSide=4
		elseif nSide==4 then 
			nSide=2
		end
		y=faceHeight-y
	end

	local lapJointWidth=gnCurrTotLen-x
	local lapJoinSide=TernaryIf(isBeg, BvnGetLogEndBvnSide(nSide), BvnGetLogBegBvnSide(nSide))
	BvnAddLine( x, string.format( "%s 0302 %02d %8.0f       0       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 000                           ", 
										sPieceNum, lapJoinSide, 10000*x, 10000*lapJointWidth, 10000*y, 10000*y, 0.0) )

    -- Enough with a lap joint
	if birdsMouthAngle ~= 90.0 then
		local birdsMouthSide=TernaryIf(isBeg, BvnGetLogBegBvnSide(nSide), BvnGetLogEndBvnSide(nSide))
		BvnAddLine(x, BvnFormatBirdsMouthCut(sPieceNum, birdsMouthSide, BvnGetXc(x), birdsMouthAngle-90, y))
	end
end

function BvnAddVCutUsingDoubleDaboSawCuts(sPieceNum, isBeg, nSide, x, y, bevelDegL, bevelDegR)
	local faceHeight=gnProfHeight
	local faceWidth=gnCurrWidth
	if nSide==1 or nSide==3 then
		faceWidth, faceHeight=faceHeight, faceWidth
	end

	local sideDir=-1
	if bevelDegR<1.0 then
		y=faceHeight/2-y
		bevelDegR=90+bevelDegR
		bevelDegL=90-bevelDegL
		sideDir=1.0
	elseif bevelDegL<1.0 then
		y=faceHeight/2+y
		bevelDegR=90-bevelDegR
		bevelDegL=90+bevelDegL
	else
		AddCncErr(0, "Double dabo cuts should only be used if any bevel angle is < 1.0")
		return
	end


	if not isBeg then
		x=gnCurrTotLen-x
		bevelDegL=bevelDegL*-1
		bevelDegR=bevelDegR*-1
		sideDir=sideDir*-1
	end

	nSide=nSide+sideDir

	-- Ensure nSide is 1-4 (use modolu?)
	if nSide==0 then nSide=4 end
	if nSide==5 then nSide=1 end

	nSide, _=BvnGetSide(nSide)

	if BvnIsMirrorXc() then
		x=gnCurrTotLen-x
		bevelDegL=bevelDegL*-1
		bevelDegR=bevelDegR*-1
	end

	local sawLocationLeft=0
	local sawLocationRight=10
	if bevelDegR<bevelDegL then
		sawLocationLeft, sawLocationRight=sawLocationRight, sawLocationLeft
	end

	-- -- Dabo cuts does not support straight angles, use straight saw cuts for those cases
	-- if bevelDegL<-89.0 or bevelDegL>89.0 then
	-- 	local area=TernaryIf(bevelDegL>89.0, 10, 20)
	-- 	BvnAddLine(x, BvnFormatHipRidgeCut(sPieceNum, nSide, x, faceWidth, faceHeight-y, area))
	-- else
	-- 	BvnAddLine(x, BvnFormatDaboSawCut(sPieceNum, nSide, x, y, faceWidth, bevelDegL, sawLocationLeft))
	-- if bevelDegR<-89.0 or bevelDegR>89.0 then
	-- 	local area=TernaryIf(bevelDegR>89.0, 10, 20)
	-- 	BvnAddLine(x, BvnFormatHipRidgeCut(sPieceNum, nSide, x, faceWidth, faceHeight-y, area))
	-- else
	-- 	BvnAddLine(x, BvnFormatDaboSawCut(sPieceNum, nSide, x, y, faceWidth, bevelDegR, sawLocationRight))
	-- end

	BvnAddLine(x, BvnFormatDaboSawCut(sPieceNum, nSide, x, y, faceWidth, bevelDegL, sawLocationLeft))
	BvnAddLine(x, BvnFormatDaboSawCut(sPieceNum, nSide, x, y, faceWidth, bevelDegR, sawLocationRight))
end


function BvnAddBegEndVCut(	sPieceNum, isBeg, nSide, x, y, angleDegR, bevelDegR, angleDegL, bevelDegL )
	local nBvnSide, nPos, bMirrorY, height, b


	if isBeg then
		nPos=x
	else
		nPos=gnCurrTotLen-x
	end
	
	nSide=1+((nSide +1)%4)			-- To the other side
	nBvnSide,bMirrorY=BvnGetSide(nSide)
	if isBeg then
		nBvnSide = BvnGetLogBegBvnSide(nSide)
	else
		nBvnSide = BvnGetLogEndBvnSide(nSide)
	end

	if nSide==1 or nSide==3 then
		y=y+gnCurrWidth*0.5
	else
		y=y+gnProfHeight*0.5
	end

	--angleDegR=180-angleDegR
	--angleDegL=180-angleDegL
	b=bMirrorY
	if not isBeg then
		b=not b
	end
	if nSide==3 or nSide==4 then
		b=not b
	end
	if b then
		y=BvnMirrorYc(y, nSide)
	else
		angleDegR, angleDegL = angleDegL, angleDegR
		bevelDegR, bevelDegL = bevelDegL, bevelDegR
	end

	height=0

--000001 0103 03      880    1000       0    1700    1118     450    1118     900       0       0 000                           
	nPos = BvnGetXc(nPos)
	BvnAddLine( nPos, string.format(	"%s 0103 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7.0f       0       0 000                           ",
									sPieceNum, nBvnSide, 10000*nPos, 10000*y, 10000*height, 10*angleDegR, 10*bevelDegR, 10*angleDegL, 10*bevelDegL ) )
end



function BvnAddHiddenShoe( isBeg, sPieceNum, holeWidth, holeHeight, holeDepth, groDepth, groWidth, drillLowest, drillFromEnd, drillSize, drillSpacing, drillCount, side14, drillFromEnd2 )
	--Esim:
	--000931 0304 04        0       0     670    3050     620      50     900      10                 000                           
	--000931 0400 02      860    1325             130       0                                         000                           
	--000931 0400 02      860     925             130       0                                         000                           
	--000931 0400 02      860     525             130       0                                         000                           
	--000931 0800 01       30     670            1070    1575      80                                 000                           
	--
	local xc, yc, nWidth, bMirrorY, nBvnSide, xDrill, xDrill2, nDrill, xGro, nextSide, sideHeight, drillHeight
	local hasDrill2

	if side14==nil then
		-- Anchor added 12/2013
		side14=1
	end
	if side14<1 or side14>4 then
		side14=1
	end
	if drillFromEnd2==nil then
		drillFromEnd2=0
	end
	hasDrill2=false
	if drillFromEnd2>0.0001 then
		hasDrill2=true
	end

	xc=0
	xDrill=drillFromEnd
	xDrill2=drillFromEnd2
	xGro=0.003

	sideHeight=gnCurrWidth
	drillHeight=gnProfHeight
	if side14==2 or side14==4 then
		sideHeight=gnProfHeight
		drillHeight=gnCurrWidth
	end

	if not isBeg then
		-- At the left side/end in bvn-coordinates
		xc=gnCurrTotLen
		xDrill=gnCurrTotLen-drillFromEnd
		xDrill2=gnCurrTotLen-drillFromEnd2
		xGro=gnCurrTotLen-xGro
	end
	xc=BvnGetXc(xc)
	xDrill=BvnGetXc(xDrill)
	xDrill2=BvnGetXc(xDrill2)
	xGro=BvnGetXc(xGro)

	-- Päätyloveus
	--000931 0304 04        0       0     670    3050     620      50     900      10                 000                           

	nextSide=side14+1
	if nextSide>4 then
		nextSide=nextSide-4
	end
	if gnBvnLogDir==EBvnDirBeg then
		if isBeg then
			nBvnSide=BvnGetLogBegBvnSide(nextSide)
		else
			nBvnSide=BvnGetLogEndBvnSide(nextSide)
		end
	else
		nBvnSide=side14+3
		if nBvnSide>4 then
			nBvnSide=nBvnSide-4
		end
		if isBeg then
			nBvnSide=BvnGetLogBegBvnSide(nBvnSide)
		else
			nBvnSide=BvnGetLogEndBvnSide(nBvnSide)
		end
	end

	BvnAddLine( xc, string.format(	"%s 0304 %02d %8.0f       0 %7.0f %7.0f %7.0f %7.0f     900      10                 000                           ",
									sPieceNum, nBvnSide, 10000*xc, 10000*sideHeight*0.5, 10000*holeHeight*2, 10000*holeWidth, 10000*holeDepth ) )
									
	-- Poraukset
	nBvnSide,bMirrorY=BvnGetSide(nextSide)
	yc=drillLowest
	if nextSide==3 or nextSide==4 then
		bMirrorY=not bMirrorY
	end
--toLog(string.format("nBvnSide=%d,bMirrorY=%s", nBvnSide, tostring(bMirrorY)))
	if not bMirrorY then
		yc=drillHeight-yc
		drillSpacing=-drillSpacing
	end

	for nDrill=1,drillCount do
		BvnAddLine( xDrill, string.format(	"%s 0400 %02d %8.0f %7.0f         %7.0f       0                                         000                           ",
										sPieceNum, nBvnSide, 10000*xDrill, 10000*yc, 10000*drillSize ) )

		if hasDrill2 then
			BvnAddLine( xDrill2, string.format(	"%s 0400 %02d %8.0f %7.0f         %7.0f       0                                         000                           ",
											sPieceNum, nBvnSide, 10000*xDrill2, 10000*yc, 10000*drillSize ) )
		end
		yc=yc+drillSpacing
	end
	
	-- Ura
	-- 000931 0800 01       30     670            1070    1575      80                                 000                           

	if isBeg then
		nBvnSide=BvnGetLogBegBvnSide(side14)
	else
		nBvnSide=BvnGetLogEndBvnSide(side14)
	end

	BvnAddLine( xGro, string.format(	"%s 0800 %02d %8.0f %7.0f         %7.0f %7.0f %7.0f                                 000                           ",
									sPieceNum, nBvnSide, 10000*xGro, 10000*sideHeight*0.5, 10000*groDepth, 10000*holeHeight, 10000*groWidth ) )
end


-- Kun palkki menee kapuloiden läpi
function BvnAddBalkMid(sPieceNum, midPos, width, depthTop, depthBot, depthSides)
	--000007 0300 01    35440    1850       0    1120       0     100     100       0       0       0 000                           
	--000007 0300 03    35440    1850       0    1120       0     100     100       0       0       0 000                           
	--000007 0300 02    35440       0       0    1120       0      50      50       0       0       0 000                           
	--000007 0300 04    35440       0       0    1120       0     200     200       0       0       0 000                           
	local nSide, nBvnSide

	midPos=BvnGetXc(midPos)
	midPos=midPos-width*0.5
	
	-- Ylä
	if depthTop>0.0001 then
		nBvnSide=BvnGetSide(1)
		BvnAddLine( midPos, string.format(	"%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 000                           ",
										sPieceNum, nBvnSide, 10000*midPos, 10000*width, 10000*depthTop, 10000*depthTop ) )
	end

	-- Etu
	if depthSides>0.0001 then
		nBvnSide=BvnGetSide(2)
		BvnAddLine( midPos, string.format(	"%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 000                           ",
										sPieceNum, nBvnSide, 10000*midPos, 10000*width, 10000*depthSides, 10000*depthSides ) )
	end

	-- Ala
	if depthBot>0.0001 then
		nBvnSide=BvnGetSide(3)
		BvnAddLine( midPos, string.format(	"%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 000                           ",
										sPieceNum, nBvnSide, 10000*midPos, 10000*width, 10000*depthBot, 10000*depthBot ) )
	end

	-- Taka
	if depthSides>0.0001 then
		nBvnSide=BvnGetSide(4)
		BvnAddLine( midPos, string.format(	"%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 000                           ",
										sPieceNum, nBvnSide, 10000*midPos, 10000*width, 10000*depthSides, 10000*depthSides ) )
	end
end


-- rotAngleDeg may be nil
-- sRoundType	nil=default, value=mortise shape given
function BvnAddSideJoint( sPieceNum, logFace, bDove, midPos, borderBot, tenonLen, tenonWidth, tenonHeight, angleDove, roundingRadius, rotAngleDeg, housingDepth, sRoundType )

	local	nBvnSide, bMirrorY, xc, yc, y1, y2, s, minDist, ux, faceHeight, rotAngleDegOrg, a

	if rotAngleDeg==nil then
		rotAngleDeg=0
	end
	if housingDepth==nil then
		housingDepth=0
	end

	if logFace>4 then
		-- beg/end
		nBvnSide=9
		bMirrorY=false
		xc=midPos
	else
		-- Sivuun
		nBvnSide,bMirrorY=BvnGetSide(logFace)
		xc=BvnGetXc(midPos)
	end

	rotAngleDegOrg=rotAngleDeg
	if bMirrorY then
		rotAngleDeg=-rotAngleDeg
	end
	if gnBvnLogDir==EBvnDirEnd then
		rotAngleDeg=-rotAngleDeg
	end
	if math.abs(rotAngleDeg)<0.1 then
		rotAngleDeg=0
	end

	--AddCncErr( 0, string.format("mirrory=%s", tostring(bMirrorY)) )
	faceHeight=gnProfHeight
	if logFace==1 or logFace==3 then
		faceHeight=gnCurrWidth
	end

	local tenonHeightOrg=tenonHeight

	tenonHeight=math.abs(tenonHeight)		-- 2/2022: Negative to limit DT-pocket
	if bDove then
		-- Lohenpyrstötasku
		-- "000922 1703 03    16521       0       0      10     600     300      60       0       0     380 000                           "
		
		-- Eikun aina käännetään
		s=" 0"
		if bMirrorY then
			s="10"
		end

		if logFace>4 then
			-- After 1/2013 this is saved as EMcFrAngledBegTenonMort
			if math.abs(rotAngleDeg)>0.5 then
				AddCncErr( x, string.format("ERROR: ROTATED DOVETAIL TO BEG/END NOT SUPPORTED IN HUNDEGGER - SKIPPED (rot angle=%.3f) ***", rotAngleDeg) )
				return
			end

			-- beg/end
			if gnBvnLogDir==EBvnDirBeg then
				xc=gnCurrWidth-xc
			end
			--toLog( string.format("x1=%f y1=%f x2=%f y2=%f", x1, y1, x2, y2) )

			if logFace==5 then
				nBvnSide=BvnGetLogBegBvnSide(3)	
				ux=BvnGetXc(0)
			else
				nBvnSide=BvnGetLogEndBvnSide(3)
				ux=BvnGetXc(gnCurrTotLen)
			end
			
			-- Pre 1/2013 saved bottom gap to "Add depth" incorrectly
			--BvnAddLine( xc, string.format(	"%s 1704 %02d %8.0f %7.0f       0     900 %7.0f %7.0f %7.0f %7.0f       0 %7.0f 000                           ",
			--								sPieceNum, nBvnSide, 10000*ux, 10000*xc, 10000*tenonWidth, 10000*borderBot, 10*angleDove, 10000*bottomGap, 10000*tenonLen ) )
			BvnAddLine( xc, string.format(	"%s 1704 %02d %8.0f %7.0f       0     900 %7.0f %7.0f %7.0f       0       0 %7.0f 000                           ",
											sPieceNum, nBvnSide, 10000*ux, 10000*xc, 10000*tenonWidth, 10000*borderBot, 10*angleDove, 10000*tenonLen ) )
		else
			-- Pre 1/2013 put bottom gap to "Add depth" incorrectly
			--BvnAddLine( xc, string.format(	"%s 1703 %02d %8.0f       0       0      %s %7.0f %7.0f %7.0f %7.0f       0 %7.0f 000                           ",
			--								sPieceNum, nBvnSide, 10000*xc, s, 10000*tenonWidth, 10000*borderBot, 10*angleDove, 10000*bottomGap, 10000*tenonLen ) )

			-- 2/2022: Allow limiting DT pocket (before was always positive)
			if tenonHeightOrg>=0 then
				tenonHeight=0		-- Unlimited
			end

			if math.abs(rotAngleDeg)>180.01 then
				AddCncErr( x, string.format("ERROR: ROTATED DOVETAIL POCKET ANGLE OUT OF LIMITS (rot angle=%.3f), SKIPPED ***", rotAngleDeg) )
			else
				local	swapped


				swapped=false
				if rotAngleDeg<-90 then
					swapped=true
					rotAngleDeg=180+rotAngleDeg
				end

				if rotAngleDeg>90 then
					swapped=true
					rotAngleDeg=-(180-rotAngleDeg)
				end

				if swapped then
					if s=="10" then
						s=" 0"
					else
						s="10"
					end
					borderBot=faceHeight-borderBot
				end
				
				if math.abs(rotAngleDeg)<0.05 then
					rotAngleDeg=0
				end
				if housingDepth>0 and rotAngleDeg==0 then
					-- Added 12/2020: Use different code for housed DT-mortise
					local rabbetShoulder=0
					local seatDepth=0
					local housingWidth=0
					local dummy, mirrory

					dummy,mirrory=BvnGetSide(logFace)
--toLog(string.format("mirrory=%s", tostring(mirrory)))
					if not mirrory then
						nBvnSide=-nBvnSide
					end
					BvnAddLine( xc, string.format(	"%s 1723 %02d %8.0f       0 %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f 000                           ",
													sPieceNum, nBvnSide, 10000*xc, 10000*rabbetShoulder, 10000*seatDepth, 10000*tenonWidth, 10000*borderBot, 10*angleDove, 10000*housingDepth, 10000*housingWidth, 10000*tenonLen) )

				else
					BvnAddLine( xc, string.format(	"%s 1702 %02d %8.0f %7.0f       0      %s %7.0f %7.0f %7.0f %7.0f %7.0f %7.0f 000                           ",
													sPieceNum, nBvnSide, 10000*xc, 10000*borderBot, s, 10000*tenonWidth, 10000*tenonHeight, 10*angleDove, 10000*housingDepth, 10*rotAngleDeg, 10000*tenonLen ) )
				end
			end
		end
		return
	end

	tenonLen=tenonLen+housingDepth
	
	-- Ensimmäinen tapaus: Suora työstö koko hirteen (kantikas tasku)
	if borderBot<0.001 and borderBot+tenonHeight>faceHeight-0.001 and roundingRadius<0.001 and rotAngleDeg==0 then
		if logFace>4 then
			-- Läpiura hirren päähän
			--BvnAddGro(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen)
			BvnAddGro(sPieceNum, midPos+tenonWidth*0.5, 0, midPos+tenonWidth*0.5, faceHeight, tenonLen, tenonWidth, 0, logFace, 0)
		else
			BvnAddLine( xc, string.format(	"%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 000                           ",
											sPieceNum, nBvnSide, 10000*(xc-tenonWidth*0.5), 10000*tenonWidth, 10000*tenonLen, 10000*tenonLen ) )
		end
		return
	end

	if roundingRadius<0.001 then
		AddCncErr( midPos, "BVN WARNING: SQUARE JOINT MADE ROUND ***" )
	end

	-- Tappiliitos
	-- Ovaali: "000903 0503 03    16521    1855       0    1710     690    1180    1800       0       0       0 000                           "
	-- Pyör:   "000903 0503 03    16521    1855       0    1710     690    1180    1800     -10       0       0 000                           "
	
	-- Eikun tällä loveus käännetyllä saadaan vain lievästi pyöristetyt kulmat:
	-- Tuossa samaan paikaan osuva tappitasikulla 0503 ja loveus käännetty:
	-- "000013 0503 02     9600    1935       0    1460     680    1050    1800     -10       0       0 000                           "
	-- "000013 0305 02     9075    1205       0    1460    1050     680       0      10      10     900 000                           "

	if rotAngleDeg==0 and not sRoundType then
		-- Optimize oversized tenon (only if not takås joint)
		y1=borderBot
		y2=y1+tenonHeight
		
		-- Tähän optimointi: Vedetään max 40 mm ohi puusta
		minDist=0.040
		if not gbK2Tenon then
			-- Pyöreä työstö, pitää mennä vähintää leveyden puolikkaan yli
			minDist=tenonWidth*0.5 + 0.010

			if minDist<0.040 then
				minDist=0.040
			end
		end
		
		if logFace>4 and minDist<0.08 then
			-- Päässä piti mennä enemmän ohi
			minDist=0.080
		end
		
		if y1<-minDist then
			y1=-minDist
			-- K1 0503 tenon len must be >= width
			if not gbK2Tenon and y2-y1<tenonWidth+0.001 then
				y1=y2-tenonWidth-0.001
			end
		end
		if y2>faceHeight+minDist then
			y2=faceHeight+minDist
			if not gbK2Tenon and y2-y1<tenonWidth+0.001 then
				y2=y1+tenonWidth+0.001
			end
		end

		borderBot	=y1
		tenonHeight	=y2-y1
	end

	if not sRoundType then
		-- Shape
		sRoundType="  0"		-- Ovaali
		if gbK2Tenon then
			if roundingRadius<0.023 then
				sRoundType="-10"	-- Rounded
			else
				sRoundType=string.format("%7.0f", 10000*roundingRadius)		-- 9/2020: Added rounding radius to Hundegger
			end
		end
		if roundingRadius<EPS then
			sRoundType=" 10"	-- Square
		end
	end
	
	if logFace>4 then
		-- Alkuun/loppuun
		if math.abs(rotAngleDeg)>0.5 then
			AddCncErr( x, string.format("ERROR: OLD MORTISE END ROTATION NOT SUPPORTED - SKIPPED (rot angle=%.3f) ***", rotAngleDeg) )
			return
		end

		if gnBvnLogDir==EBvnDirBeg then
			xc=gnCurrWidth-xc
		end
		--toLog( string.format("x1=%f y1=%f x2=%f y2=%f", x1, y1, x2, y2) )

		if logFace==5 then
			nBvnSide=BvnGetLogBegBvnSide(3)	
			ux=BvnGetXc(0)
		else
			nBvnSide=BvnGetLogEndBvnSide(3)
			ux=BvnGetXc(gnCurrTotLen)
		end

		BvnAddLine( xc, string.format(	"%s 0504 %02d %8.0f %7.0f       0     900 %7.0f %7.0f %7.0f %7s %7.0f       0 000                           ",
									sPieceNum, nBvnSide, 10000*ux, 10000*xc, 10000*tenonWidth, 10000*tenonLen, 10000*borderBot, sRoundType, 10000*tenonHeight ) )

	else
		-- Calc mid pos in original coordinate system (positive rot angle always ccw)
		a=rotAngleDegOrg*PI/180.0+PI2
		xc=midPos    + tenonHeight*0.5*math.cos(a)
		yc=borderBot + tenonHeight*0.5*math.sin(a)
		xc=BvnGetXc(xc)

		if bMirrorY then
			yc=faceHeight-yc
		end

		BvnAddLine( xc, string.format(	"%s 0503 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f %7s       0       0 000                           ",
										sPieceNum, nBvnSide, 10000*xc, 10000*yc, 10000*tenonHeight, 10000*tenonLen, 10000*tenonWidth, 10*rotAngleDeg, sRoundType ) )
	end

	-- Tässä kone valittaa korkeussuunnassa liian suuresta:
--	BvnAddLine( xc, string.format(	"%s 0502 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f             %s       0       0 000                           ",
--									sPieceNum, nBvnSide, 10000*(xc-tenonWidth*0.5), 10000*(y1 + y2)*0.5, 10000*tenonWidth, 10000*tenonLen, 10000*(y2-y1), sRound ) )

end



-- Adds window groove
-- groStart			Start coordinate of the groove (ends to the opening)
-- groOtherSideOff	Value to add to previous to get to other side
function BvnAddBuckGro( sPieceNum, nBvnSide, groStart, groOtherSideOff, buckWidth, buckDepth, openingDepth )
	local x1, x2
	
	-- Now forget about groOtherSideOff - just calc x1,x2
	if groOtherSideOff<0 then
		x1=groStart+groOtherSideOff
		x2=groStart+0.020					-- Oversize to get rid of roundings
	else
		x1=groStart-0.020
		x2=groStart+groOtherSideOff
	end

	-- 000001 0800 04     4220    1040       0    1640       0      80       0       0       0       0 000                           
	--BvnAddLine( x1, string.format( "%s 0800 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f       0       0       0       0 000                           ",
	--						   sPieceNum, nBvnSide, 10000*x1, 10000*gnCurrWidth*0.5, 10000*buckDepth, 10000*openingDepth, 10000*buckWidth) )

	-- 000015 0305 04    67680    1550       0     400     500     725    1800      10      10     900 000                           
	BvnAddLine( x1, string.format( "%s 0305 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f    1800      10      10     900 000                           ",
							   sPieceNum, nBvnSide, 10000*x2, 10000*(gnCurrWidth+buckWidth)*0.5, 10000*buckWidth, 10000*(x2-x1), 10000*openingDepth) )
end



-- logFace	1=top, 3=bottom
-- nDepth	Depth from that face
-- x1,x2	In bvn-coordinates
-- bUseCutter	true=add cutter machinings to both sides, false=nope, just sawing
function BvnAddOpening( sPieceNum, logFace, nDepth, x1, x2, bUseCutter )
	local sawLen, groLen, groFace, sawFace, mirrorSawY, nSplinter, xBeg, xEnd, a, yOrg, nLeftRight, nLeftRightOrg
	local groBeg, groEnd

	if x1<0.001 then
		x1=0
	end
	if x2>gnCurrTotLen-0.001 then
		x2=gnCurrTotLen
	end

	if x1<0.001 and x2>gnCurrTotLen-0.001 then
		-- Whole piece is cut
		sawFace=BvnGetSide(logFace)
		BvnAddLine( gnCurrTotLen+100, string.format(	"%s 0102 %02d        0 %7.0f       0       0       0 %7.0f       0       0       0       0 000                           ", 
										sPieceNum, sawFace, 5000*gnCurrWidth, 10000*(gnProfHeight-nDepth)) )
		return
	end

	-- Ei koko hirren mittainen, jyrsitään
	-- "000001 1500 01    13000     910       0    8000     200    1820      10       0       0       0 000                           "
	--nInOut=0		-- 0=inside, 10=outside
	--BvnAddLine( x1, string.format( "%s 1500 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 000                           ", 
	--							sPieceNum, groFace, 10000*x1, 5000*gnCurrWidth, 10000*(x2-x1), 10000*nDepth, 10000*gnCurrWidth, nInOut ) )

	groFace=BvnGetSide(logFace)

	-- 100 is splinter free, 0=not
	nSplinter=100
	
	-- Cutter length depends on the plank thickness
	a=math.asin((gnBvnSawR-gnBvnSawMaxDepth)/gnBvnSawR)
	xBeg=math.cos(a)*gnBvnSawR
	xEnd=0

	if gnCurrWidth<gnBvnSawMaxDepth then
		a=math.asin((gnBvnSawR-gnBvnSawMaxDepth+gnCurrWidth)/gnBvnSawR)
		xEnd=math.cos(a)*gnBvnSawR
	end
	
	groLen=xBeg-xEnd+0.050				-- 5 cm extra
	
	-- Don't add groove if at the end of the log
	groBeg=1
	groEnd=1
	
	if x1<0.001 then
		groBeg=0
	end
	if x2>gnCurrTotLen-0.001 then
		groEnd=0
	end

	if bUseCutter==false or x2-x1>(groBeg+groEnd)*groLen then
		-- Sawing to the middle (speed-up)

		if logFace==1 then
			y=gnProfHeight-nDepth
			nLeftRight=0
		else
			y=nDepth
			nLeftRight=10
		end

		yOrg=y
		nLeftRightOrg=nLeftRight
		sawFace,mirrorSawY=BvnGetSide(2)		-- To log's front side
		if mirrorSawY then
			y=gnProfHeight-y
			if nLeftRight==10 then
				nLeftRight=0
			else
				nLeftRight=10
			end
		end

		BvnAddLine( x1, string.format( "%s 0109 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f       0      10 %7.0f       0 000                           ",
										sPieceNum, sawFace, 10000*(x1-(1-groBeg)*groLen), 10000*y, 10000*(x2+(1-groEnd)*groLen), 10000*y, 10000*gnBvnSawMaxDepth, nLeftRight) )

		if gnCurrWidth>gnBvnSawMaxDepth then
			-- Double groove (hope that gnCurrWidth<2*gnBvnSawMaxDepth)
			y=yOrg
			nLeftRight=nLeftRightOrg
			sawFace,mirrorSawY=BvnGetSide(4)		-- To log's back side
			if mirrorSawY then
				y=gnProfHeight-y
				if nLeftRight==10 then
					nLeftRight=0
				else
					nLeftRight=10
				end
			end

			BvnAddLine( x1, string.format( "%s 0109 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f       0      10 %7.0f       0 000                           ",
											sPieceNum, sawFace, 10000*(x1-(1-groBeg)*groLen), 10000*y, 10000*(x2+(1-groEnd)*groLen), 10000*y, 10000*gnBvnSawMaxDepth, nLeftRight) )
		end

		if groLen>0 and bUseCutter then
			-- Gro beg
			if groBeg==1 then
				BvnAddLine( x1, string.format( "%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 %3.0f                           ", 
											sPieceNum, groFace, 10000*x1, 10000*groLen, 10000*nDepth, 10000*nDepth, nSplinter) )
			end

			-- Gro end
			if groEnd==1 then
				BvnAddLine( x1, string.format( "%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 %3.0f                           ", 
											sPieceNum, groFace, 10000*(x2-groLen), 10000*groLen, 10000*nDepth, 10000*nDepth, nSplinter) )
			end
		end
	elseif groLen>0 then
		-- Single groove
		BvnAddLine( x1, string.format( "%s 0300 %02d %8.0f       0       0 %7.0f       0 %7.0f %7.0f       0       0       0 %3.0f                           ", 
									sPieceNum, groFace, 10000*x1, 10000*(x2-x1), 10000*nDepth, 10000*nDepth, nSplinter) )
	end

	if bUseCutter and groLen>0 and nDepth>gnProfHeight*0.75 then
		AddCncErr( orgX1, "WARNING, OPENING CUTS MORE THAN 75% OF THE LOG. SAVED TO BVN FILE." )
	end
end


-- xStart	Start coord in plank coordinates
-- dWidth	Width
-- dDepthTop	A Distance from surface to the cross pt (pos=inside plank, neg=outside)
-- dYoffTop		B Distance from surface middle to the cross pt in surface y-coordinate direction
-- dAngleY2Deg	C angle at surface y2
-- dAngleY1Deg	D angle at surface y1
function BvnAddSaw( sPieceNum, logFace, xStart, dWidth, dDepthTop, dYoffTop, dAngleY2Deg, dAngleY1Deg )
	local nBvnSide, bMirrorY, x1Real, x2Real, temp
	local nLen, nArea, nSplinter, dzNow, dyFace, dyFace2, nSingleCut, yc


	if logFace>4 then
		AddCncErr( xStart, string.format("BvnAddSaw, BAD FACE: %d. MACHINING SKIPPED", logFace) )
		return
	end

	nBvnSide,bMirrorY=BvnGetSide(logFace)
	nSplinter=100

	-- Miten osuu puuhun
	x1Real=BvnGetXc(xStart)
	if dWidth==0 then
		x2Real=BvnGetXc(gnCurrTotLen)
	else
		x2Real=BvnGetXc(xStart+dWidth)
	end
	
	if x1Real>x2Real then
		x1Real,x2Real = x2Real,x1Real
	end
	
	dyFace=gnProfHeight
	dzNow=gnCurrWidth
	if logFace==1 or logFace==3 then
		dyFace=gnCurrWidth
		dzNow=gnProfHeight
	end

	dyFace2=dyFace*0.5
	nSingleCut=0
	if dYoffTop<-dyFace2+0.001 then
		-- Single cut only
		dAngleY1Deg=0
		nSingleCut=2
	elseif dYoffTop>dyFace2-0.001 then
		dAngleY2Deg=0
		nSingleCut=1
	end

	-- Tarkistetaan x-koordinaatit
	yc=dYoffTop+dyFace2
	if bMirrorY then
		yc=dyFace-yc
		dAngleY1Deg,dAngleY2Deg = dAngleY2Deg,dAngleY1Deg
		if nSingleCut==1 then
			nSingleCut=2
		elseif nSingleCut==2 then
			nSingleCut=1
		end
	end

	nLen=0
	if x1Real<0.001 and x2Real>gnCurrTotLen-0.001 then
		nArea=0		-- Kaikki
	elseif x1Real<0.001 then
		nArea=10	-- To len
		nLen=x2Real
	elseif x2Real>gnCurrTotLen-0.001 then
		nArea=20	-- From len
		nLen=x1Real
	else
		-- Use cutter
		local	d1, d2, nTan

		if dAngleY1Deg+dAngleY2Deg<-0.1 then
			AddCncErr( xStart, string.format("BvnAddSaw, VALLEY CUT AT MIDDLE OF THE PLANK - CANNOT DO WITH CUTTER. MACHINING SKIPPED") )
			return
		end

		if nSingleCut~=2 then
			-- Cut y1
			nTan=math.tan(dAngleY1Deg*PI/180)
			d1=dDepthTop+yc*nTan
			d2=d1-dyFace*nTan

			BvnAddLine( x1Real, string.format( "%s 0302 %02d %8.0f       0       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 %3.0f                           ", 
										sPieceNum, nBvnSide, 10000*x1Real, 10000*(x2Real-x1Real), 10000*d1, 10000*d2, -10*dAngleY1Deg, nSplinter) )
		end

		if nSingleCut~=1 then
			-- Cut y2
			nTan=math.tan(dAngleY2Deg*PI/180)
			d1=dDepthTop-yc*nTan
			d2=d1+dyFace*nTan

			BvnAddLine( x1Real, string.format( "%s 0302 %02d %8.0f       0       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 %3.0f                           ", 
										sPieceNum, nBvnSide, 10000*x1Real, 10000*(x2Real-x1Real), 10000*d1, 10000*d2, 10*dAngleY2Deg, nSplinter) )
		end

		nArea=-1
	end

	if nArea~=-1 then
		local sortPos

		sortPos=x1Real
		if nArea==0 then
			sortPos=gnSortPosLast
		end
		if nSingleCut~=0 or dAngleY1Deg+dAngleY2Deg>-0.1 then
			-- Hip ridge cut or single
			BvnAddLine( sortPos, string.format( "%s 0102 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 000                           ",
											sPieceNum, nBvnSide, 10000*nLen, 10000*yc, 10*dAngleY1Deg, 10*dAngleY2Deg, 10000*(dzNow-dDepthTop), nArea) )
		else
			-- Valley cut
			BvnAddLine( sortPos, string.format( "%s 0102 %02d %8.0f %7.0f       0 %7.0f %7.0f %7.0f %7.0f       0       0       0 000                           ",
											sPieceNum, nBvnSide, 10000*nLen, 10000*yc, 10*dAngleY1Deg, 10*dAngleY2Deg, 10000*(dzNow-dDepthTop), nArea) )
		end
	
	end
end



function BvnMarkReinforcement( sPieceNum, groFace, xMid, yMid, dx, dy, xPosText, yPosText, fontSize, textOff, s )
	local	xOff, bDone, x
	
	if gbBvnAddMarkLine==false then
		return
	end

	-- NO TEXT IN BVN: BvnAddMarking(sPieceNum, groFace, xMid, yMid-0.01, xMid, yMid+0.01, xPosText, yPosText, fontSize, textOff, s, false)

	-- Beg line
	x=xMid-dx*0.5
	if x>0.001 then		
	BvnAddMarking(sPieceNum, groFace, x, 0, x, 1, 2, 2, 0, 0, "", true)
	end

	-- End	
	x=xMid+dx*0.5
	if x<gnCurrTotLen-0.001 then
		BvnAddMarking(sPieceNum, groFace, x, 0, x, 1, 2, 2, 0, 0, "", true)
	end
end


-- Write iMc and iMcStr with current global plank offsets
-- ac_objectopen() must have been called for current plank
-- begExtra	For log object: How much to add to the mc x-coordinates
-- Sets globals gbBegCut and gbEndCut to true if there is no need to add straight cut (beg=plank's beg, may be swapped to bvn)
function BvnWriteMcTbl( begExtra )
	local	s, n, i, nOther, x, nDepth, x1, x2, nWidth, sBin, y, z, sPart, b
	local	bBegJoint, bEndJoint, nLeftRight
	local	nBvnSide, bMirrorY
	local	nSplinter
	local	nAngleSide, nStraightSide, nAngleTop, nStraightTop
	local	nSide, sSide, nSortPos, begCuts, endCuts


	gbBegCut=false
	gbEndCut=false
	begCuts=0
	endCuts=0

	if ac_objectget("#mirroring")==1 then
		AddCncErr( 0, "MIRRORED OBJECT NOT SUPPORTED - SKIPPED" )
		return
	end

	n=ac_objectget("iMc" ,-1)
	if n==nil then
		return
	end

	for i=1,n do
		nType=NormalizeType(ac_objectget("iMc", i, 1))

		if nType==EMcFrAngledBegOld then
			nAngleTop=ac_objectget("iMc", i, 2)*PI/180
			nAngleSide=ac_objectget("iMc", i, 3)*PI/180
			nStraightTop=ac_objectget("iMc", i, 4)
			nStraightSide=ac_objectget("iMc", i, 5)
			
			-- Konversio hirren tyyliin
			if nAngleSide<0 then
				nAngleSide=PI/2+nAngleSide
			else
				nAngleSide=-PI/2+nAngleSide
			end

			-- Päältä vain konversio hundegger-tyyliin
			if nAngleTop<0 then
				nAngleTop=-PI/2-nAngleTop
			else
				nAngleTop=PI/2-nAngleTop
			end
			BvnAddBegAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop )

		elseif nType==EMcFrAngledBeg or nType==EMcFrAngledEnd then
			local isBeg, tPars, tRes

			isBeg=(nType==EMcFrAngledBeg)
			nAngleTop=ac_objectget("iMc", i, 2)*PI/180
			nAngleSide=ac_objectget("iMc", i, 3)*PI/180		-- Bevel
			x=ac_objectget("iMc", i, 4)
			y=ac_objectget("iMc", i, 5)
			z=ac_objectget("iMc", i, 6)
			BvnAddBegEndAngled( sPieceNum, nAngleTop, nAngleSide, x, y, z, isBeg )

			tPars={}
			tPars.guid=gsCurrentLogGuid
			tPars.mcindex=i
			tRes=af_request("mc_getcutinfo", tPars)
			if tRes~=nil then
				if tRes.fullcut==1 then
					if isBeg then
						gbBegCut=true
					else
						gbEndCut=true
					end
				end
			end

			if isBeg then
				-- Fail-safe...
				begCuts=begCuts+1
				if begCuts>1 then
					gbBegCut=false
				end
			else
				endCuts=endCuts+1
				if endCuts>1 then
					gbEndCut=false
				end
			end

		elseif nType==EMcFrAngledBegTenon or nType==EMcFrAngledEndTenon then
			--! iMc[mindex][2], uihelp_length1: tapin pituus
			--! iMc[mindex][3], uihelp_length2: reunus ylä
			--! iMc[mindex][4], uihelp_length3: reunus ala
			--! iMc[mindex][5], uihelp_length4: tappi: reunus sivut, lohari: tapin leveys
			--! iMc[mindex][6], uihelp_length5: pyöristyssäde
			--! iMc[mindex][7], uihelp_angle1: kulma päältä
			--! iMc[mindex][8], uihelp_angle2: kallistuskulma
			--! iMc[mindex][9], uihelp_str3: Liitoksen tyyppi 1=Tappi, 2=Lohari
			--! iMc[mindex][10], uihelp_length6: Pohjavälys
			--! iMc[mindex][11], uihelp_length7: Sivuvälys
			--! iMc[mindex][12], uihelp_angle3: (Lohenpyrstön) tapin kulma laajenus alhaalta ylös
			
			bDove=false
			if ac_objectget("iMc", i, 9)==2 then
				bDove=true
			end

			tenonLen=ac_objectget("iMc", i, 2)
			tenonWidth=ac_objectget("iMc", i, 5)
			borderBot=ac_objectget("iMc", i, 4)
			tenonHeight=gnCurrHeight-ac_objectget("iMc", i, 3)-borderBot
			if not bDove then
				tenonWidth=gnCurrWidth-2*tenonWidth
			else
				-- If dovetail goes to top, set height to zero (empty=full dove male)
				if borderBot+tenonHeight+0.001>gnCurrHeight then
					tenonHeight=0
				end
			end

			nAngleTopDeg=ac_objectget("iMc", i, 7)
			nAngleSideDeg=ac_objectget("iMc", i, 8)
			
			-- Päältä vain konversio hundegger-tyyliin
--			if nAngleTopDeg<0 then
--				nAngleTopDeg=-90-nAngleTopDeg
--			else
--				nAngleTopDeg=90-nAngleTopDeg
--			end

			-- 3=alapuoli
			if nType==EMcFrAngledEndTenon then
				nBvnSide=BvnGetLogEndBvnSide(3)
				nAngleSideDeg=-nAngleSideDeg
				nAngleTopDeg=-nAngleTopDeg
			else
				nBvnSide=BvnGetLogBegBvnSide(3)
			end

			BvnAddBegEndTenon( sPieceNum, nBvnSide, bDove, tenonLen, tenonWidth, tenonHeight, borderBot, nAngleSideDeg, nAngleTopDeg, ac_objectget("iMc", i, 6), ac_objectget("iMc", i, 12) )
			
		elseif nType==EMcFrAngledBegTenonMort or nType==EMcFrAngledEndTenonMort then
			--// As angled cut: coordinate of the reference point
			--// For female, this is to surface and for male this is to the start of the tenon (lower mid)
			--double		dAngleDeg;			// [2] Angle as in saw cut, 90 deg=straight cut. Note: Hundegger has swapped angle and bevel from compared to sawing.
			--double		dBevelDeg;			// [3] Blade as in saw cut, 90 deg=straight cut
			--double		dX;					// [4] Plane's origin point on the anchor side. In plank coordinates instead of cut plane (as in operation)
			--double		dY;					// [5] Orientation at base/bottom surface: y positive moves left looked from plank beg
			--double		dZ;					// [6]
			--
			--// Tenon/mortise params
			--double		dAnchorSide;		// [7] 1...4 to be origin of the coordinate system (first angle, then bevel)
			--double		dJointType;			// [8] ETypeXXX: 1=tenon, 2=dt, 3=mortise, 4=dt-pocket, 5=Honka dove, 6=Honka mortise
			--double		dRotAngleDeg;		// [9] Tenon rotate angle from the ref point looking at tenon's dir: positive ccw
			--
			--double		dLen;				// [10] Tenon or mortise depth
			--double		dWidth;				// [11] Its width
			--double		dHeight;			// [12] And height
			--double		dRoundingRadius;	// [13] Työkalun pyöristyssäde. 0=Ei ole pyöristetty
			--double		dAngleTenonDeg;		// [14] Ainakin lohenpyrstössä on alareuna usein kapeampi kuin yläreuna
			local	isBeg, nSide, nEndType, nRotAngleDeg, roundingRadius, nAngleTenonDeg, housing, xErr


			nAngleTopDeg=ac_objectget("iMc", i, 2)
			nAngleSideDeg=ac_objectget("iMc", i, 3)		-- bevel
			x			=ac_objectget("iMc", i, 4)
			y			=ac_objectget("iMc", i, 5)
			z			=ac_objectget("iMc", i, 6)
			
			nSide		=ac_objectget("iMc", i, 7)
			nEndType	=ac_objectget("iMc", i, 8)
			nRotAngleDeg=ac_objectget("iMc", i, 9)

			tenonLen	=ac_objectget("iMc", i, 10)
			tenonWidth	=ac_objectget("iMc", i, 11)
			tenonHeight	=ac_objectget("iMc", i, 12)
			roundingRadius	=ac_objectget("iMc", i, 13)
			nAngleTenonDeg	=ac_objectget("iMc", i, 14)

			gMortHousing=0		-- Use global since there are so many functions in between
			s=FindKeyVal(ac_objectget("iMcStr", i, 1), "housing")
			if s then
				gMortHousing=tonumber(s)
			end

			b=false
			if math.abs(nAngleTopDeg-90)<0.1 and math.abs(nAngleSideDeg-90)<0.1 then
				b=true
			end

			if nType==EMcFrAngledBegTenonMort then
				if b then
					gbBegCut=true
				end
				isBeg=true
				xErr=0
			else
				if b then
					gbEndCut=true
				end
				isBeg=false
				xErr=gnCurrTotLen
			end

			if nAngleTenonDeg<0 then
				-- 11/2021: It is straight DT having roundings at top and bottom
				BvnAddBegEndTenonMortNew(	sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, x, y, z, nSide, nEndType, nRotAngleDeg, 
											tenonLen, tenonWidth, 0, roundingRadius, 0 )		-- tenonHeight 0 here

				if math.abs(nRotAngleDeg)>0.1 then
					AddCncErr( xErr, string.format("ERROR: ROTATED DT WITH DOUBLE ROUNDING NOT SUPPORTED, WRITTEN AS STRAIGHT") )					
				end
				if math.abs(nAngleTopDeg-90)>0.1 or math.abs(nAngleSideDeg-90)>0.1 then
					AddCncErr( xErr, string.format("ERROR: ANGLED DT WITH DOUBLE ROUNDING NOT SUPPORTED, SKIPPING WRITING THE OTHER END") )
				else
					-- Anchor to opposite side
					nSide=nSide+2
					if nSide>4 then
						nSide=nSide-4
					end

					-- Adjust coordinates
					local dy

					dy=gnCurrHeight
					if nSide==2 or nSide==4 then
						dy=gnCurrWidth
					end
					y=-y
					z=dy-(z+tenonHeight)
					BvnAddBegEndTenonMortNew(	sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, x, y, z, nSide, nEndType, 0, 
												tenonLen, tenonWidth, 0, roundingRadius, 0 )		-- tenonHeight 0 here
				end
			else
				BvnAddBegEndTenonMortNew(	sPieceNum, isBeg, nAngleTopDeg, nAngleSideDeg, x, y, z, nSide, nEndType, nRotAngleDeg, 
											tenonLen, tenonWidth, tenonHeight, roundingRadius, nAngleTenonDeg )
			end

		elseif nType==EMcJointBeg or nType==EMcJointEnd then
			--double		dType;					// 1, EMcJointBeg/EMcJointEnd
			--double		dSideOneBased;			// 2, 1-4
			--double		dX;						// 3, distance from end to furthest point (usually zero)
			--double		dLen;					// 4, A: Length of angled part
			--double		dStraightHeight;		// 5, B
			--double		dDrillDia;				// 6, In meters (UNUSED)
			--double		dDrillCount;			// 7 (UNUSED)
			--double		dFlags;					// 8, bit0 & bit1 & bit2 = type 0...7: 0=Angled scarf, 1=toothed
			--double		dDrillDist;				// 9, distance of closest drillings at middle from each other, 0=space evenly (UNUSED)
			
			local	isBeg, nSide, len, straight, jointType


			if nType==EMcJointBeg then
				gbBegCut=true
				isBeg=true
			else
				gbEndCut=true
				isBeg=false
			end

			nSide		=ac_objectget("iMc", i, 2)
			x			=ac_objectget("iMc", i, 3)
			len			=ac_objectget("iMc", i, 4)
			straight	=ac_objectget("iMc", i, 5)
			jointType	=ac_objectget("iMc", i, 8) % 8
			
			BvnAddBegEndJoint(	sPieceNum, isBeg, x, nSide, len, straight, jointType )

		elseif nType==EMcVCutBeg or nType==EMcVCutEnd then
			--double		dType;					// 1, EMcVCutBeg/EMcVCutEnd
			--double		dSideOneBased;			// 2, 1-4
			--double		dX;						// 3, distance from end to furthest point (usually zero)
			--double		dY;						// 4, Y-coordinate for the face from face mid line. pos to right in watching dir, neg to left
			--double		dAngleDegR;				// 5, angle at right side of the ref side
			--double		dBevelDegR;				// 6
			--double		dAngleDegL;				// 7, Left side
			--double		dBevelDegL;				// 8
			--
			--// GDL generation set by AF
			--double		dDirX;					// 9, mid line vector relative to the plank x 
			--double		dDirY;					// 10
			--double		dDirZ;					// 11
			--double		dCutAngleDegR;			// 12 Rotation for the cut, 0=no cut, 179=max
			--double		dCutAngleDegL;			// 13
			--
			local	isBeg, nSide, angleDegR, bevelDegR, angleDegL, bevelDegL


			if nType==EMcVCutBeg then
				--gbBegCut=true
				isBeg=true
			else
				--gbEndCut=true
				isBeg=false
			end

			nSide		=ac_objectget("iMc", i, 2)
			x			=ac_objectget("iMc", i, 3)
			y			=ac_objectget("iMc", i, 4)
			angleDegR	=ac_objectget("iMc", i, 5)
			bevelDegR	=ac_objectget("iMc", i, 6)
			angleDegL	=ac_objectget("iMc", i, 7)
			bevelDegL	=ac_objectget("iMc", i, 8)

			-- V-Cut does not work with straight (0 degree) and negative angles, try to simulate a V-Cut with other machinings in those cases
			if bevelDegL<0.0 or bevelDegR<0.0 then
				BvnAddVCutUsingDoubleDaboSawCuts(sPieceNum, isBeg, nSide, x, y, bevelDegL, bevelDegR)
            else
                local zeroAngle=nil
                local otherAngle=nil
                if math.abs(bevelDegL)<EPS then
                    zeroAngle=bevelDegL
                    otherAngle=bevelDegR
                elseif math.abs(bevelDegR)<EPS then
                    zeroAngle=bevelDegR
                    otherAngle=bevelDegL
                end

                -- No angle is zero (and no angle is negative), OK to add regular V-Cut
                if zeroAngle==nil then
                    BvnAddBegEndVCut(	sPieceNum, isBeg, nSide, x, y, angleDegR, bevelDegR, angleDegL, bevelDegL )
                else
                    if math.abs(otherAngle)<90.0 then
                        AddCncErr(0, string.format("ERROR: Cannot machine V-Cut if one angle is 0.0 and one angle is < 90.0"))
                    else
                        BvnAddVCutUsingBirdsMouthAndLapJoint(sPieceNum, isBeg, nSide, x, y, bevelDegL, bevelDegR)
                    end
                end
            end
			
		elseif nType==EMcFrBegHiddenShoe or nType==EMcFrEndHiddenShoe then
			--! iMc[mindex][2], uihelp_length1: kolouksen leveys
			--! iMc[mindex][3], uihelp_length2: kolouksen korkeus
			--! iMc[mindex][4], uihelp_length3: kolouksen syvyys
			--! iMc[mindex][5], uihelp_length4: uran syvyys (ura on yhtä korkea kuin kolous)
			--! iMc[mindex][6], uihelp_length5: uran leveys
			--! iMc[mindex][7], uihelp_length6: alin poraus yKeski
			--! iMc[mindex][8], uihelp_length7: porausten etäisyys päästä (keskipiste)
			--! iMc[mindex][9], uihelp_length8: poran halkaisija
			--! iMc[mindex][10], uihelp_length9: porien välistys pystysuunnassa
			--! iMc[mindex][11], uihelp_count1: porausten lukumäärä
			
			local	isBeg, holeWidth, holeHeight, holeDepth, groDepth, groWidth, drillLowest, drillFromEnd, drillSize, drillSpacing, drillCount, drillFromEnd2

			isBeg=true
			if nType==EMcFrEndHiddenShoe then
				isBeg=false
			end
			holeWidth	=ac_objectget("iMc", i, 2)
			holeHeight	=ac_objectget("iMc", i, 3)
			holeDepth	=ac_objectget("iMc", i, 4)
			groDepth	=ac_objectget("iMc", i, 5)
			groWidth	=ac_objectget("iMc", i, 6)
			drillLowest	=ac_objectget("iMc", i, 7)
			drillFromEnd=ac_objectget("iMc", i, 8)
			drillSize	=ac_objectget("iMc", i, 9)
			drillSpacing=ac_objectget("iMc", i, 10)
			drillCount	=ac_objectget("iMc", i, 11)
			side		=ac_objectget("iMc", i, 12)
			drillFromEnd2=ac_objectget("iMc", i, 13)
			
			BvnAddHiddenShoe( isBeg, sPieceNum, holeWidth, holeHeight, holeDepth, groDepth, groWidth, drillLowest, drillFromEnd, drillSize, drillSpacing, drillCount, side, drillFromEnd2 )
			
		elseif nType==EMcFrAngledEndOld then
			nAngleTop=ac_objectget("iMc", i, 2)*PI/180
			nAngleSide=ac_objectget("iMc", i, 3)*PI/180
			nStraightTop=ac_objectget("iMc", i, 4)
			nStraightSide=ac_objectget("iMc", i, 5)
			
			-- Konversio hirren tyyliin
			if nAngleSide<0 then
				nAngleSide=-PI/2-nAngleSide
			else
				nAngleSide=PI/2-nAngleSide
			end
			
			-- Päältä puolen vaihto ja konversio hundegger-tyyliin
			nAngleTop=-nAngleTop
			if nAngleTop<0 then
				nAngleTop=-PI/2-nAngleTop
			else
				nAngleTop=PI/2-nAngleTop
			end
			BvnAddEndAngledOld( sPieceNum, nAngleSide, nStraightSide, nAngleTop, nStraightTop )
		
		--elseif nType==EMcFrOpening then
		elseif nType==EMcFrGroove then
			local groType
			x1		=ac_objectget("iMc", i, 2)
			y1		=ac_objectget("iMc", i, 3)
			x2		=ac_objectget("iMc", i, 4)
			y2		=ac_objectget("iMc", i, 5)
			groDepth=ac_objectget("iMc", i, 6)
			groWidth=ac_objectget("iMc", i, 7)
			groAngle=ac_objectget("iMc", i, 8)*PI/180.0
			groFace	=ac_objectget("iMc", i, 9)
			groAngleLen=ac_objectget("iMc", i, 10)*PI/180.0
			if groFace<5 then
				x1=x1+begExtra
				x2=x2+begExtra
			end
			groType=ac_objectget("iMc", i, 11)
			
			BvnAddGro(sPieceNum, x1, y1, x2, y2, groDepth, groWidth, groAngle, groFace, groAngleLen, groType)

		elseif nType==EMcFrDrill then
			x1		=ac_objectget("iMc", i, 2)
			y1		=ac_objectget("iMc", i, 3)
			groWidth=ac_objectget("iMc", i, 4)
			groDepth=ac_objectget("iMc", i, 5)
			groFace	=ac_objectget("iMc", i, 6)
			if groFace<5 then
				x1=x1+begExtra
			end
			BvnAddDrill(sPieceNum, x1, y1, groWidth, groDepth, groFace)

		elseif nType==EMcFrMarking then
			local bLine, bInLineDir

			x1		=ac_objectget("iMc", i, 2)
			y1		=ac_objectget("iMc", i, 3)
			x2		=ac_objectget("iMc", i, 4)
			y2		=ac_objectget("iMc", i, 5)
			xPosText=ac_objectget("iMc", i, 6)
			yPosText=ac_objectget("iMc", i, 7)
			fontSize=ac_objectget("iMc", i, 8)
			groFace	=ac_objectget("iMc", i, 9)
			textOff	=ac_objectget("iMc", i, 10)
			if groFace<5 then
				x1=x1+begExtra
				x2=x2+begExtra
			end

			bLine=true
			if BitTest(ac_objectget("iMc", i, 11), 2)==1 then
				bLine=false
			end

			bInLineDir=false
			if BitTest(ac_objectget("iMc", i, 11), 1)==1 or gnBvnForceTextLineDir then
				bInLineDir=true
			end

			s=ac_objectget("iMcStr", i, 1)
			if math.abs(textOff)<0.001 or s=="" then
				-- No text offset
				BvnAddMarking(sPieceNum, groFace, x1, y1, x2, y2, xPosText, yPosText, fontSize, 0, s, bLine, bInLineDir)
				s=""
			elseif bLine==nil or bLine==true then
				-- Only line
				BvnAddMarking(sPieceNum, groFace, x1, y1, x2, y2, xPosText, yPosText, fontSize, 0, "", bLine, bInLineDir)
			end
			
			if s~="" then
				-- Adjust the line with textOff and only text here
				dx=x2-x1
				dy=y2-y1
				z=math.sqrt(dx*dx+dy*dy)
				if z>0.001 then
					dx=dx/z
					dy=dy/z
					dx,dy=dy,-dx		-- To right
					x1=x1+dx*textOff
					y1=y1+dy*textOff
					x2=x2+dx*textOff
					y2=y2+dy*textOff
				end
				BvnAddMarking(sPieceNum, groFace, x1, y1, x2, y2, xPosText, yPosText, fontSize, 0, s, false, bInLineDir)
			end

		elseif nType==EMcFrReinforce then
			-- Marker lines to beg & end
			x1		=ac_objectget("iMc", i, 2)
			y1		=ac_objectget("iMc", i, 3)
			dx		=ac_objectget("iMc", i, 4)
			dy		=ac_objectget("iMc", i, 5)
			groFace	=ac_objectget("iMc", i, 7)

			xPosText=2
			yPosText=2
			if groFace==1 or groFace==3 then
				fontSize=gnCurrWidth
			else
				fontSize=gnProfHeight-gnBvnYoffset
			end
			fontSize=fontSize*50		-- 50% and to cm
			
			if dx<0.0005 then
				dx=gnCurrTotLen
				x1=gnCurrTotLen*0.5
			end

			textOff	=0
			s=ac_objectget("iMcStr", i, 1)
			if s=="" then
				s=string.format("%.0f x %.0f", dx*1000, dy*1000)
			end
			BvnMarkReinforcement( sPieceNum, groFace, x1, y1, dx, dy, xPosText, yPosText, fontSize, textOff, s )

			if ac_objectget("iMc", i, 8)~=0 then
				-- Both sides
				if groFace==1 then
					groFace=3
				elseif groFace==2 then
					groFace=4
				elseif groFace==3 then
					groFace=1
				elseif groFace==4 then
					groFace=2
				elseif groFace==5 then
					groFace=6
				elseif groFace==6 then
					groFace=5
				end
				BvnMarkReinforcement( sPieceNum, groFace, x1, y1, dx, dy, xPosText, yPosText, fontSize, textOff, s )
			end

		elseif nType==EMcFrSaw then
			-- Lengthwise sawing
			logFace		=ac_objectget("iMc", i, 2)
			xStart		=ac_objectget("iMc", i, 3)
			dWidth		=ac_objectget("iMc", i, 4)
			dDepthTop	=ac_objectget("iMc", i, 5)
			dYoffTop	=ac_objectget("iMc", i, 6)
			dAngleY2Deg	=ac_objectget("iMc", i, 7)
			dAngleY1Deg	=ac_objectget("iMc", i, 8)
			if logFace<5 then
				xStart=xStart+begExtra
			end
			BvnAddSaw( sPieceNum, logFace, xStart, dWidth, dDepthTop, dYoffTop, dAngleY2Deg, dAngleY1Deg )

		elseif nType==EMcFrTenonSide then
			--! ### 400: Tappiliitos tai lohari kylkeen
			--double		dType;				// [1] 
			--
			--double		dMidPos;			// [2] Keskipiste kyljessä (x)
			--double		dBotLevel;			// [3] Korkeusasema suhteessa alareunaan (y)
			--
			--// Because changed
			--double		dTenonLen;			// [4] Tapin pituus
			--double		dTenonWidth;		// [5] 
			--double		dTenonHeight;		// [6] 
			--double		dBottomGapOrRotDeg;	// [7] Tapin pohjavälys, if dFlags bit0=1 this is rotate angle in degrees. Rotate center is mortise bottom mid (x,y)
			--double		dBorderGapOrDtHousingDepth;	// [8] Tapin sivuvälys, if dFlags bit0=1 (from 2014) this is housing depth for mortise (not included in tenon len)
			--
			--double		dRoundingRadius;	// [9]
			--
			--double		dJointSideOneBased;	// [10] IFramePlankHandler::SideType+1: 1...6
			--double		dJointType;			// [11] ETypeXXX
			--
			--double		dAngleTenonDeg;		// [12] Ainakin lohenpyrstössä on alareuna usein kapeampi kuin yläreuna
			--double		dFlags;				// [13] Version control, bit0 used

			local logFace, str, bDove, midPos, borderBot, tenonLen, tenonWidth, tenonHeight, sideGap, bottomGap, angleDove, roundingR, rotAngleDeg, isNew, housingDepth

			isNew		=ac_objectget("iMc", i, 13) % 1		-- bit0: Version control

			bDove=false
			if ac_objectget("iMc", i, 11)==2 then
				bDove=true
			end
			
			midPos		=ac_objectget("iMc", i, 2)
			borderBot	=ac_objectget("iMc", i, 3)
			tenonLen	=ac_objectget("iMc", i, 4)
			tenonWidth	=ac_objectget("iMc", i, 5)
			tenonHeight	=ac_objectget("iMc", i, 6)

			rotAngleDeg=0
			bottomGap=0
			sideGap=0
			housingDepth=0
			if isNew then
				rotAngleDeg	=ac_objectget("iMc", i, 7)
				housingDepth=ac_objectget("iMc", i, 8)
			else
				bottomGap	=ac_objectget("iMc", i, 7)
				sideGap		=ac_objectget("iMc", i, 8)
			end

			roundingR	=ac_objectget("iMc", i, 9)
			logFace		=ac_objectget("iMc", i, 10)
			angleDove	=ac_objectget("iMc", i, 12)

			if logFace<5 then
				midPos=midPos+begExtra
			end

			BvnAddSideJoint( sPieceNum, logFace, bDove, midPos, borderBot, tenonLen+bottomGap, tenonWidth+sideGap*2, tenonHeight, angleDove, roundingR, rotAngleDeg, housingDepth )

		elseif nType==EMcFrBalkJoint then
			--! ### 401: Palkin kaulus
			--! iMc[mindex][2], uihelp_length1: keskipiste kapulan alusta
			--! iMc[mindex][3], uihelp_length2: kauluksen leveys
			--! iMc[mindex][4], uihelp_length3: kolous ylä
			--! iMc[mindex][5], uihelp_length4: kolous ala
			--! iMc[mindex][6], uihelp_length5: kolous sivut
			
			midPos		=ac_objectget("iMc", i, 2)+begExtra
			width		=ac_objectget("iMc", i, 3)
			depthTop	=ac_objectget("iMc", i, 4)
			depthBot	=ac_objectget("iMc", i, 5)
			depthSides	=ac_objectget("iMc", i, 6)
			BvnAddBalkMid(sPieceNum, midPos, width, depthTop, depthBot, depthSides)

		elseif nType==EMcFrBeamFemale then
			local side, width, height, openside, subtype

			x1		=ac_objectget("iMc", i, 2)
			y1		=ac_objectget("iMc", i, 3)
			side	=ac_objectget("iMc", i, 4)
			width	=ac_objectget("iMc", i, 5)-0.078
			openside=ac_objectget("iMc", i, 6)
			subtype	=ac_objectget("iMc", i, 8)

			x1=x1+begExtra

			height=width
			if side==0 and subtype==0 and (openside==1 or openside==3) then
				-- Takås through the log: x1,y1 is the middle of the takås
				if openside==1 and y1<gnProfHeight then
					height=height+gnProfHeight-y1
					y1=y1+(gnProfHeight-y1)/2			-- Should actually add to gnProfHeight and add double to height (similar to Pro Conv)
				elseif openside==3 and y1>0 then
					height=height+y1
					y1=y1-y1/2							-- Should actually add to gnProfHeight and add double to height (similar to Pro Conv)
				end
--ac_environment("tolog", string.format("width=%f height=%f y1=%f", width, height, y1))
				BvnAddSideJoint( sPieceNum, 2, false, x1, y1-height/2, 0, width, height, 0, width/2, 0, 0, "  0" )
				--BvnAddSideJoint( sPieceNum, logFace, bDove, midPos, borderBot, tenonLen, tenonWidth, tenonHeight, angleDove, roundingRadius, rotAngleDeg, housingDepth, sRoundType )
			else
				AddCncErr( x1, string.format("UNSUPPORTED BEAM MORTISE JOINT SKIPPED (subtype=%d)", subtype) )
			end

		elseif nType==EMcFrNailGroup or nType==EMcFrNailLine or nType==EMcFrBalkShoe then
			-- NOP for Hundegger on purpose
		elseif nType~=0 then
			AddCncErr( ac_objectget("iMc", i, 2), string.format("UNSUPPORTED MACHINING %d", nType) )
		end
	end

	-- Lengthwise profile
	local tblBeg, tblMid, tblEnd

	tblBeg=ProfPolyToEdges("iMatProfileXzBeg", gnCurrHeight)
	tblMid=ProfPolyToEdges("iMatProfileXzMid", gnCurrHeight)
	tblEnd=ProfPolyToEdges("iMatProfileXzEnd", gnCurrHeight)

	if tblEnd then
		ProfPolyToEnd(tblEnd, gnCurrTotLen)
	end

	if tblBeg~=nil then
		s=InsertProfTbl(sPieceNum, tblBeg, 0, false, gnCurrHeight )
		BvnAddLine(BvnGetXc(0), s, true)
	end

	if tblMid~=nil then
		-- Profile at mid
		local	x1, x2

		x1=0
		if tblBeg then
			x1=tblBeg.box.x2
		end

		x2=gnCurrTotLen
		if tblEnd then
			x2=tblEnd.box.x1
		end

		s=InsertProfTblMid(sPieceNum, tblMid, gnCurrHeight, x1, x2)
		BvnAddLine(BvnGetXc(x1), s, true)
	end

	if tblEnd~=nil then
		s=InsertProfTbl(sPieceNum, tblEnd, 0, true, gnCurrHeight)
		BvnAddLine(BvnGetXc(gnCurrTotLen), s, true)
	end
end


-- ### Lengthwise profile BEG

-- Converts object's table into lines and arcs. Contour goes ccw/right hand side outside
-- Returns: nil=no definition, otherwise structure having fields:
-- box, structure
--	x1,x2,y1,y2	Polygon bound box (x1,y1 always 0)
--	hasbot		Is bottom other than a line covering x1 -> x2
--	hastop		Is top other than a line covering x1 -> x2
-- edges, 1-based table having fields:
--	x1,y1	Begin pt
--	x2,y2	End point
--	isarc	true=is arc and following set, nil=line
--	midx,midy	Arc's center point
--	anglebegrad	Angle at starting point
--	anglelenrad	Angle length
function ProfPolyToEdges(parName, faceHeight)
	local	n, i, v, prevx, prevy, midx, midy, x2, y2, status, dest
	local	tbl, tblBox, tblEdges

	n=ac_objectget(parName,-1)
	if not n or n<9 then
		return nil
	end

	x2=0
	y2=0
	i=1
	prevx=nil
	midx=nil

	dest=0
	tblEdges={}

	while i+2<=n do
		x=ac_objectget(parName, i)
		y=ac_objectget(parName, i+1)
		status=ac_objectget(parName, i+2)
		if status<100 then
			-- Includes end point
			if x>x2 then
				x2=x
			end
			if y>y2 then
				y2=y
			end

			if prevx and (math.abs(x-prevx)>EPS or math.abs(y-prevy)>EPS) then
				-- New edge
				tbl={}
				tbl.x1=prevx
				tbl.y1=prevy
				tbl.x2=x
				tbl.y2=y
				dest=dest+1
				tblEdges[dest]=tbl
			end

			if status<0 then
				break
			end
			prevx=x
			prevy=y
			midx=nil
		elseif status>=900 and status<1000 then
			-- Circle center
			midx=x
			midy=y
		elseif status>=4000 and status<4100 then
			-- Arc/full circle, y=angledeg, if angle==360 then x=radius

			if math.abs(y)>359 then
				AddCncErr(0, string.format("Unsupported full circle in table %s", parName))
			else
				-- Arc
				local	a, r, dx, dy

--ac_environment("tolog", string.format("prevx=%f prevy=%f", prevx, prevy))
				tbl={}

				dy=prevy-midy
				dx=prevx-midx
				a=math.atan2(dy, dx)
				r=math.sqrt(dx*dx + dy*dy)
				tbl.anglebegrad=a
				a=a+y*PI/180

				tbl.x1=prevx
				tbl.y1=prevy

				tbl.x2=midx+math.cos(a)*r
				tbl.y2=midy+math.sin(a)*r

				tbl.isarc=true
				tbl.midx=midx
				tbl.midy=midy
				tbl.anglelenrad=y*PI/180

				dest=dest+1
				tblEdges[dest]=tbl

				prevx=tbl.x2
				prevy=tbl.y2

				if tbl.x2>x2 then
					x2=tbl.x2
				end
				if tbl.y2>y2 then
					y2=tbl.y2
				end
			end
		else
			AddCncErr(0, string.format("Unsupported length shape code %d in table %s", status, parName))
		end
		i=i+3
	end

	tblBox={}
	tblBox.x1=0
	tblBox.y1=0
	tblBox.x2=x2
	tblBox.y2=y2
	tblBox.hasbot=true
	tblBox.hastop=true

	-- Check if straight top or bottom
	for i,v in ipairs(tblEdges) do
		if not v.isarc and math.abs(v.y1-v.y2)<EPS and (v.x1<EPS and v.x2>x2-EPS or v.x2<EPS and v.x1>x2-EPS) then
			if v.y1<EPS then
				tblBox.hasbot=false
			end
			if v.y1>faceHeight-EPS then
				tblBox.hastop=false
			end
		end
	end

	tbl={}
	tbl.box=tblBox
	tbl.edges=tblEdges

--DumpTbl( tbl.edges )

	return tbl
end


-- Swaps coordinates to the plank's end and swaps direction of the polygon (to keep ccw)
function ProfPolyToEnd(tblEnd, plankLen)
	local i, v, n

	for i,v in ipairs(tblEnd.edges) do
		v.x1,v.y1,v.x2,v.y2=plankLen-v.x2, v.y2, plankLen-v.x1, v.y1			-- Swap coords

		if v.isarc then
			v.midx=plankLen-v.midx
			v.anglebegrad=math.atan2(v.y1-v.midy, v.x1-v.midx)
			-- Not changing: v.anglelenrad
		end
	end

	-- Need to swap order also
	n=#tblEnd.edges

	for i=1,math.floor(n/2) do
		v=tblEnd.edges[i]
		tblEnd.edges[i]=tblEnd.edges[n+1-i]
		tblEnd.edges[n+1-i]=v
	end

	tblEnd.box.x1,tblEnd.box.x2=plankLen-tblEnd.box.x2, plankLen-tblEnd.box.x1
end



function IsPlankContour(edge, box, faceHeight)
	if math.abs(edge.y1-edge.y2)<EPS then
		if edge.y1<EPS or edge.y1>faceHeight-EPS then
			return true
		end
	end

	if math.abs(edge.x1-edge.x2)<EPS then
		if edge.x1-EPS<box.x1 or edge.x1+EPS>box.x2 then
			return true
		end
	end

	-- Not at polygon/plank contour
	return false
end


function AngleTo2pi(a)
	local neg, pos

	while true do
		if a<0 then
			if pos then
				break
			end
			a=2*PI + a
			neg=true
		elseif a>2*PI then
			if neg then
				break
			end
			a=a-2*PI
			pos=true
		else
			break
		end
	end
	return a
end


-- Checks if points ix1,iy1 or ix2,iy2 are inside v.x1,v.y1 -> v.x2,v.y2
function PointsInLine(v,ix1,iy1,ix2,iy2)
	local off, dist, len

	if ix1 then
		off,dist,len=ac_geo("linedist", v.x1, v.y1, v.x2, v.y2, ix1, iy1)
--toLog(string.format("line1: v.x1=%f, v.y1=%f, v.x2=%f, v.y2=%f, ix1=%f, iy1=%f, off=%f dist=%f len=%f", v.x1, v.y1, v.x2, v.y2, ix1, iy1, off, dist, len))
		if dist>0.0005 and dist<len-0.0005 then
			return true
		end
	end

	if ix2 then
		off,dist,len=ac_geo("linedist", v.x1, v.y1, v.x2, v.y2, ix2, iy2)
--toLog(string.format("line2: v.x1=%f, v.y1=%f, v.x2=%f, v.y2=%f, ix2=%f, iy2=%f, off=%f, dist=%f len=%f", v.x1, v.y1, v.x2, v.y2, ix2, iy2, off, dist, len))
		if dist>0.0005 and dist<len-0.0005 then
			return true
		end
	end

	return false
end

-- sPieceNum	bvn piece number
-- tblPoly		From ProfPolyToEdges
-- limitTopBot	-1=bottom only, 0=all, 1=top only
-- findBot		true=find bottom line first
-- x2clip		nil=no clipping, value=where to clip the right hand side. Edits polygon if clipping occurs.
-- Returns multiline bvn-code
function InsertProfTbl(sPieceNum, tblPoly, limitTopBot, findBot, faceHeight, x2clip)
	local i, n, v, i1, cnc
	local millRadius=0.020		-- 40 mm finger cutter

	-- Find first item for top side (ccw) if begin or bottom if end
	i1=nil
	for i,v in ipairs(tblPoly.edges) do
		if findBot==false then
			if v.x1+EPS>tblPoly.box.x2 then
				if i1==nil or v.y1>tblPoly.edges[i1].y1 then
					i1=i
				end
			end
		else
			if v.x1-EPS<tblPoly.box.x1 then
				if i1==nil or v.y1<tblPoly.edges[i1].y1 then
					i1=i
				end
			end
		end
	end

	if not i1 then
		AddCncErr(0, string.format("ERROR: Cannot find starting point for contour shape - skipping contour at x1=%f x2=%f", tblPoly.box.x1, tblPoly.box.x2) )
		return 0
	end

	-- i1 points to the starting point
	local	tblAdd, addCount			-- Add field edgeindex 1...N to items: tells collect number to know if it continues with next
	local   skipEdge

	tblAdd={}
	addCount=0
	n=#tblPoly.edges
	-- Add all skipping straight edges on plank edges
	for i=1,n do
		v=tblPoly.edges[i1]

		skipEdge=false
		if x2clip then
			local	begout, endout, dist

			-- Starting point right from clipping line?
			dist=ac_geo("linedist", x2clip, -1, x2clip, faceHeight+1, v.x1, v.y1)
			if dist>-EPS then
				begout=true
			end

			dist=ac_geo("linedist", x2clip, -1, x2clip, faceHeight+1, v.x2, v.y2)
			if dist>-EPS then
				endout=true
			end

			if begout and endout then
				skipEdge=true
			elseif begout or endout then
				local xx, yy

				xx,yy=ac_geo("linex", x2clip, -1, x2clip, faceHeight+1, v.x1, v.y1, v.x2, v.y2)
				if begout then
					v.x1=xx
					v.y1=yy
				else
					v.x2=xx
					v.y2=yy
				end
			end
		end

		if skipEdge==false then
			if v.isarc or not IsPlankContour(v, tblPoly.box, faceHeight) then
				-- Add this edge
				addCount=addCount+1
				tblAdd[addCount]=v
				v.edgeindex=i
			end
		end

		if limitTopBot<0 then
			if v.x2+EPS>tblPoly.box.x2 then
				break
			end
		elseif limitTopBot>0 then
			if v.x1-EPS<tblPoly.box.x1 then
				break
			end
		end

		-- To next pt
		i1=i1+1
		if i1>n then
			i1=1
		end
	end

--DumpTbl(tblAdd)
	-- Add all collected edges
	local	s, isBeg, tbl, sCnc, x, y, len, x2, y2, a, nBvnSide, bMirrorY, prevDir, nEnd, vprev, vnext

	sCnc=""
	isBeg=true
	nBvnSide,bMirrorY=BvnGetSide(2)
	prevDir=0							-- Angle after prev segment in bvn-coordinates, always positive in radians
	vprev=nil							-- Previous segment
	for i,v in ipairs(tblAdd) do
		if isBeg then
			-- Add starting point
			--000003 3000 -3     4000    2040       0       0       0       0                                 000                           
			--000003 3001 -3     4000    2040       0      20       0     200       0      20       0   30000 000                           

			x=BvnGetXc(v.x1)
			y=BvnMirrorYc(v.y1, 2, bMirrorY)

			s=string.format(
			"%s 3000 %02d %8.0f %7.0f       0       0       0       0                                 000                           \n" ..
			"%s 3001 %02d %8.0f %7.0f       0      10       0     200       0      20       0       0 000                           ",					-- 20=tool on right from the line (10=left), 200=speed (mm/sec), 20=Tool type
			sPieceNum, BvnGetSide(2), x*10000, y*10000,
			sPieceNum, BvnGetSide(2), x*10000, y*10000
			)
			if sCnc~="" then
				s="\n" .. s			-- Not first contour
			end
			sCnc=sCnc .. s
		end

		vnext=nil
		nEnd=0
		if i==#tblAdd or v.edgeindex+1~=tblAdd[i+1].edgeindex then
			-- Terminate path
			nEnd=1
		else
			vnext=tblAdd[i+1]		-- Next segment
		end

		s=nil
		if v.isarc then
			-- Arc segment
			-- 000003 3005 03   5808.1  -342.1    1230       0       0    -870     930       0       0       0 000                           
			local r, a2

			-- Calc r
			x=v.x1-v.midx
			y=v.y1-v.midy
			r=math.sqrt(x*x + y*y)

			-- Calc begin angle as vector in bvn-coords
			x=math.cos(v.anglebegrad+PI2)		-- Tangent of the circle in this angle
			if gnBvnLogDir==EBvnDirEnd then
				x=-x
			end
			y=math.sin(v.anglebegrad+PI2)
			if bMirrorY then
				y=-y
			end
			a=AngleTo2pi(math.atan2(y, x))
			if v.anglelenrad<0 then
				a=a+PI
			end
			a=a-prevDir
			a=AngleTo2pi(a)


			a2=v.anglelenrad
			if bMirrorY then
				a2=-a2
			end
			if gnBvnLogDir==EBvnDirEnd then
				a2=-a2
			end

			x2=BvnGetXc(v.x2)
			y2=BvnMirrorYc(v.y2, 2, bMirrorY)

			s=string.format(
			"\n%s 3005 %02d %8.0f %7.0f %7.0f       0       0 %7.0f %7.0f       0       0       0 %03d                           ",
			sPieceNum, BvnGetSide(2), x2*10000, y2*10000, r*10000, a/PI*1800, a2/PI*1800, nEnd )
			sCnc=sCnc .. s

			prevDir=prevDir+a+a2
			if prevDir<0 then
				prevDir=2*PI + prevDir
			elseif prevDir>=2*PI then
				prevDir=prevDir-2*PI
			end

		else
			-- Line segment
			-- 000003 3002 -3   2787.6    1340       0       0       0    3300    1400       0       0       0 000                           
			local ix1, iy1, ix2, iy2			-- Intersection coords
			local dx, dy, offbeg, offend

			-- Unit vector for current line
			dx=v.x2-v.x1
			dy=v.y2-v.y1
			len=math.sqrt(dx*dx+dy*dy)
			dx=dx/len
			dy=dy/len
			offbeg=0
			offend=0

			if vprev then
				-- Adjust line beg with previous segment, it ends to this point's begin point
				-- Move so that finger cutter does not cut previous arc
				if vprev.isarc then
					local cx, cy

					cx=vprev.x1-vprev.midx
					cy=vprev.y1-vprev.midy
					r=math.sqrt(cx*cx + cy*cy)
					while true do
						ix1,iy1,ix2,iy2=GetCirclesX(vprev.midx, vprev.midy, r, v.x1+offbeg*dx + millRadius*dy, v.y1+offbeg*dy - millRadius*dx, millRadius, vprev.anglebegrad, vprev.anglelenrad)
						if ix2==nil or offbeg+0.001>len then
							-- No intersection (max touching prev segment) or segment will be empty
							break
						end

						-- Advance by 1 mm
						offbeg=offbeg+0.001
					end
				else
					-- Line segment
					while true do
						ix1,iy1,ix2,iy2=GetLineCircleX(vprev.x1, vprev.y1, vprev.x2, vprev.y2, v.x1+offbeg*dx + millRadius*dy, v.y1+offbeg*dy - millRadius*dx, millRadius)
						if ix1==nil or offbeg+0.001>len or not PointsInLine(vprev,ix1,iy1,ix2,iy2) then
							-- No intersection (max touching prev segment) or segment will be empty
							break
						end

						-- Advance by 1 mm
						offbeg=offbeg+0.001
					end
				end
			end

			-- Adjust line end with next segment
			if vnext then
				-- Adjust line beg with previous segment, it ends to this point's begin point
				-- Move so that finger cutter does not cut previous arc
				if vnext.isarc then
					local cx, cy

					cx=vnext.x1-vnext.midx
					cy=vnext.y1-vnext.midy
					r=math.sqrt(cx*cx + cy*cy)
					while true do
						ix1,iy1,ix2,iy2=GetCirclesX(cx, cy, r, v.x2-offend*dx + millRadius*dy, v.y2-offend*dy - millRadius*dx, millRadius, vnext.anglebegrad, vnext.anglelenrad)
						if ix2==nil or offend+0.001>len then
							-- No intersection (max touching prev segment) or segment will be empty
							break
						end

						-- Advance by 1 mm
						offend=offend+0.001
					end
				else
					-- Line segment
					while true do
						ix1,iy1,ix2,iy2=GetLineCircleX(vnext.x1, vnext.y1, vnext.x2, vnext.y2, v.x2-offend*dx + millRadius*dy, v.y2-offend*dy - millRadius*dx, millRadius)
						--if ix1==nil or offend+0.001>len then
						if ix1==nil or offend+0.001>len or not PointsInLine(vnext,ix1,iy1,ix2,iy2) then
							-- No intersection (max touching prev segment) or segment will be empty
							break
						end

						-- Advance by 1 mm
						offend=offend+0.001
					end
				end
			end

			x=BvnGetXc(v.x1)
			y=BvnMirrorYc(v.y1, 2, bMirrorY)
			x2=BvnGetXc(v.x2)
			y2=BvnMirrorYc(v.y2, 2, bMirrorY)

			dx=(x2-x)/len			-- Now to bvn vector
			dy=(y2-y)/len

			a=math.atan2(y2-y, x2-x)
			if a<0 then
				a=2*PI + a
			end

			if offbeg+offend+0.001>len then
				-- Whole segmen skipped, move to last position
				s=string.format(
				"\n%s 3008 %02d %8.0f %7.0f       0       0       0 %7.0f %7.0f       0       0       0 %03d                           ",
				sPieceNum, BvnGetSide(2), x2*10000, y2*10000, AngleTo2pi(a-prevDir)/PI*1800, len*10000, nEnd )
				sCnc=sCnc .. s
				prevDir=a
			else
				if offbeg>EPS then
					-- Move cutter without cutting
					s=string.format(
					"\n%s 3008 %02d %8.0f %7.0f       0       0       0 %7.0f %7.0f       0       0       0 000                           ",
					sPieceNum, BvnGetSide(2), (x+offbeg*dx)*10000, (y+offbeg*dy)*10000, AngleTo2pi(a-prevDir)/PI*1800, offbeg*10000 )
					sCnc=sCnc .. s
					prevDir=a
				end

				-- Cut
				s=string.format(
				"\n%s 3002 %02d %8.0f %7.0f       0       0       0 %7.0f %7.0f       0       0       0 %03d                           ",
				sPieceNum, BvnGetSide(2), (x2-offend*dx)*10000, (y2-offend*dy)*10000, AngleTo2pi(a-prevDir)/PI*1800, (len-offbeg-offend)*10000, nEnd )
				sCnc=sCnc .. s
				prevDir=a

				if offend>EPS then
					-- Move cutter without cutting
					s=string.format(
					"\n%s 3008 %02d %8.0f %7.0f       0       0       0 %7.0f %7.0f       0       0       0 000                           ",
					sPieceNum, BvnGetSide(2), x2*10000, y2*10000, AngleTo2pi(a-prevDir)/PI*1800, offend*10000 )
					sCnc=sCnc .. s
					prevDir=a
				end
			end
		end

		vprev=v
		isBeg=false
		if nEnd==1 then
			isBeg=true
			vprev=nil
			prevDir=0
		end
	end

	return sCnc
end



-- Like InsertProfTbl but takes x1,x2 and multiplies polygon on that area & handles top and bottom separately
function InsertProfTblMid(sPieceNum, tblPoly, faceHeight, x1, x2)
	local	xoff, i, v, s, sTop, sBot, x2clip

	sTop=""
	sBot=""
	xoff=x1
	while x1+0.001<x2 do
		for i,v in ipairs(tblPoly.edges) do
			v.x1=v.x1+xoff
			v.x2=v.x2+xoff
			if v.midx then
				v.midx=v.midx+xoff
			end
		end
		tblPoly.box.x1=tblPoly.box.x1+xoff
		tblPoly.box.x2=tblPoly.box.x2+xoff

		x2clip=x1+tblPoly.box.x2-tblPoly.box.x1
		if x2clip<x2 then
			x2clip=nil
		else
			x2clip=x2
		end

		s=InsertProfTbl(sPieceNum, tblPoly, -1, true, faceHeight, x2clip)
		if sTop~="" and s~="" then
			sTop=sTop .. "\n"
		end
		sTop=sTop .. s

		s=InsertProfTbl(sPieceNum, tblPoly, 1, false, faceHeight, x2clip)
		if sBot~="" and s~="" then
			sBot=sBot .. "\n"
		end
		sBot=sBot .. s

		xoff=tblPoly.box.x2-tblPoly.box.x1
		x1=x1+xoff
		if xoff<0.001 then
			break
		end
	end

	-- Not ending with \n
	if sTop~="" and sBot~="" then
		sTop=sTop .. "\n"
	end

	return sTop .. sBot
end

-- ### Lengthwise profile END


-----------------------------------------------------------------------------
-- FRAME PLANK

-- Returns width,height
function BvnGetPlankSize()
	local	width,height
	
	width=ac_objectget("iWidth")
	if width==nil or width==0.0 then
		width=ac_objectget("A")
	end

	height=ac_objectget("iHeight")
	if height==nil or height==0.0 then
		height=ac_objectget("B")
	end

	return width,height
end


-- Gets frame plank basic parameters:
-- gsCurrentLogId			Use same global as ArchiLogs to ease showing error msg
-- gnCurrTotLen
-- gnCurrHeight
-- gnCurrWidth
-- gnOverlap				Always zero
function BvnGetPlankBasicParams(unidPlank)
	local	dx, dy, dz, cosTiltAngle, tiltAngle

	gsCurrentLogId=ac_objectget("#id")
	gsCurrentLogGuid=unidPlank

	-- Pituus täytyy laskea
	tiltAngle=ac_objectget("iTiltAngle")
	cosTiltAngle=math.cos(tiltAngle)
	if math.abs(cosTiltAngle)<0.005 then
		-- Vertical
		gnCurrTotLen=ac_objectget("zzyzx")
	else
		dx=ac_objectget("iEndX")-ac_objectget("iBegX")
		dy=ac_objectget("iEndY")-ac_objectget("iBegY")
		dz=math.tan(tiltAngle)*math.sqrt(dx*dx + dy*dy)
		gnCurrTotLen=math.sqrt(dx*dx+dy*dy+dz*dz)
	end

	gnCurrWidth,gnCurrHeight=BvnGetPlankSize()
	gnOverlap=0		-- ac_objectget("iMatOverlap")
	gnBvnYoffset=0
	gnProfHeight=gnCurrHeight+gnOverlap
end

function HasReinforce()
	local i, n, nType
	
	n=ac_objectget("iMc" ,-1)
	for i=1,n do
		nType=NormalizeType(ac_objectget("iMc", i, 1))
		if nType==EMcFrReinforce then
			return true
		end
	end
	return false
end


-- Adds part's header line based on globals
-- sUsage is written into bvn-file's part name
-- useInfoSettings	Use gnBvnInfoPart etc to set up the infos (true=is a plank)
-- Returns the piece number to be used in every bvn-line
function BvnAddPartHeader(sUsage, nSimilarCount, useInfoSettings)
	local sPieceNum, x, y
	local sPart, sUnit, sGrade, sComment, sProf, sRoof, sType

	sPart=""
	sUnit=""
	sGrade=""
	sComment=""
	sProf=""
	sRoof=""
	sType=""

	-- Compatibility for pre 11/2017 (old code) -->
	if not sUsage then
		-- It is a plank, set defaults as they were
		sUsage=ac_objectget("iUsageId")
		if not sUsage then
			sUsage=""			-- Board obj
		end
		s=ac_objectget("iMatId")
		if s~=string.format("%.0fx%.0f", gnCurrWidth*1000, gnCurrHeight*1000) then
			sComment=s
		end
	end
	
	-- kappalenro suoraan ID:stä, jos on pelkkää numeroa
	if string.find(gsCurrentLogId, "[^%d]")==nil and gbBvnForceUnid==false then
		-- Pelkkää numeroa
		if gnBvnPieceNum==nil then
			-- Hätävarana, jos on muitakin kuin pelkkiä numeerisia tunnuksia
			gnBvnPieceNum=100000
		end
		sPieceNum=string.format( "%06s", gsCurrentLogId )
		sPart=sUsage
		if sPart=="" then
			sPart=gsCurrentLogId
		end
	else
		-- ID:ssä muutakin kuin numeroa
		if gnBvnPieceNum==nil then
			gnBvnPieceNum=1
		end
		if sUsage~="" then
			sPart=string.format( "%s (%s)", gsCurrentLogId, sUsage)
		else
			sPart=gsCurrentLogId
		end
		sPieceNum=string.format( "%06d", gnBvnPieceNum )
		gnBvnPieceNum=gnBvnPieceNum+1
	end
	-- Compatibility for pre 11/2017 (old code) <--

	if useInfoSettings then
		-- New settings from 11/2017 for frame plank
		local plankinfo

		plankinfo=af_request("plankinfo")
		sPart=GetInfoStr(gnBvnInfoPart, plankinfo)
		sUnit=GetInfoStr(gnBvnInfoUnit, plankinfo)
		sGrade=GetInfoStr(gnBvnInfoGr, plankinfo)
		sComment=GetInfoStr(gnBvnInfoComments, plankinfo)
		sProf=GetInfoStr(gnBvnInfoProf, plankinfo)
		sRoof=GetInfoStr(gnBvnInfoRoof, plankinfo)
		sType=GetInfoStr(gnBvnInfoType, plankinfo)

		if false then
			-- Debug/test types
			ac_environment("tolog", string.format("EInfoFullIDPlusUsage=%s", GetInfoStr(EInfoFullIDPlusUsage, plankinfo)))
			ac_environment("tolog", string.format("EInfoShortID=%s", GetInfoStr(EInfoShortID, plankinfo)))
			ac_environment("tolog", string.format("EInfoFullID=%s", GetInfoStr(EInfoFullID, plankinfo)))
			ac_environment("tolog", string.format("EInfoElementID=%s", GetInfoStr(EInfoElementID, plankinfo)))
			ac_environment("tolog", string.format("EInfoUsage=%s", GetInfoStr(EInfoUsage, plankinfo)))
			ac_environment("tolog", string.format("EInfoMatIdFull=%s", GetInfoStr(EInfoMatIdFull, plankinfo)))
			ac_environment("tolog", string.format("EInfoMatIdShort=%s", GetInfoStr(EInfoMatIdShort, plankinfo)))
			ac_environment("tolog", string.format("EInfoGrade=%s", GetInfoStr(EInfoGrade, plankinfo)))
			ac_environment("tolog", string.format("EInfoMatIdIfNotSize=%s", GetInfoStr(EInfoMatIdIfNotSize, plankinfo)))
			ac_environment("tolog", string.format("EInfoPlankRole=%s", GetInfoStr(EInfoPlankRole, plankinfo)))
			ac_environment("tolog", string.format("EInfoPlankRoleFin=%s", GetInfoStr(EInfoPlankRoleFin, plankinfo)))
			ac_environment("tolog", string.format("EInfoPlankRoleNor=%s", GetInfoStr(EInfoPlankRoleNor, plankinfo)))
		end
	end

	if gbBvnAddMarkLine and HasReinforce() then
		if sComment~="" then
			sComment=sComment .. " "
		end
		sComment=sComment .. "REINFORCED"
	end

	-- Must be numeric
	if sRoof=="" then
		sRoof="0"
	end

	-- Headers
	BvnAddLine( -1010, string.format(	"%s %-20.20s         %-10.10s%-2.2s%-3.3s%-3.3s%-5.5s%-10.10s%-40.40s                 ", 
								sPieceNum, sPart, sType, sProf, sRoof, sGrade, sUnit, sGrade, sComment) )
	if gnBvnPlateSide==EBvnMale or gnBvnPlateSide==EBvnFemale then
		x=gnCurrWidth
		y=gnProfHeight
	else
		y=gnCurrWidth
		x=gnProfHeight
	end
	BvnAddLine( -1005, string.format( "%s           %6.0f       0  %6.0f  %6.0f  %6.0f                                                                       ", 
								sPieceNum, nSimilarCount, 10000*x, 10000*y, 10000*gnCurrTotLen) )

	-- Longer/other attributes
	if string.len(sProf)>2 then
		BvnAddLine( -1004, string.format(	"%s 3200 03                                                  %30.30s                                ", 
									sPieceNum, sProf) )
	end
	if string.len(sUnit)>5 then
		BvnAddLine( -1004, string.format(	"%s 3201 03                                                  %30.30s                                ", 
									sPieceNum, sUnit) )
	end
	if string.len(sGrade)>10 then
		BvnAddLine( -1004, string.format(	"%s 3202 03                                                  %30.30s                                ", 
									sPieceNum, sGrade) )
	end

	return sPieceNum
end



function BvnCncTblToStr()
	local	s, s2
	
	-- From table to text
	if gTblCnc==nil then
		return ""
	end

	-- Sort the table and create full text
	table.sort(gTblCnc, function (n1, n2)
		if math.abs(n1.pos-n2.pos)>EPS then
			return n1.pos < n2.pos		-- compare the sort key
		end
		
		return n1.count < n2.count		-- Keep the order if at same pos
	end)

	s=""
	for i,v in ipairs(gTblCnc) do
		s2 = v.text .. "\n"
		s=s .. s2
	end

	-- May not add empty line: k2.exe does not like it: s=s .. "\n"
	return s
end


-- Write ArchiFrame plank Hundegger K1/K2 code.
-- ac_objectopen() must have been called before calling this
-- Saves CNC to variable gsCncText
function WriteBvnPlank(unidPlank, nSimilarCount)
	local	s, n, i, nOther, x, nDepth, x1, x2, nWidth, sBin, y, z, sPart, sUsage
	local	bBegJoint, bEndJoint, nLeftRight
	local	nBvnSide, bMirrorY
	local	nSplinter
	local	nAngleSide, nStraightSide, nAngleTop, nStraightTop
	local	nSide, sSide, nSortPos, prevSide, prevDir


	gnCncCount=0
	gTblCnc=nil
	gsCncText=""
	gsCurrentLogId=ac_objectget("#id")

	BvnGetPlankBasicParams(unidPlank)

	prevSide=gnBvnPlateSide
	if gnBvnAutoRotate==1 then
		-- Select feeding direction automatically
		if gnCurrHeight>gnCurrWidth then
			gnBvnPlateSide=EBvnFemale
		else
			gnBvnPlateSide=EBvnFrontSide
		end
	end
	
	-- Put material ID if it is different to widthxheight
	sPieceNum=BvnAddPartHeader(nil, nSimilarCount, true)

	nSplinter=100
	if gbBvnNoSplinterFree then
		nSplinter=0
	end

	-- Frame plank has all machinings in single table including beginning and ending shapes
	BvnWriteMcTbl(0)

	if gnPrintInfoSide~=0 and gsPrintInfoContent~="" then
		-- Print ID
		local sMark, xMid, yTop, x1, width, forcedFontSize
		local plankinfo

		plankinfo=af_request("plankinfo")

		sMark=gsPrintInfoContent
		sMark=ac_environment ("strreplace", sMark, "#fullid#", gsCurrentLogId)
		sMark=ac_environment ("strreplace", sMark, "#projnum#", ac_environment("parsetext", "<PROJECTNUMBER>"))
		sMark=ac_environment ("strreplace", sMark, "#projid#", ac_environment("parsetext", "<PROJECT_ID>"))
		sMark=ac_environment ("strreplace", sMark, "#shortid#", GetInfoStr(EInfoShortID, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#usage#", GetInfoStr(EInfoUsage, plankinfo))

		sMark=ac_environment ("strreplace", sMark, "#plankrole#", GetInfoStr(EInfoPlankRole, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#plankrolefin#", GetInfoStr(EInfoPlankRoleFin, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#plankrolenor#", GetInfoStr(EInfoPlankRoleNor, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#plankroleshort#", GetInfoStr(EInfoPlankRoleShort, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#plankroleshortfin#", GetInfoStr(EInfoPlankRoleShortFin, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#plankroleshortnor#", GetInfoStr(EInfoPlankRoleShortNor, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#ownerelemid#", GetInfoStr(EOwnerElemID, plankinfo))
		sMark=ac_environment ("strreplace", sMark, "#floornum#", GetInfoStr(EInfoFloorNum, plankinfo))

		yTop=gnCurrHeight

		-- Adjust so that does not intersect with grooves and markings
		if gnPrintInfoHeight<0.001 then
			gnPrintInfoHeight=0.001
		end

		width=string.len(sMark)*gnPrintInfoHeight*0.67		-- 20 mm per character for 30 mm high one
		width=width+0.100

		-- To the beginning
		xMid=width*0.5
		if gnPrintInfoXpos==2 then
			xMid=gnCurrTotLen*0.5
		elseif gnPrintInfoXpos==3 then
			xMid=gnCurrTotLen-width*0.5
			if xMid<0 then
				xMid=0
			end
		end

		if gnBvnLogDir==EBvnDirEnd then
			xMid=gnCurrTotLen-xMid
		end

		x1=xMid-width*0.5
		if x1<0 then
			x1=0
		end

		forcedFontSize=0
		if gnBvnForceTextSize then
			forcedFontSize=gnBvnForceTextSize
		end

--toLog(string.format("pre: gnPrintInfoHeight=%f x1=%f width=%f", gnPrintInfoHeight, x1, width))
		x1=af_request("mc_findtextpos", gnPrintInfoSide, x1, width, forcedFontSize)
--toLog(string.format("pre: gnPrintInfoHeight=%f x1=%f width=%f", gnPrintInfoHeight, x1, width))

		local prev=gnBvnForceTextSize

		gnBvnForceTextSize=nil
		-- Size: function will multiply by 100 making font size 10 to be 10 mm, here we have meter
		--BvnAddMarking(sPieceNum, gnPrintInfoSide, x1, 0, x1+width, 0, 1, 2, gnPrintInfoHeight*10000/100, 0, sMark, false)
		BvnAddMarking(sPieceNum, gnPrintInfoSide, x1, 0, x1+width, 0, 2, 2, gnPrintInfoHeight*10000/100, 0, sMark, false)

		gnBvnForceTextSize=prev
	end

	-- Sawings to beg and end
	n=3
	if gnBvnLogDir==EBvnDirEnd then
		n=-n
	end
	if gbBegCut==false then
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, n, 10000*BvnGetXc(0), 0, 0) )
	end
								
	if gbEndCut==false then
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, -n, 10000*BvnGetXc(gnCurrTotLen), 0, 0) )
	end

	gsCncText = gsCncText .. BvnCncTblToStr()

	gnBvnPlateSide=prevSide
	return 1
end


-- Called before writing new cnc-file - resets globals
function BvnOnInit()
	gnCncErrCount=0
	gtblUsedIds = {}
	gnBvnPieceNum=1
end

-- CODE SHARED WITH ARCHIFRAME END <--
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ARCHIFRAME ONLY



-- Called before save as dialog is showed
-- strPlnFileName	-> Full path file name of current pln WITHOUT extension (.pln removed)
-- Return values (multiple ret values):
-- 1=listing file name WITH extension, ""=Just prompt with file dlg, starting with *=result contains full path name - do not prompt
-- 2=file extension to be used in save as dialog
function OnInit(strPlnFileName)
	local	projNum = ac_environment("parsetext", "<PROJECTNUMBER>")


	BvnOnInit()
	sFileName=projNum .. ".bvn"
	sExt="bvn"

	return sFileName, sExt
end


function SettingsDlg()
	local	tblSettings, sInfos


	tblSettings={}
	tblSettings[1]			={}
	tblSettings[1].cfgonly	=1
	tblSettings[1].type		=2
	tblSettings[1].prompt	="Write splinter free codes"
	tblSettings[1].key		="bvnsplinterfree"
	tblSettings[1].defvalue	=1

	tblSettings[2]			={}
	tblSettings[2].cfgonly	=1
	tblSettings[2].type		=2
	tblSettings[2].prompt	="Write also top and bottom pieces"
	tblSettings[2].key		="bvntopbot"
	tblSettings[2].defvalue	=gnBvnWriteTopBottom

	tblSettings[3]			={}
	tblSettings[3].cfgonly	=1
	tblSettings[3].type		=2
	tblSettings[3].prompt	="Automatically rotate piece/widest side towards table"
	tblSettings[3].key		="bvnautorot"
	tblSettings[3].defvalue	=gnBvnAutoRotate

	tblSettings[4]			={}
	tblSettings[4].cfgonly	=1
	tblSettings[4].type		=2
	tblSettings[4].prompt	="Save into separate files based on element IDs"
	tblSettings[4].key		="bvnsepfiles"
	tblSettings[4].defvalue	=gnBvnWriteSepFiles

	tblSettings[5]			={}
	tblSettings[5].cfgonly	=1
	tblSettings[5].type		=2
	tblSettings[5].prompt	="For element-related pieces save just core-layer"
	tblSettings[5].key		="bvnonlycore"
	tblSettings[5].defvalue	=gnBvnWriteOnlyCore

	-- Info fields
	sInfos="\"1:Nothing\",\"2:Full ID plus usage (e.g. EW01-07 (ELEM))\",\"3:Short ID (e.g. 07)\",\"4:Full ID (e.g. EW01-07)\",\"5:Element ID (e.g. EW01)\",\"6:Usage (e.g. ELEM)\",\"7:Full mat id (e.g. 48x198 C24)\",\"8:Short mat id cut to last space (e.g. 48x198)\",\"9:Grade after last space from mat id (e.g. C24)\",\"10:Material ID if different from width x size (e.g. SAPCODE)\",\"11:Plank role in element (e.g. Stud)\",\"12:Plank role in element Finnish (e.g. Tolppa)\",\"13:Plank role in element Norwegian (e.g. Stender)\",\"14:Plank role in element short (e.g. ST)\",\"15:Plank role in element short Finnish (e.g. TO)\",\"16:Plank role in element short Norwegian (e.g. ST)\",\"17:CNC-Package or if it is empty the Element ID\",\"18:ID of the owning ArchiFrameElement-object\""
	tblSettings[6]			={}
	tblSettings[6].cfgonly	=1
	tblSettings[6].type		=1
	tblSettings[6].prompt	="Part field content"
	tblSettings[6].key		="partinfo"
	tblSettings[6].defvalue	=gnBvnInfoPart
	tblSettings[6].valuelist=sInfos

	tblSettings[7]			={}
	tblSettings[7].cfgonly	=1
	tblSettings[7].type		=1
	tblSettings[7].prompt	="Unit field content"
	tblSettings[7].key		="unitinfo"
	tblSettings[7].defvalue	=gnBvnInfoUnit
	tblSettings[7].valuelist=sInfos

	tblSettings[8]			={}
	tblSettings[8].cfgonly	=1
	tblSettings[8].type		=1
	tblSettings[8].prompt	="Gr field content"
	tblSettings[8].key		="grinfo"
	tblSettings[8].defvalue	=gnBvnInfoGr
	tblSettings[8].valuelist=sInfos

	tblSettings[9]			={}
	tblSettings[9].cfgonly	=1
	tblSettings[9].type		=1
	tblSettings[9].prompt	="Comments field content"
	tblSettings[9].key		="commentsinfo"
	tblSettings[9].defvalue	=gnBvnInfoComments
	tblSettings[9].valuelist=sInfos

	tblSettings[10]			={}
	tblSettings[10].cfgonly	=1
	tblSettings[10].type		=1
	tblSettings[10].prompt	="Prof field content"
	tblSettings[10].key		="profinfo"
	tblSettings[10].defvalue	=gnBvnInfoProf
	tblSettings[10].valuelist=sInfos

	tblSettings[11]			={}
	tblSettings[11].cfgonly	=1
	tblSettings[11].type		=1
	tblSettings[11].prompt	="Roof field content"
	tblSettings[11].key		="roofinfo"
	tblSettings[11].defvalue	=gnBvnInfoRoof
	tblSettings[11].valuelist=sInfos

	tblSettings[12]			={}
	tblSettings[12].cfgonly	=1
	tblSettings[12].type		=1
	tblSettings[12].prompt	="Type field content"
	tblSettings[12].key		="typeinfo"
	tblSettings[12].defvalue	=gnBvnInfoType
	tblSettings[12].valuelist=sInfos

	tblSettings[13]			={}
	tblSettings[13].cfgonly	=1
	tblSettings[13].type		=2
	tblSettings[13].prompt	="Write reinforcements"
	tblSettings[13].key		="bvnwrreinforce"
	tblSettings[13].defvalue	=gbBvnWriteReinforce

	tblSettings[14]			={}
	tblSettings[14].cfgonly	=1
	tblSettings[14].type		=2
	tblSettings[14].prompt	="Write reinforcement marking lines"
	tblSettings[14].key		="bvnmarklines"
	tblSettings[14].defvalue	=gbBvnAddMarkLine

	tblSettings[15]			={}
	tblSettings[15].cfgonly	=1
	tblSettings[15].type		=1
	tblSettings[15].prompt	="Plank's feeding direction"
	tblSettings[15].key		="bvnfeed"
	tblSettings[15].defvalue	=gnBvnLogDir+1
	tblSettings[15].valuelist   ="\"1:Begin first\",\"2:End first\""

	tblSettings[16]			={}
	tblSettings[16].cfgonly	=0
	tblSettings[16].type	=3
	tblSettings[16].prompt	="Warn if groove narrower, usually 40 mm, 0=No"
	tblSettings[16].key		="bvnwarngro"
	tblSettings[16].defvalue=0

	tblSettings[17]			={}
	tblSettings[17].cfgonly	=1
	tblSettings[17].type		=1
	tblSettings[17].prompt	="Print part ID content to side"
	tblSettings[17].key		="bvnidside"
	tblSettings[17].defvalue	=1
	tblSettings[17].valuelist   ="\"1:Do not print\",\"2:Top\",\"3:Front\",\"4:Bottom\",\"5:Back\""

	tblSettings[18]			={}
	tblSettings[18].cfgonly	=1
	tblSettings[18].type	=4
	tblSettings[18].prompt	="Part ID content to print"
	tblSettings[18].key		="bvnidstring"
	tblSettings[18].defvalue="#fullid#"

	tblSettings[19]			={}
	tblSettings[19].cfgonly	=1
	tblSettings[19].type	=3
	tblSettings[19].prompt	="Part ID text height"
	tblSettings[19].key		="bvnidsize"
	tblSettings[19].defvalue=0.015

	tblSettings[20]			={}
	tblSettings[20].cfgonly	=1
	tblSettings[20].type	=3
	tblSettings[20].prompt	="Force height of marking texts (0=no)"
	tblSettings[20].key		="bvntxtsize"
	tblSettings[20].defvalue=0

	tblSettings[21]			={}
	tblSettings[21].cfgonly	=1
	tblSettings[21].type		=2
	tblSettings[21].prompt	="Force texts to be in line's dir (as before 3/2022)"
	tblSettings[21].key		="bvntextline"
	tblSettings[21].defvalue	=1

	tblSettings[22]			={}
	tblSettings[22].cfgonly	=1
	tblSettings[22].type		=1
	tblSettings[22].prompt	="Part ID print x-coordinate"
	tblSettings[22].key		="bvnidxpos"
	tblSettings[22].defvalue	=1
	tblSettings[22].valuelist   ="\"1:Begin\",\"2:Middle\",\"3:End\""

	if af_request("aflang")=="ita" then
		tblSettings[1].prompt	="Scrivi codici senza schegge"
		tblSettings[2].prompt	="Includi piani inferiore e superiore nel file"
		tblSettings[3].prompt	="Posa automaticamente i pezzi lungo il lato maggiore"
		tblSettings[4].prompt	="Salva in file separati per ID"
		tblSettings[5].prompt	="Salva solo strato CORE (per elementi stratificati)"
		tblSettings[6].prompt	="Valore 'Part' da mostrare in K2"
		tblSettings[7].prompt	="Valore 'Unit' in K2"
		tblSettings[8].prompt	="Valore 'Gr' in K2"
		tblSettings[9].prompt	="Valore 'Comments' in K2"
		tblSettings[10].prompt	="Valore 'Prof' in K2"
		tblSettings[11].prompt	="Valore 'Roof.' in K2"
		tblSettings[12].prompt	="Valore 'Type' in K2"
		tblSettings[13].prompt	="Scrivi rinforzi"
		tblSettings[14].prompt	="Scrivi linea termine rinforzo"
		tblSettings[15].prompt	="Direzione di partenza taglio"
		tblSettings[15].valuelist   ="\"1:Parti dall'inizio\",\"2:Parti dalla fine\""
		tblSettings[16].prompt	="Segnala scanal. minori di (tipico=40 mm, 0=No)"
		tblSettings[17].prompt	="Scrivi ID sul lato:"
		tblSettings[17].valuelist="\"1:Non stampare\",\"2:Superiore\",\"3:Fronte\",\"4:Inferiore\",\"5:Retro\""
		tblSettings[18].prompt	="Contenuto ID da scrivere"
		tblSettings[19].prompt	="H testo ID"
		tblSettings[20].prompt	="Forza altezza ID elementi connessi (0=no)"
	end


    gHelpAnchor="afdlgbvnexport"
	bRes,sErr=ac_optiondlg("LDBV", "BVN-writing settings", tblSettings)
	if not bRes then
		return false
	end

	gbBvnNoSplinterFree=false
	if tblSettings[1].value==0 then
		gbBvnNoSplinterFree=true
	end

	gnBvnWriteTopBottom=tblSettings[2].value
	gnBvnAutoRotate	=tblSettings[3].value
	gnBvnWriteSepFiles	=tblSettings[4].value
	gnBvnWriteOnlyCore	=tblSettings[5].value

	gnBvnInfoPart	= tblSettings[6].value
	gnBvnInfoUnit	= tblSettings[7].value
	gnBvnInfoGr		= tblSettings[8].value
	gnBvnInfoComments = tblSettings[9].value
	gnBvnInfoProf	= tblSettings[10].value
	gnBvnInfoRoof	= tblSettings[11].value
	gnBvnInfoType	= tblSettings[12].value

	gbBvnWriteReinforce=false
	if tblSettings[13].value==1 then
		gbBvnWriteReinforce=true
	end

	gbBvnAddMarkLine=false
	if tblSettings[14].value==1 then
		gbBvnAddMarkLine=true
	end

	gnBvnLogDir=tblSettings[15].value-1
	gdBvnWarnGroWidth=tblSettings[16].value

	gnPrintInfoSide=tblSettings[17].value-1			-- 0=Don't print, 1-4=side
	gsPrintInfoContent=tblSettings[18].value
	gnPrintInfoHeight=tblSettings[19].value

	gnBvnForceTextSize=nil
	if tblSettings[20].value~=0 then
		gnBvnForceTextSize=tblSettings[20].value
	end

	gnBvnForceTextLineDir=false
	if tblSettings[21].value~=0 then
		gnBvnForceTextLineDir=true
	end

	gnPrintInfoXpos=tblSettings[22].value			-- 1=begin, 2=middle, 3=end
	return true
end


-- Returns path,file name and extension. nil=cannot find
function SplitFileName(strPathName)
	local path, fname, ext
	local i, c, extIndex

	i=string.len(strPathName)
	extIndex=i
	while i>0 do
		c=string.sub(strPathName, i, i)
		if ext==nil and c=="." then
			ext=string.sub(strPathName, i, string.len(strPathName))
			extIndex=i-1
		elseif fname==nil and (c=="\\" or c=="/") then
			fname=string.sub(strPathName, i+1, extIndex)
			path=string.sub(strPathName, 1, i)
			break
		end
		i=i-1
	end
	
	return path,fname,ext
end


function DoFileName(strFileName, strAdd)
	local path, fname, ext

	path, fname, ext=SplitFileName(strFileName, strNum)
	return string.format("%s%s%s%s", path, fname, strAdd, ext)
end


-- Writes every plate
function SaveReinforceBvn(strFileName)
	local hFile
	local sProjId=string.format( "REINFORCE %s", ac_environment("parsetext", "<PROJECTNAME>") )

	-- Frame-kapulat -> bvn
	hFile=io.open(strFileName, "wt")
	io.output( hFile )

	-- bvn-header...
	if string.len(sProjId)>20 then
		sProjId=string.sub(sProjId,1,20)
	end

	while string.len(sProjId)<20 do
		sProjId=sProjId .. " "
	end

	io.write( "    " .. sProjId .. "           0                 0        0        0        0        0             0   0                  \n" )
	-- ...bvn-header

	gnBvnPieceNum=1
	SaveReinforceBvn2()
	io.close( hFile )
end


-- Saves to open file
function SaveReinforceBvn2()
	local nPiece, sPart, sPieceNum, item, n, nSimilarCount

	for nPiece=1,gnReinforce do
		-- kappalenro suoraan ID:stä, jos on pelkkää numeroa
		item=gtblReinforce[nPiece]
		sPart=item.info
		sPieceNum=string.format( "%06d", gnBvnPieceNum )
		gnBvnPieceNum=gnBvnPieceNum+1			-- May be planks before reinforcements

		gnCncCount=0
		gTblCnc=nil
		gsCncText=""
		gsCurrentLogId="REINFORCE PIECE"
		gnCurrTotLen=item.width

		-- Headers
		BvnAddLine( -1010, string.format(	"%s %-20.20s                       0                                                                           ", 
									sPieceNum, sPart) )

		nSimilarCount=1
		BvnAddLine( -1005, string.format( "%s           %6.0f       0  %6.0f  %6.0f  %6.0f                                                                       ", 
									sPieceNum, nSimilarCount, 10000*item.height, 10000*item.thickness, 10000*item.width) )

		n=3
		--if gnBvnLogDir==EBvnDirEnd then
			--n=-n
		--end

		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, n, 10000*0, 0, 0) )
									
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, -n, 10000*gnCurrTotLen, 0, 0) )

		io.write( BvnCncTblToStr() )
	end
end


-- Called to do all that needs to be done
-- strFileName is full path name for the result file
function OnSaveList(strFileName)
	-- Edit BVN-settings here
	gnBvnPlateSide=EBvnFrontSide
	gnBvnLogDir=EBvnDirBeg
	gnBvnPieceNum=nil

	if not SettingsDlg() then
		gbCancel=true
		return
	end

	local	i, v, tblRes, owner, fname

	if gbBvnWriteReinforce then
		-- Add all reinforcements into ArchiFrame's internal plank list to be processed later
		i=1
		while true do
			v=gTblPlanks[i]
			if v==nil then
				break
			end
			i=i+1
			af_request( "mc_reinforce2planks", v )
		end
	end

	if gnBvnWriteOnlyCore==1 then
		-- Filter out anything related to elements but not into core layer
		local	tblPlanksNew, nPlanksNew, elemType, tblElem
		local	tblElemTypes			-- key=guid, value: 0=not core, 1=is core

		tblElemTypes={}
		tblPlanksNew={}
		nPlanksNew=0
		i=1
		while true do
			v=gTblPlanks[i]
			if v==nil then
				break
			end
			i=i+1

			ac_objectopen(v)
			tblRes=af_request("plankinfo", v)
			ac_objectclose()

			owner=tblRes.ownerelemguid

			if owner~=nil then
				-- Check that owner element type is core
				elemType=tblElemTypes[owner]
				if elemType==nil then
					-- Not known - open element
					local	ke, ve, currType

					tblElem=af_request("elem_openparent", owner)

					for ke,ve in ipairs(tblElem.tblelems) do
						currType=0
						if ve.type=="core" then
							currType=1
						end
						tblElemTypes[ve.guid]=currType
					end

					elemType=tblElemTypes[owner]
				end
				if elemType==1 then
					-- Core, add it
					owner=nil
				end
				-- Leave owner set not to be included
			end

			if not owner then
				nPlanksNew=nPlanksNew+1
				tblPlanksNew[nPlanksNew]=v
			end
		end

		gTblPlanks=tblPlanksNew
	end


	if gnBvnWriteSepFiles>0 then
		-- Choose file for each plank, planks are sorted by id
		local tblPlankFiles
		local ownerNone, ownerReinforce, planksNow

		-- Fields: numPlanks=number of collected planks, tblPlanks=plank list, sortkey
		ownerNone="$$$NO OWNER$$$"
		tblPlankFiles={}		-- key=owner=element id or one of above

		i=1
		while true do
			v=gTblPlanks[i]
			if v==nil then
				break
			end

			ac_objectopen(v)

			-- Related to any element?
			tblRes=af_request("plankinfo", v)
			owner=tblRes.ownerelemid
			if owner==nil then
				owner=ownerNone
			end

			planksNow=tblPlankFiles[owner]
			if planksNow==nil then
				planksNow={}
				planksNow.numPlanks=0
				planksNow.tblPlanks={}

				planksNow.sortkey=owner
				planksNow.owner=owner
				tblPlankFiles[owner]=planksNow
			end

			planksNow.numPlanks=planksNow.numPlanks+1
			planksNow.tblPlanks[planksNow.numPlanks]=v

			ac_objectclose(v)
			i=i+1
		end

		local key, value, tblSorted, sComment, elemsCount
	
		tblSorted={}
		elemsCount=0
		for key,value in pairs(tblPlankFiles) do
			elemsCount=elemsCount+1
			tblSorted[elemsCount]=value
		end
	
		table.sort(tblSorted, function (n1, n2)
			return n1.sortkey < n2.sortkey
		end)

		for key,value in ipairs(tblSorted) do
			gnBvnPieceNum=nil
			gTblPlanks=value.tblPlanks
			owner=value.owner
			sComment=nil
			if owner==ownerNone then
				--Write without any addition to the file name
				OnSaveListInt(strFileName, true, nil)
			else
				fname=DoFileName(strFileName, "_" .. owner)
				OnSaveListInt(fname, true, owner)
			end
		end
	else
		-- All into single file
		OnSaveListInt(strFileName, true)
	end

	if gbBvnWriteReinforce then
		-- Always to separate file
		af_request( "mc_reinforce2tbl", "REINF/[parentid]-001" )		-- To internal table to be processed later
		fname=DoFileName(strFileName, "_reinforce")
		OnSaveListInt(fname, true, nil)
	end

	if false then
		-- Debug all feeding variations
		local dir, plate

		ac_msgbox( "TESTING, PLANK FED ALL WAYS" )
		
		gbBvnForceUnid=true
		for dir=0,1 do
			gnBvnLogDir=dir
			for plate=0,3 do
				gnBvnPlateSide=plate
				gtblUsedIds = {}	
				OnSaveListInt(strFileName, false)
			end
		end
	end
end


-- Called to do all that needs to be done
-- strFileName is full path name for the result file
-- sWallId nil=write all into single file, otherwise the element ID for this file
function OnSaveListInt(strFileName, bWriteHeader, sWallId)
	local sProjId=ac_environment("parsetext", "<PROJECTNAME>")
	local nSimilarCount, sGuid, i1, i2, i, v, prevPackage, s

	if not gbBvnWriteProjName then
		sProjId=""
	end

	if sWallId then
		if sProjId~="" then
			sProjId=sProjId .. " "
		end
		sProjId=sProjId .. sWallId
	end

	-- Start writing
	sTotPlank=""
	i=1
	while true do
		v=gTblPlanks[i]
		if v==nil then
			break
		end
		gsCurrentLogId=ac_getobjparam(v, "#id")
		sGuid=ac_getobjparam(v, "#libguid")
		prevPackage=ac_getobjparam(v, "iCncPackage")
		CheckId(gsCurrentLogId)
		
		-- Lasketaan montako on samalla id:llä ja täräytetään ne kerralla
		nSimilarCount=1
		while gTblPlanks[i+nSimilarCount]~=nil do
			if gsCurrentLogId~=ac_getobjparam(gTblPlanks[i+nSimilarCount], "#id") then
				break
			end
			if sGuid~=ac_getobjparam(gTblPlanks[i+nSimilarCount], "#libguid") then
				break
			end
			if prevPackage then
				s=ac_getobjparam(gTblPlanks[i+nSimilarCount], "iCncPackage")
				if s and prevPackage~=s then
					break
				end
			end

			nSimilarCount=nSimilarCount+1
		end

		gsCurrentLogGuid=v
		ac_objectopen(v)

		-- # GUID of the libpart, first part only
		sGuid=string.lower(sGuid)
		i1,i2=string.find( sGuid, "}-{", 1, true )
		if i1==nil then
			error( "Bad guid: " .. sGuid )
		end

		sGuid=string.sub(sGuid, 1, i1)
		gsCncText=""
		if sGuid=="{b42736c9-1a6b-4166-bc7c-6f3634e90c73}" then
			-- Frame plank
			local bWrite, s

			bWrite=true
			s=ac_objectget("iElemGroup")
			if gnBvnWriteTopBottom==0 and (string.match(s, "^bottom_.*") or string.match(s, "^2ndbottom_.*") or string.match(s, "^top_.*") or string.match(s, "^2ndtop_.*")) then
				bWrite=false
			end

			if bWrite then
				WriteBvnPlank( v, nSimilarCount )
			end
		elseif sGuid=="{9277f2c2-b9ee-11d8-a788-000a9575b220}" then
			-- Log
			WriteBvnLog( v, nSimilarCount )
		elseif sGuid=="{fddf39ba-935a-4a61-b2ec-a0f9bac3197a}" then
			-- Log column
			WriteBvnLogCol( v, nSimilarCount )
		elseif sGuid=="{4c1329e6-90d9-4203-972d-7b096b3d93e6}" then
			-- Board
			WriteBvnPlank( v, nSimilarCount )
		else
			AddCncErr( 0, "ERROR: UNKNOWN OBJECT TYPE: " .. ac_objectget("#libname") );
			error( "ERROR: UNKNOWN OBJECT TYPE: " .. ac_objectget("#libname") )
		end
			
		ac_objectclose(v)
		sTotPlank=sTotPlank .. gsCncText
		i=i+nSimilarCount
	end
	
	-- Frame-kapulat -> bvn
	if bWriteHeader then
		hFile=io.open(strFileName, "wt")
	else
		hFile=io.open(strFileName, "at")
	end

	io.output( hFile )

	if bWriteHeader then
		-- bvn-header...
		if string.len(sProjId)>20 then
			sProjId=string.sub(sProjId,1,20)
		end

		while string.len(sProjId)<20 do
			sProjId=sProjId .. " "
		end

		io.write( "    " .. sProjId .. "           0                 0        0        0        0        0             0   0                  \n" )
		-- ...bvn-header
	end

	io.write( sTotPlank )
	io.close( hFile )
	gsCncText=""
end


-----------------------------------------------------------------------------
-- Log object
function WriteBvnLog(unIdLog, nSimilarCount)
	-- Write iMc. It is without any y-offsets unlike machining
	local	tblInfo
	local	prevSide, prevDir

	prevSide=gnBvnPlateSide
	prevDir=gnBvnLogDir
	gnBvnPlateSide=EBvnFrontSide
	gnBvnLogDir=EBvnDirBeg
	if gbKarstula then
		gnBvnLogDir=EBvnDirEnd
		gnBvnPlateSide=EBvnBackSide
	end
	
	-- Part params
	tblInfo=af_request("plankinfo", gsCurrentLogGuid)
	gnCurrTotLen	=tblInfo.len
	gnCurrWidth		=tblInfo.width
	gnCurrHeight	=tblInfo.height
	gnBegExtra		=tblInfo.begoff
	gnOverlap		=0
	gnBvnYoffset	=0
	gnProfHeight	=gnCurrHeight
	gnBvnYoffset	=0
	
	-- Cnc base
	gnCncCount=0
	gTblCnc=nil
	gsCncText=""
	sPieceNum=BvnAddPartHeader("LOG", 1)
	
	BvnWriteMcTbl( gnBegExtra )
	

	-- Sawings to beg and end
	n=3
	if gnBvnLogDir==EBvnDirEnd then
		n=-n
	end
	if gbBegCut==false then
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, n, 10000*BvnGetXc(0), 0, 0) )
	end
								
	if gbEndCut==false then
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, -n, 10000*BvnGetXc(gnCurrTotLen), 0, 0) )
	end

	gsCncText = gsCncText .. BvnCncTblToStr()
	
	gnBvnPlateSide=prevSide
	gnBvnLogDir=prevDir
end

-- Log object
-----------------------------------------------------------------------------


-----------------------------------------------------------------------------
-- Log column object
function WriteBvnLogCol(unIdLog, nSimilarCount)
	-- Write iMc. It is without any y-offsets unlike machining
	local	tblInfo
	local	prevSide, prevDir


	-- Part params
	tblInfo=af_request("plankinfo", gsCurrentLogGuid)
	gnCurrTotLen	=tblInfo.len
	gnCurrWidth		=tblInfo.width
	gnCurrHeight	=tblInfo.height
	gnBegExtra		=tblInfo.begoff
	gnOverlap		=0
	gnBvnYoffset	=0
	gnProfHeight	=gnCurrHeight
	gnBvnYoffset	=0
	
	-- Cnc base
	gnCncCount=0
	gTblCnc=nil
	gsCncText=""
	sPieceNum=BvnAddPartHeader("LOG COL", nSimilarCount)

	BvnWriteMcTbl( gnBegExtra )
	

	-- Sawings to beg and end
	n=3
	if gnBvnLogDir==EBvnDirEnd then
		n=-n
	end
	if gbBegCut==false then
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, n, 10000*BvnGetXc(0), 0, 0) )
	end
								
	if gbEndCut==false then
		BvnAddLine( -1001,  string.format( "%s 0100 %02d %8.0f %7.0f %7.0f     900     900       0       0       0       0       0 000                           ",
									sPieceNum, -n, 10000*BvnGetXc(gnCurrTotLen), 0, 0) )
	end

	gsCncText = gsCncText .. BvnCncTblToStr()
end


-- Log column object
-----------------------------------------------------------------------------

gbBvnWriteProjName=true				-- Write <PROJECTNAME> into bvn-file
gnBvnWriteTopBottom=1				-- Write top and bottom pieces into bvn
gnBvnAutoRotate=0					-- 1=select feeding direction so that wider side is against the table
gbBvnWriteReinforce=false			-- Write the reinforcement pieces
gbBvnAddMarkLine=false				-- Add reinforcements lines
gnBvnWriteSepFiles=0				-- 0=All into single file, 1=split by owning element ID
gnBvnWriteOnlyCore=0				-- 0=write all, 1=if part of element, write only core layer
gdBvnWarnGroWidth=0					-- If non-zero, warn about grooves smaller than this value

gnBvnInfoPart		= EInfoFullIDPlusUsage		-- Part field (20 chars)
gnBvnInfoUnit		= EInfoNone					-- (31 chars)
gnBvnInfoGr			= EInfoNone					-- (31 chars)
gnBvnInfoComments	= EInfoMatIdIfNotSize		-- (40 chars)
gnBvnInfoProf		= EInfoNone					-- (2 chars)
gnBvnInfoRoof		= EInfoNone					-- (3 chars)
gnBvnInfoType		= EInfoNone					-- (3 chars)
