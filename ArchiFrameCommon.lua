-- ArchiFrameCommon Lua helper library
--
-- Put the following 3 lines at the start of your Lua file to get access to this module ('af')
-- 
--   local scriptDir, pathChar = ac_environment("scriptdir")
--   package.path = scriptDir .. pathChar .. "?.lua;" .. package.path
--   require("ArchiFrameCommon")
--
--
-- Then, e.g.:
--
--     af.Log("test log")
-- 
-----------------------------------------------------------------------------------------------------------------------

module("af", package.seeall)

EPS = 0.0001
MM2 = 0.0005
PI  = 3.141592653589793
PI2 = PI * 0.5

-- # Frame machinings types
EMcFrAngledBegOld	= 100
EMcFrAngledBeg		= 101
EMcFrAngledBegTenon = 110		-- Also dovetail (OLD)
EMcFrBegHiddenShoe	= 111
EMcFrAngledBegTenonMort = 112
EMcFrJointBeg			= 113
EMcFrVCutBeg			= 114
EMcFrAngledEndOld	= 200
EMcFrAngledEnd		= 201
EMcFrAngledEndTenon	= 210
EMcFrEndHiddenShoe	= 211
EMcFrAngledEndTenonMort = 212
EMcFrJointEnd			= 213
EMcFrVCutEnd			= 214

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


function Log(str)
	ac_environment("tolog", str)
end


function dumpint(o, nIndent)
  local s,k,v
  
  if type(o) == 'table' then
    s = '{\n'
    for i = 0, nIndent do
      s = s .. '\t'
    end
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dumpint(v, nIndent + 1) .. ',\n'
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



-- Dumps given variable to log
function Dump(o)
	Log(dumpint(o, 0))
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


-- Formats message so that calling program shows just the msg
-- Message can be empty - nothing is showed then (if operation canceled)
function RaiseError(msg)
	msg="###>" ..  msg .. "<###"
	error( msg )
end


-- open Excel on windows, and open the supplied file at filepath
function ExcelOpen(filepath)
	if not ac_environment("shellopen", filepath) then
		-- not necessarily an error
	end
end


-- Do we have imperial working settings?
function CheckImperial()
	local  n, s	
	n,s=ac_environment("units", "length", "work")
	if n>2 then
		-- AC22 added decimeter, check all metric units
		if s~="m" and s~="dm" and s~="cm" and s~="mm" then
			return true
		end
	end
	return false
end


function IsEmptyString(str)
	if str == nil or str == '' then
		return true
	end
	return false
end


function Text2Csv(s, forceEscape)
	if not forceEscape and string.find(s, ";")==nil and string.find(s, "\"")==nil then
		return s
	end

	local i, len, dest, c

	dest="\""
	len=string.len(s)
	for i=1,len do
		c=string.sub(s, i, i)
		if c=="\"" then
			c="\"\""
		end
		dest=dest .. c
	end
	dest=dest .. "\""
	return dest
end


function GetLangStr3()
	local res

	res=af_request("aflang")
	if res==nil then
		res="eng"
	end
	return string.upper(string.sub(res,1,1)) .. string.sub(res,2)
end


-- In: file.ext, out:file[sAppend]
function ChangeFileNameExt(sOrgName, sAppend)
	local	i, sName

	i=string.len(sOrgName)
	sName=sOrgName .. sAppend
	while i>0 do
		if string.sub(sOrgName, i, i)=="." then
			sName=string.sub(sOrgName, 1, i-1) .. sAppend 
			break
		end
		i=i-1
	end

	return sName
end


function GetFileExt(sOrgName)
	local	i

	i=string.len(sOrgName)
	while i>0 do
		if string.sub(sOrgName, i, i)=="." then
			return string.sub(sOrgName, i)
		end
		i=i-1
	end

	return ""
end


-- Gives file name to user specific folder or current script's folder
-- fnameNoExt	File name without language and file extension
-- Returns the full path file name
function GetTemplateFileName(fnameNoExt, fileExt)
	local   apxPath, dataPath, userPath, fname, res

	apxPath,dataPath,userPath=af_request("afpaths")

	fname,res=GetTemplateFileNameInt(userPath, fnameNoExt, fileExt)
	if res then
		return fname
	end

	-- Fallback
	return GetTemplateFileNameInt(gsScriptPath, fnameNoExt, fileExt)
end


function GetTemplateFileNameInt(path, fnameNoExt, ext)
	local	file, templateName, res

	res=false
	str=GetLangStr3()
	templateName=path .. fnameNoExt .. str .. ext
	file=io.open(templateName, "r")
	if file then
		io.close( file )
		res=true
	else
		templateName=path .. fnameNoExt .. "Eng" .. ext		-- fallback

		file=io.open(templateName, "r")
		if file then
			io.close( file )
			res=true
		else
			templateName=path .. fnameNoExt .. ext		-- fallback2 original name no additions
		end
	end
	return templateName, res
end

	function GeneratePanels(length, panelWidth, gap, offset)
	  local panels = {}
	  local x = offset
	  while x < length do
		local x1 = x
		local x2 = math.min(x + panelWidth, length)
		table.insert(panels, {x1 = x1, x2 = x2})
		x = x2 + gap
	  end
	  return panels
	end


function GetAutoTextNoNil(autoName)
	local	s

	s=ac_environment("parsetext", autoName)
	if s==nil then
		s=autoName
	end
	if s=="" then
		s=autoName
	end
	return s
end


-- Returns width,height
-- Object needs to be opened with ac_objectopen()
function GetPlankSize()
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


-- Gives ac_objectopen()-called current plank's length
function GetPlankLength()
	local	angle, len

	len=ac_objectget("iMatFixLen")
	if len==nil then
		return 0								-- Board?
	end

	if len<0.001 then
		angle	=ac_objectget("iTiltAngle")
		if math.abs(math.abs(angle)-PI2)<PI2/90.0 + EPS then
			len	=ac_objectget("zzyzx")			-- Column like
		else
			local	dx, dy, dz

			dx=ac_objectget("iEndX") - ac_objectget("iBegX")
			dy=ac_objectget("iEndY") - ac_objectget("iBegY")
			dz=math.tan(angle)*math.sqrt(dx*dx+dy*dy)
			len	=math.sqrt(dx*dx+dy*dy+dz*dz)
		end
	end

	return len
end


-- Returns true if the board identified by guid has type code denoting insulation, false otherwise.
function BoardIsInsulation(guid)
	local code

	code = ac_getobjparam(guid, "iTypeCode")
	if code and code>=200 and code<300 then
		return true
	end

	return false
end


-- Returns true if any board in tblBoards is flagged as insulation, false otherwise.
function BoardHasInsulation(tblBoards)
	local i, code

	if tblBoards==nil then
		return false
	end

	i=1
	while tblBoards[i] do
		if BoardIsInsulation(tblBoards[i].guid) then
			return true
		end
		i=i+1
	end

	return false
end


-- Gets AF's default material list and sorts it. Returns the sorted table and string of the the material IDs suitable for dialogs.
function GetSortedMaterials()
  local tblMaterials, tblSortedMaterials
  local strMaterials
  local s = ""
  local strSep = ""
  local i, id, v

  tblMaterials = af_request("matlist")

  local n = 0
  tblSortedMaterials = {}

  -- We'll remove those materials that don't have height & thickness defined
  for id, v in pairs(tblMaterials) do
    if v.height ~= 0 and v.thickness ~= 0 then
      n = n + 1
      tblSortedMaterials[n] = v
    end
  end

  table.sort(tblSortedMaterials, function(m1, m2)
    return m1.index < m2.index
  end)

  -- Since we removed bunch of materials from the list, the indices are 'off by diff', adjust them here
  local diff = tblSortedMaterials[#tblSortedMaterials].index - #tblSortedMaterials
  for i = 1, #tblSortedMaterials do
    tblSortedMaterials[i].index = tblSortedMaterials[i].index - diff
  end

  for i, v in ipairs(tblSortedMaterials) do
    s = string.format("%s%s\"%s:%s (%s)\"", s, strSep, i, v.name, v.id)
    strSep = ","
  end

  return tblSortedMaterials, s
end


-- Given a string sMatId, tries to separate the 'quality' from it
-- Returns an empty string on error or in the case that quality can't be found.
function MaterialIdToQuality(sMatId)
	local j, w, ret

	j = 1
	ret = {}

	for w in sMatId:gmatch("[%w-]+") do
		ret[j] = w
		j = j + 1
	end

	if ret[#ret] ~= nil then
		return ret[#ret]
	else
		return ""
	end
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
    if type(o) == 'string' then
    	s = '"' .. tostring(o) .. '"'
    elseif type(o) == 'number' then						-- Less digits to be able to compare results
    	s = '"' .. string.format("%0.4f", o) .. '"'
    else
    	s = tostring(o)
    end
  end
  return s
end


-- Dumps a table to the log window with indentation.
function DumpTbl(o)
  ac_environment("tolog", DumpTblInt(o, 0))
end


function FormatFloat(f)
  return string.format("%.4f", f)
end


function DumpMatrix(M)
  local m, n, s
  s = ""
  
  if #M == 12 then
    m = 3 -- rows
    n = 4 -- columns
  elseif #M == 16 then
    m = 4
    n = 4
  else
    -- just print it out as an linear array
    for i = 1, #M do
      s = s .. " " .. FormatFloat(M[i])
    end
    ac_environment("tolog", s)
  end
  
  for j = 1, m do
    for i = 1, n do
      if i ~= 1 then s = s .. "\t\t" end
      s = s .. FormatFloat(M[(j - 1) * m + i])
    end
    s = s .. "\n"
  end
  
  ac_environment("tolog", s)
end


function DumpVector(V)
  local k, v
  local s = ''
  
  for k, v in pairs(V) do
    if type(k) == 'number' then
      local components = {'x', 'y', 'z', 'w', 'u', 'v', 'w'}
      s = s .. components[k] .. '=' .. FormatFloat(v) .. ' '
    else
      s = s .. k .. '=' .. FormatFloat(v) .. ' '
    end
  end
  ac_environment("tolog", s)
end


-----------------------------------------------------------------------------------------------------------------------
-- Math & Geometry


-- Returns cos angle of the vectors if normalized
function CalcDot3D( x1, y1, z1, x2, y2, z2 )
	return x1 * x2 + y1 * y2 + z1 * z2;
end


-- Calculates plane equation from normal vector and a point on the plane x1, y1, z1
-- Note! Plane constant having different sign compared to Wykobi
-- in:
--	tnx, tny, tnz	Plane normal, calculated to unit vec here
--	x1,y1,z1		Point on the plane
-- Returns:
--	pa, pb, pc, pd	Plane equation (pa,pb,pc=normal vector of the plane as unit)
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
	local mul, pa, pb, pc, pd

	-- Tässä hypätään suoraan vakion laskentaan
	mul=math.sqrt(tnx*tnx+tny*tny+tnz*tnz)
	if math.abs(mul)<0.00001 then
		return 0, 0, 0, 0
	end

	mul=1/mul
	pa=tnx*mul
	pb=tny*mul
	pc=tnz*mul
	pd=-(pa*x1+pb*y1+pc*z1)
	return pa, pb, pc, pd
end


-- ## Calculates 3D point distance from plane
-- pos=in normal vector's dir, neg=on the back side
function DistFromPlane(x, y, z, pa, pb, pc, pd)
	return pa * x + pb * y + pc * z + pd
end


-- Returns given 3D pt projected to the plane: x, y, z
function ProjectToPlane(x, y, z, pa, pb, pc, pd)
	local dist

	dist = DistFromPlane(x, y, z, pa, pb, pc, pd)

	-- Offset by dist to get onto the plane
	x = x - dist * pa;
	y = y - dist * pb;
	z = z - dist * pc;
	return x, y, z
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


function DistPoints2D(pt1, pt2)
	local subvecx = pt2.x - pt1.x
	local subvecy = pt2.y - pt1.y
	return math.sqrt(subvecx * subvecx + subvecy * subvecy)
end

function IsPointOnEdge2D(point, edgeBeg, edgeEnd)
	local result = false
	local dist0 = af.DistPoints2D(edgeBeg, edgeEnd)
	local dist1 = af.DistPoints2D(edgeBeg, point)
	local dist2 = af.DistPoints2D(point, edgeEnd)
	if math.abs(dist1 + dist2 - dist0) < 0.0001 then
		result = true
	end
	return result
end

function IsParallelVectors2D(vec1, vec2)
	local result = false
	if math.abs(vec1.x * vec2.y - vec2.x * vec1.y) < 0.001 then
		result = true
	end
	return result
end

function IsOppositeVectors2D(vec1, vec2)
	local result = false
	local length1 = math.sqrt(vec1.x * vec1.x + vec1.y * vec1.y)
	local length2 = math.sqrt(vec2.x * vec2.x + vec2.y * vec2.y)
	local unitVector1 = {x=vec1.x/length1, y=vec1.y/length1}
	local unitVector2 = {x=vec2.x/length2, y=vec2.y/length2}
	local dotproduct = unitVector1.x * unitVector2.x + unitVector1.y * unitVector2.y
	if math.abs(dotproduct + 1) < 0.001 then
		result = true
	end
	return result
end

-- Math & Geometry
-----------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------
-- LibXL


-- libXL API only supports these named constants for setting colors, but AF gives out colors as RGB floats (?).
-- Try to do an approximate conversion to these constants. A quick google search suggests that computing the 'distance' between
-- the constant color values and the given color could be the method of choice...

-- Table 'Color Palette, Excel' from:
-- http://dmcritchie.mvps.org/excel/colors.htm
-- These seem to be the same as in libXL 'Color' enum.
local gCOLORS = {
--    color enum    r_u8 g_u8 b_u8 
	{ 8,            0,   0,   0   }, -- BLACK
	{ 9,            255, 255, 255 }, -- WHITE
	{ 10,           255, 0,   0   }, -- RED
	{ 11,           0,   255, 0   }, -- BRIGHTGREEN
	{ 12,           0,   0,   255 }, -- BLUE
	{ 13,           255, 255, 0   }, -- YELLOW
	{ 14,           255, 0,   255 }, -- PINK
	{ 15,           0,   255, 255 }, -- TURQUOISE
	{ 16,           128, 0,   0   }, -- DARKRED
	{ 17,           0,   128, 0   }, -- GREEN
	{ 18,           0,   0,   128 }, -- DARKBLUE
	{ 19,           128, 128, 0   }, -- DARKYELLOW
	{ 20,           128, 0,   128 }, -- VIOLET
	{ 21,           0,   128, 128 }, -- TEAL
	{ 22,           192, 192, 192 }, -- GRAY25
	{ 23,           128, 128, 128 }, -- GRAY50
	{ 24,           153, 153, 255 }, -- PERIWINKLE_CF
	{ 25,           153, 51,  102 },
	{ 26,           255, 255, 204 },
	{ 27,           204, 255, 255 },
	{ 28,           102, 0,   102 },
	{ 29,           255, 128, 128 },
	{ 30,           0,   102, 204 },
	{ 31,           204, 204, 255 },
	{ 32,           0,   0,   128 },
	{ 33,           255, 0,   255 },
	{ 34,           255, 255, 0   },
	{ 35,           0,   255, 255 },
	{ 36,           128, 0,   128 },
	{ 37,           128, 0,   0   },
	{ 38,           0,   128, 128 },
	{ 39,           0,   0,	  255 },
	{ 40,           0,   204, 255 },
	{ 41,           204, 255, 255 },
	{ 42,           204, 255, 204 },
	{ 43,           255, 255, 153 },
	{ 44,           153, 204, 255 },
	{ 45,           255, 153, 204 },
	{ 46,           204, 153, 255 },
	{ 47,           255, 204, 153 },
	{ 48,           51,  102, 255 },
	{ 49,           51,  204, 204 },
	{ 50,           153, 204, 0   },
	{ 51,           255, 204, 0   },
	{ 52,           255, 153, 0   },
	{ 53,           255, 102, 0   },
	{ 54,           102, 102, 153 },
	{ 55,           150, 150, 150 },
	{ 56,           0,   51,  102 },
	{ 57,           51,  153, 102 },
	{ 58,           0,   51,  0   },
	{ 59,           51,  51,  0   },
	{ 60,           153, 51,  0   },
	{ 61,           153, 51,  102 },
	{ 62,           51,  51,  153 },
	{ 63,           51,  51,  51  },
}
-- Convert to named constant, returns COLOR_AUTO if all else fails
function LibxlColor(r_u8, g_u8, b_u8)
     -- COLOR_DARKBLUE_CL, COLOR_PINK_CL, COLOR_YELLOW_CL, COLOR_TURQUOISE_CL, COLOR_VIOLET_CL, COLOR_DARKRED_CL, COLOR_TEAL_CL,
     -- COLOR_BLUE_CL, COLOR_SKYBLUE, COLOR_LIGHTTURQUOISE, COLOR_LIGHTGREEN, COLOR_LIGHTYELLOW, COLOR_PALEBLUE, COLOR_ROSE, COLOR_LAVENDER,
     -- COLOR_TAN, COLOR_LIGHTBLUE, COLOR_AQUA, COLOR_LIME, COLOR_GOLD, COLOR_LIGHTORANGE, COLOR_ORANGE, COLOR_BLUEGRAY, COLOR_GRAY40,
     -- COLOR_DARKTEAL, COLOR_SEAGREEN, COLOR_DARKGREEN, COLOR_OLIVEGREEN, COLOR_BROWN, COLOR_PLUM, COLOR_INDIGO, COLOR_GRAY80,
     -- COLOR_DEFAULT_FOREGROUND = 0x0040, COLOR_DEFAULT_BACKGROUND = 0x0041, COLOR_TOOLTIP = 0x0051, COLOR_NONE = 0x7F, COLOR_AUTO = 0x7FFF};

	-- take from color table
	local color = gCOLORS[0]
	local distsqr =  1000000

	-- toLog(string.format("Color: %s %s %s", tostring(r_u8), tostring(g_u8), tostring(b_u8)))

	for key,c in pairs(gCOLORS) do
		local r = c[2] - r_u8
		local g = c[3] - g_u8
		local b = c[4] - b_u8

		local dsqr = r * r + g * g + b * b

		if dsqr < distsqr then
			-- toLog(string.format("%s:\t%s %s %s ... %s < %s", tostring(key), tostring(r), tostring(g), tostring(b), tostring(dsqr), tostring(distsqr)))
			distsqr = dsqr
			color = c
		end
	end

	return color[1]
end


-- Creates a libXL book object based on file extension and template name
-- After modifications are done: call book:save(fileName) and book:release()
function LibxlCreateBook(fileExt, templateName)
	local book

	if fileExt == ".xls" then
		book = xl.create_book()
		gXlsx=false
	else
		book = xl.create_xml_book()
		gXlsx=true
	end

	if book == nil then
		af.RaiseError("libXL failed to create a new Excel workbook")
	end

	if not book:set_locale("UTF-8") then
		af.RaiseError("Failed to set Excel workbook locale to UTF-8")
	end

	if (book:open(ac_mbstoutf8(templateName)) == false) then
		af.RaiseError("Failed to open Excel workbook template `" .. templateName .. "`")
	end

	if gXlsx then
		book:set_rgb_mode(1)
	end

	return book
end


-- LibXL interface to format different values BEG
-- rows and col numbering start from zero, set gtblLibxlFormats to nil when 

gtblLibxlFormats=nil		-- Assume we are working on single book - created formats here: key=format str unique to the style, value=libxl Lua-interface format user-data. Formats are like AC attributes reused in many cells

function LibxlClean()
	gtblLibxlFormats=nil
end


-- Creates new format or uses old ones
function LibxlGetFormat(book, numFormat, botLine)
	local s, tblFormat

	if gtblLibxlFormats==nil then
		gtblLibxlFormats={}
	end

	s=""
	if numFormat then
		s=s .. "num=" .. numFormat
	end
	if botLine then
		s=s .. "bot=true"
	end

	tblFormat=gtblLibxlFormats[s]
	if not tblFormat then
		-- Create format to libxl
		tblFormat = book:add_format()
		if numFormat then
			local fmt

			fmt = book:add_custom_num_format(numFormat)
			tblFormat:set_num_format(fmt)
		end
		if botLine then
			tblFormat:set_borderbot(1)
		end
		gtblLibxlFormats[s]=tblFormat
--toLog(string.format("fmt=%s\n", s))
	end
	return tblFormat
end


-- botLine	true=add bottom line to cell, false=nope
function LibxlMbsToCell(book, sheet, row0, col0, str, botLine)
	if not gScriptUtf8 or gScriptUtf8~=1 then
		str=ac_mbstoutf8(str)
	end
	sheet:write_str(row0, col0, str)

	if botLine then
		sheet:set_format(row0, col0, LibxlGetFormat(book, nil, true))
	end
end


-- botLine	true=add bottom line to cell, false=nope
function LibxlNumToCell(book, sheet, row0, col0, num, botLine)
	sheet:write_num(row0, col0, num)

	if botLine then
		sheet:set_format(row0, col0, LibxlGetFormat(book, nil, true))
	end
end


-- valtype="length"| "angle" | "area" | "volume"
-- pref="work", "dim"or "calc" 
function LibxlNumToCellUnit(book, sheet, row0, col0, numval, valtype, pref, botLine)
	local typenum, unitstr, mul, decimals, s

	typenum, unitstr, mul, decimals=ac_environment("units", valtype, pref)
	if mul and mul~=0.0 then
		-- Write as number
		sheet:write_num(row0, col0, numval*mul)

		-- Set format - first create format string and maintain those as attributes of the book (key=format str, value=format number)
		s="0"
		if decimals and decimals>0 then
			s=s .. "."
			while decimals>0 do
				s=s .. "0"
				decimals=decimals-1
			end
		end

		sheet:set_format(row0, col0, LibxlGetFormat(book, s, botLine))

	else
		-- Write as string
		s=ac_environment ("ntos", numval, valtype, pref)
		LibxlMbsToCell(book, sheet, row0, col0, s, botLine)
--toLog(string.format("str=%s", s))
	end
end

function LibxlDimLenToCell(book, sheet, row0, col0, numval, botLine)
	LibxlNumToCellUnit(book, sheet, row0, col0, numval, "length", "dim", botLine)
end

function LibxlCalcLenToCell(book, sheet, row0, col0, numval, botLine)
	LibxlNumToCellUnit(book, sheet, row0, col0, numval, "length", "calc", botLine)
end

function LibxlAreaToCell(book, sheet, row0, col0, numval, botLine)
	LibxlNumToCellUnit(book, sheet, row0, col0, numval, "area", "calc", botLine)
end

function LibxlVolToCell(book, sheet, row0, col0, numval, botLine)
	LibxlNumToCellUnit(book, sheet, row0, col0, numval, "volume", "calc", botLine)
end

-- LibXL interface to format different values END

-- LibXL
-----------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------
-- Machinings constants from FrameMc.h

EMcNone                 = 0
EMcAngledBegOld		    = 100
EMcAngledBeg		    = 101
EMcAngledBegTenonOld    = 110
EMcBegHiddenShoe	    = 111
EMcAngledBegTenonMort   = 112		-- New version - also general female at the end of the part
EMcJointBeg			    = 113
EMcVCutBeg			    = 114
EMcAngledEndOld		    = 200
EMcAngledEnd		    = 201
EMcAngledEndTenonOld    = 210
EMcEndHiddenShoe	    = 211
EMcAngledEndTenonMort   = 212		-- New version - also general female at the end of the part
EMcJointEnd			    = 213
EMcVCutEnd			    = 214
EMcBegFirst             = 100
EMcBegLast              = 199
EMcEndFirst             = 200
EMcEndLast              = 299
