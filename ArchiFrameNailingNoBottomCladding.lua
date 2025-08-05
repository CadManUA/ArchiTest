-- Example nailing script that marks the lowest cladding piece(s) not to be nailed

-- input:
-- gtblSources, 1-based array of source elements each having fields:
-- istarget (if flagged as target layer)
-- typenum, 1=plank, 4=board
-- guidmaster
-- guidproj, nil=not started from projection


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


-- Marks the lowest cladding piece(s) with exclude area(s)
function ExcludeHorBottom(tblClad)
	-- Then mark all lowest cladding pieces not to have nailings
	local curr, i, v
	
	i=1
	repeat
		curr=tblClad[i]
		v={}
		v.ptr=tblClad[i].ptr
		v.prio=9		-- Let user place a line that will cause nailing line even over this exclude rule
		v.side=2
		v.x1=0
		v.y1=0
		v.x2=curr.tblSides[2].dx
		v.y2=curr.tblSides[2].dy

--ac_environment("tolog", string.format("Exclude plank v.x1=%f, v.y1=%f, v.x2=%f, v.y2=%f", v.x1, v.y1, v.x2, v.y2))
		gtblExclude[#gtblExclude+1]=v
		i=i+1
	until (i>#tblClad or math.abs(tblClad[i].elemdata.bz1 - tblClad[1].elemdata.bz1)>0.001)
end


-- Handles adding custom no nailings areas, nailing lines and point nailings
function OnPreNailing()
	local guidElem, infoElem, i, v, info, tblClad, tblStud
--ac_environment("tolog", string.format("Nailing script, %d items", #gtblSources))

	guidElem=FindSourceElem()
	if not guidElem then
		-- Perhaps cladding not exploded - do not report anything
		return
	end

	-- Make table of the horizontal cladding pieces using surface 2/front
	infoElem=af_request("plankinfo", guidElem)
	tblClad={}
	tblStud={}
	for i,v in ipairs(gtblSources) do
		info=af_request("plankinfo", v.guidmaster, infoElem)
		if v.istarget then
			if math.abs(info.elemdata.z1 - info.elemdata.z2)<0.001 then
				tblClad[#tblClad+1]=info		-- It is horizontal
			end
		else
			-- Piece behind
			if math.abs(info.elemdata.x1 - info.elemdata.x2)<0.001 then
				tblStud[#tblStud+1]=info		-- It is vertical
			end
		end
	end

	if #tblClad==0 then
		-- Unexcpected?
		return
	end

	-- Sort by level in the element
	table.sort(tblClad, function (e1, e2)
		local d
		
		d=e1.elemdata.bz1 - e2.elemdata.bz1
		if math.abs(d)>0.001 then
			return d<0
		end
		return false		-- Equal
	end)

	gtblExclude={}
	ExcludeHorBottom(tblClad)

	-- Example line
	if false then
		local t

		t={}
		t.ptr=tblClad[1].ptr
		t.prio=99				-- Also over user's exclude fills (which has prio 20)
		t.side=2
		t.spacing=0.050
		t.x1=0.500
		t.y1=0.020
		t.x2=1.200
		t.y2=0.080
		t.nailgun=123

		gtblLines={}
		gtblLines[1]=t
	end
		
	-- Example nail point
	if false then
		local t

		t={}
		t.ptr=tblClad[1].ptr
		t.prio=99				-- Also over user's exclude fills (which has prio 20)
		t.side=2
		t.x=0.100
		t.y=0.050
		t.nailgun=123

		gtblPoints={}
		gtblPoints[1]=t
	end
end
