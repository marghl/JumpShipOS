delay = 60
timeout = 10
cores = 6

if event.type == "program" then
	interrupt(2 + heat)
	mem.core = 1
end

function data_format(m,c)
	if type(m) == "table" then
	local t={}
	local r={}
	for k, v in ipairs(m.rods) do
		if v > 0 and v < 10 then
			table.insert(r, "0"..tostring(v))
		elseif v == 0 then
			table.insert(r, "  ")
		else
			table.insert(r, tostring(v))
		end
	end
	if m.enabled then
		table.insert(t,c)
		table.insert(t,"State:  active")
	else
		table.insert(t,"State:  idle")
	end
	bt = math.floor((m.burn_time / 8640) +0.5) / 10
	table.insert(t,"Days:   "..tostring(bt))
	table.insert(t,"Damage: "..tostring(m.structure_accumulated_badness))
	table.insert(t,"Rods:      "..r[1].."|"..r[2].."|"..r[3])
	table.insert(t,"           "..r[4].."|"..r[5].."|"..r[6])
      
	return(table.concat(t,"\n"))
   else
	return("ERROR:\nExpected table\nGot "..type(m))
   end
end

if event.type == "interrupt" then
	digiline_send("core_"..mem.core,{command="get"})
	mem.core = mem.core + 1
	if mem.core > cores then mem.core = 1 end
	interrupt(timeout)
end

if event.type == "digiline" then
	m = "mon_"..string.sub(event.channel,6,-1)
	digiline_send(m,data_format(event.msg,event.channel))
end