-- Example object translation script

-- Handles translating object ArchiFrameElemStamp1
-- Could be handled without Lua but for example's sake
function DoElemStamp(guid, sourceLang, destLang)
	local names, i, changes, s

	names={}
	if destLang=="Swedish" then
		names[1]="ID"
		names[2]="Typ"
		names[3]="Datum"
		names[4]="Projekt"
		names[5]="Designer"
		names[6]="Projekt nr"
	elseif destLang=="Finnish" then
		names[1]="ID"
		names[2]="Tyyppi"
		names[3]="Pvm"
		names[4]="Projekti"
		names[5]="Suunnittelija"
		names[6]="Projektin nro"
	else
		names[1]="ID"
		names[2]="Type"
		names[3]="Date"
		names[4]="Project"
		names[5]="Designer"
		names[6]="Project num"
	end

	ac_objectopen(guid)
	for i=1,6 do
		s=string.format("iName%d", i)
		if ac_objectget(s)~=names[i] then
--ac_environment("tolog", "CHANGED")
			ac_objectset(s, names[i])
		end
	end
	ac_objectclose()
end
