-- Nailing script that marks to the current boarding layer no nailings based on the next boarding layer's edges inside current boarding layer

g_safetyDist = 0.015		-- How much to leave empty to _both_ sides of a board edge

-- input:
-- gtblSources, 1-based array of source elements each having fields:
-- istarget (if flagged as target layer)
-- typenum, 1=plank, 4=board
-- guidmaster
-- guidproj, nil=not started from projection


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

	-- T‰ss‰ hyp‰t‰‰n suoraan vakion laskentaan
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


-- Finds the related ArchiFrameElement-object for the target layer (must be single element layer)
function FindSourceElem()
	local i,v,info

	for i,v in ipairs(gtblSources) do
		if v.istarget then
			info=af_request("plankinfo", v.guidmaster)
			if info.ownerelemguid then
				return info.ownerelemguid
			end
		end
	end
	
	return nil
end


-- Adds edges from single polygon to tblEdges, does not handle arcs
function GetPolyEdgesSingle(tblPolyPoints, tblEdges)
	local i, v, begInd, x, y, prev


	begInd=1
	prev=nil
	for i,v in ipairs(tblPolyPoints) do
		if prev then
			tblEdges[#tblEdges +1] =
			{
				x1 = prev.x,
				y1 = prev.y,
				x2 = v.x,
				y2 = v.y
			}
		end

		prev=v

		if v.isendcontour then
			-- Duplicate start point
			tblEdges[#tblEdges +1] =
			{
				x1 = v.x,
				y1 = v.y,
				x2 = tblPolyPoints[begInd].x,
				y2 = tblPolyPoints[begInd].y
			}

			if v.isendpolygon then
				break
			end
			begInd=i+1
			prev=nil
		end
	end
end


-- Adds edges from polygon list to tblEdges, does not handle arcs
-- tblPolys is what you get from "getpoly"
-- Returns 1-based table of edges each having x1,y1, x2,y2
function GetPolyEdgesList(tblPolys)
	local v, tblEdges

	tblEdges={}
	for _,v in ipairs(tblPolys.poly) do
		GetPolyEdgesSingle(v, tblEdges)
	end
	return tblEdges
end



-- Finds polygon edges from polyNext that are inside polysCurr, returns table of lines each having fields x1,y1, x2,y2
function FindPolyEdgesInside(polysCurr, polysNext)
	local tblEdges, v, tblx, tblRes

	-- Get edges of the next polygon and get parts inside current
	tblEdges=GetPolyEdgesList(polysNext)
--DumpTbl(tblEdges)
	tblRes={}
	for _,v in ipairs(tblEdges) do
		tblx = ac_geo("linepolyx", v.x1, v.y1, v.x2, v.y2, polysCurr.poly, false, false)		-- last param onEdgeInside=false
		if tblx then
			local v2

			for _,v2 in ipairs(tblx) do
				table.insert(tblRes, v2)
			end
		end
	end

	return tblRes
end


function ProjectToLocal(pa, pb, pc, pd, sideTarget, xsource, ysource, sideSource)
	local	x, y, z

	-- First calc 3D pt for source
	x = sideSource.origc.x + xsource * sideSource.vecx.x + ysource * sideSource.vecy.x
	y = sideSource.origc.y + xsource * sideSource.vecx.y + ysource * sideSource.vecy.y
	z = sideSource.origc.z + xsource * sideSource.vecx.z + ysource * sideSource.vecy.z

	-- Project to target
	x, y, z = ProjectToPlane(x, y, z, pa, pb, pc, pd)

-- DEBUG BEG
--	if math.abs(DistFromPlane(x, y, z, pa, pb, pc, pd)) > 0.0001 then
--		ac_environment("tolog", string.format("ProjectToLocal, err1"))
--	end
-- DEBUG END

	-- Then get the local coords
	x = x - sideTarget.origc.x
	y = y - sideTarget.origc.y
	z = z - sideTarget.origc.z

	local rx, ry

	rx = CalcDot3D( x, y, z, sideTarget.vecx.x, sideTarget.vecx.y, sideTarget.vecx.z )
	ry = CalcDot3D( x, y, z, sideTarget.vecy.x, sideTarget.vecy.y, sideTarget.vecy.z )

--ac_environment("tolog", string.format("xsource=%f, ysource=%f rx=%f, ry=%f", xsource, ysource, rx, ry))
	return rx, ry
end


-- Adds no nailings for each tblLinesx that intersect target. Converts tblLinesx to target's coordinate system
function AddNoNailings(target, tblLinesx, infoElem)
	local infoTarget, sideTarget, pa, pb, pc, pd, v, x1, y1, x2, y2

	-- Get coord world of the target (front surface for board)
	infoTarget = af_request("plankinfo", target.guidmaster)
	sideTarget = infoTarget.tblSides[2]
	pa, pb, pc, pd = MakePlaneNormal(sideTarget.vecz.x, sideTarget.vecz.y, sideTarget.vecz.z, sideTarget.origc.x, sideTarget.origc.y, sideTarget.origc.z)

	-- Then scan the lines
	for _,v in ipairs(tblLinesx) do
		-- Convert the middle line to local
		x1, y1 = ProjectToLocal(pa, pb, pc, pd, sideTarget, v.x1, v.y1, infoElem.tblSides[2])
		x2, y2 = ProjectToLocal(pa, pb, pc, pd, sideTarget, v.x2, v.y2, infoElem.tblSides[2])

		-- Then calc normal vec to right for the line
		local dx, dy, len

		dx = x2 - x1
		dy = y2 - y1
		len = math.sqrt(dx*dx + dy*dy)
		if len>0.001 then
			dx = dx / len
			dy = dy / len

			x1 = x1 - dx * g_safetyDist		-- Extend beg
			y1 = y1 - dy * g_safetyDist
			x2 = x2 + dx * g_safetyDist		-- Extend end
			y2 = y2 + dy * g_safetyDist
			dx, dy = dy, -dx		-- To right

			-- Then form four point polygon to exlude area
			local tblPoints = {}

			tblPoints[1] = { x =  x1 + dx * g_safetyDist, y =  y1 + dy * g_safetyDist }
			tblPoints[2] = { x =  x2 + dx * g_safetyDist, y =  y2 + dy * g_safetyDist }
			tblPoints[3] = { x =  x2 - dx * g_safetyDist, y =  y2 - dy * g_safetyDist }
			tblPoints[4] = { x =  x1 - dx * g_safetyDist, y =  y1 - dy * g_safetyDist }
--DumpTbl(tblPoints)
			local t

			t = {}
			t.ptr=target.guidmaster
			t.prio=90		-- Never nailings here
			t.side=2
			t.poly = tblPoints

			gtblExclude[#gtblExclude+1]=t
		end
	end
end


-- Handles adding custom no nailings areas, nailing lines and point nailings
function OnPreNailing()
	local guidElem, infoElem
--ac_environment("tolog", string.format("Nailing script, %d items", #gtblSources))

	guidElem=FindSourceElem()
--ac_environment("tolog", string.format("Nailing script: Source element=%s, #gtblSources=%d", tostring(guidElem), #gtblSources))
	if not guidElem then
		return
	end

	-- Get our coordinate world
	infoElem=af_request("plankinfo", guidElem)
	infoElem.vecy, infoElem.vecz = infoElem.vecz, infoElem.vecy		-- Make it a camera having z-axis as the watching dir

	-- Find the next boarding layer
	local q, t

	t={}
	t.quant=0
	q = af_request("elem_quantities", guidElem, 1, t)
	if not q then
		return
	end

	local i, icore, icurr, inext

	for i,v in ipairs(q.tblelems) do
		if v.guid == guidElem then
			icurr=i
		end

		if v.elemtype=="core" then
			icore=i
		end
	end

	if not icore or not icurr then
		ac_environment("tolog", "Nailing script: No core or current layer found, skipped")
		return
	end

	if icore<icurr then
		inext=icurr+1
	elseif icore>icurr then
		inext=icurr-1
	else
		-- Current is the core, check if either next or previous is a boarding layer
		if icurr+1<#q.tblelems and q.tblelems[icurr+1].tblboards then
			inext=icurr+1
		elseif icurr-1>0 and q.tblelems[icurr-1].tblboards then
			inext=icurr-1
		else
			return
		end
	end

	if not inext or inext<1 or inext>#q.tblelems then
		return
	end

--ac_environment("tolog", string.format("Nailing script: Current=%d, Core=%d, Next=%d", icurr, icore, inext))

	-- Get polygons for current layer
	local polysCurr, polysNext, tblLinesx

	t={}
	t.side = 2
	t.fromboard = 1
	t.givelist = 1
	t.camera = infoElem

	polysCurr = af_request ("getpoly", t, q.tblelems[icurr].guid)
	polysNext = af_request ("getpoly", t, q.tblelems[inext].guid)

--ac_environment("tolog", "curr")
--DumpTbl(polysCurr)
--ac_environment("tolog", "next")
--DumpTbl(polysNext)

	tblLinesx = FindPolyEdgesInside(polysCurr, polysNext)
	gtblExclude={}

	-- Put found lines to each target using target's coordinate system
	local i,v,info

	for i,v in ipairs(gtblSources) do
		if v.istarget then
			AddNoNailings(v, tblLinesx, infoElem)
		end
	end

end
