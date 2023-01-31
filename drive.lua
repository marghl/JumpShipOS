-- Basic Pandorabox tools

-- ########
-- TODO:
-- Current coordinates in LUAc doesn't reset when a jump was requested
-- but not executed (e.g. obstructed, Refresh+Reset fixes the state)
-- The JD doesn't always send a success message. Add a reliable way to
-- determine if a jump happened.
-- possible close: global pos?

-- BOOTSTRAP
-- Config just below

-- bootstrapping the networks


-- Touchscreen setup for debug. Change ONLY max_lines and monitor channel!



if event.type == "program" then
    -- the memory for locations
   mem.m = mem.m or {}
   mem.m.locations = mem.m.locations or {}
   mem.m.location_num = mem.m.location_num or 1
   mem.m.group = mem.m.group or {}
   mem.m.filter = ""
   mem.linebuffer = mem.linebuffer or {}
   mem.linebuffer.jumpdrive = mem.linebuffer.jumpdrive or {"JumpDriveLog"}
   mem.instant_jump = mem.instant_jump or {distance = 50}
    mem.events = mem.events or {count = 0}

    mem.minterrupt = mem.minterrupt or {}
   mem.minterrupt.label = mem.minterrupt.label or ""
end
-- END
local debug = true
-- CONFIGURE
-- TODO: clean this mess up

-- USER PERMISSIONS
local permission = {
    authorised_users = {"marghl"},
    ignore = true    -- leave this to false!
                     --if true no permission will be checked!
}

-- MODULES
local debug = true -- debug uses time and gives penalty. set to false if not needed
local help = false -- Need help? Not supported for now, ask user marghl in game

-- QUARRY

local jumpdrive = {channel = "jumpdrive"}

-- linebuffer to setup section


-- Touchscreen
-- Change ONLY channel
-- pages MUST contain at least "Drive" and "System"
local touchscreen = {
    channel = "ts",
    -- pages = {"Drive", "Memory", "Quarry", "System"},
    pages = {"Drive", "Memory","System"},
    permissions = {"Open", "Users", "Locked"},
    linebuffer = {
        jumpdrive = {memory = mem.linebuffer.jumpdrive , max_lines = 20}
        --quarry = {memory = mem.linebuffer.quarry, max_lines = 20}
    }
}
local event_catcher = {
        touchscreen = {channel = "ts_ec", max_lines = 30},
        monitor = {channel = "mon_ec"}
    }
if debug then
    table.insert(touchscreen.pages, "Events")

end
if help then
    table.insert(touchscreen.pages, "Help")
end



-- ########
-- Demo Code
-- ########

-- ########
-- Helper functions
-- ########

-- permission check to helper functions
permission.check = function(user)
    if permission.ignore == true then
        return true
    end
    local is_allowed = false
    for i, u in ipairs(permission.authorised_users) do
        if user == u then
            is_allowed = true
            break
        end
    end
   return is_allowed
end


function minterrupt(time,label)
-- i NEED iid!
         mem.minterrupt.label = label
         interrupt(time)
            return
end

function table_concat(t1, t2)
-- by Ruggila from "I wish i had an item"
    res = {}
    for i, v in ipairs(t1) do
        res[i] = v
    end
    local n = #res
    for i, v in ipairs(t2) do
        res[i + n] = v
    end
    return res
end

function filter_locations()
-- by Ruggila from "I wish i had an item"
    --if mem.m.locations ~= {} then
    -- get list of recipes in a nice user format
    local grouped = {}
    local ungrouped = {}
    local filter = mem.m.filter:lower()
    for k, _ in pairs(mem.m.locations) do
      local k_ = k:lower()
        local s = mem.m.group[k]
        if s then
            s = s .. " " .. k
            s_ = s:lower()
            if filter == "" or s_:find(filter, 1, true) then
                table.insert(grouped, s)
            end
        else
            if filter == "" or k_:find(filter, 1, true) then
                table.insert(ungrouped, k)
            end
        end
    end
    --end
    table.sort(grouped)
    table.sort(ungrouped)
    mem.m.targets = table_concat(grouped, ungrouped)
end

if event.type == "program" then
    filter_locations()
end
local character = {}
character.is_numeric = function(sChar)
    if sChar:byte() >= 48 and sChar:byte() <= 57 then
        return true
    else
        return false
    end
end

local coordinates = {names = {"x", "y", "z"}}

function coordinates:to_table(sInput)
    local tNumberList = {}
    if type(sInput) == "string" then
        local bContinuous = false
        for nChar = 1, #sInput do
            local nByte = sInput:byte(nChar)
            -- A new numerical string starts - potentially - ignoring repetitions of "-"
            if
                (bContinuous == false and (nByte == 45 or (nByte >= 48 and nByte <= 57))) or
                    (nByte == 45 and sInput:byte(nChar - 1) ~= 45)
             then
                -- Override previous non valid numerical string "-"
                if #tNumberList > 0 and tNumberList[#tNumberList] == "-" then
                    tNumberList[#tNumberList] = string.char(nByte)
                else
                    table.insert(tNumberList, string.char(nByte))
                end
                bContinuous = true
            elseif bContinuous and (nByte >= 48 and nByte <= 57) then
                tNumberList[#tNumberList] = tostring(tNumberList[#tNumberList]) .. string.char(nByte)
            elseif nByte ~= 45 then
                bContinuous = false
            end
        end
        -- Remove tailing non valid numerical string "-"
        if tNumberList[#tNumberList] == "-" then
            tNumberList[#tNumberList] = nil
        end
    end
    local tOutput = {}
    for i, name in ipairs(self.names) do
        tOutput[name] = tonumber(tNumberList[i] or "0")
    end
    return tOutput
end

function coordinates:to_string(coordinate_table)
    if type(coordinate_table) == "table" then
        return coordinate_table.x .. "," .. coordinate_table.y .. "," .. coordinate_table.z
    end
end

local function get_string(data, maxdepth)
    local maxdepth = maxdepth or 3
    if type(data) == "string" then
        return data
    elseif type(data) == "table" and maxdepth > 0 then
        local oString = "{"
        for k, v in pairs(data) do
            local val = v
            if type(v) == "table" then
                val = get_string(val, maxdepth - 1)
            end
            oString = oString .. tostring(k) .. "=" .. tostring(val) .. ", "
        end
        return string.sub(oString, 1, -3) .. "}"
    else
        return tostring(data)
    end
    return "Something went wrong!"
end

local function get_time_string(datetable)
    local date_table = datetable or os.datetable()
    local date_string = date_table.year .. "." .. date_table.month .. "." .. date_table.day
    local time_string = date_table.hour .. ":" .. date_table.min .. ":" .. date_table.sec
    return date_string .. " " .. time_string
end

local function merge_shallow_tables(t1, t2)
    local t3 = {}
    for k, v in pairs(t1) do
        t3[k] = v
    end
    for k, v in pairs(t2) do
        t3[k] = v
    end
    return t3
end

local function add_line_to_buffer(linebuffer, message)
    -- expects linebuffer to be an array with keys memory (link to line table in mem) and max_lines (integer)
    if type(message) ~= "string" then
        message = get_string(message)
    end
    table.insert(linebuffer.memory, 1, message)
    while table.maxn(linebuffer.memory) > linebuffer.max_lines do
        table.remove(linebuffer.memory)
    end
end

local function touchscreen_add_line(msg)
    table.insert(mem.event_catcher.touchscreen_line_table, 1, tostring(mem.events.count) .. ": " .. tostring(msg))
    while table.maxn(mem.event_catcher.touchscreen_line_table) > event_catcher.touchscreen.max_lines do
        table.remove(mem.event_catcher.touchscreen_line_table)
    end
end

local function send_to_monitors(message)
    -- Omitt appending it's own and other "display" type content to avoid doubling the output
    if message ~= nil and message.msg ~= nil and message.msg.display ~= nil then
        message.msg.display = "<cut>"
    end

    if message.channel then
        digiline_send(event_catcher.monitor.channel, message.channel)
    elseif message.type then
        digiline_send(event_catcher.monitor.channel, message.type)
    else
        digiline_send(event_catcher.monitor.channel, get_string(message, 1))
    end
    if message ~= nil and message.type == "interrupt" then
        message.time = get_time_string()
    end
    touchscreen_add_line(get_string(message))
    digiline_send(
        event_catcher.touchscreen.channel,
        {
            {command = "clear"},
            {
                command = "addtextarea",
                name = "display",
                label = "Events:",
                default = table.concat(mem.event_catcher.touchscreen_line_table, "\n"),
                X = 0.2,
                Y = 0.1,
                W = 10.2,
                H = 9.5
            }
        }
    )
end

-- ########
-- Touchscreen
-- ########
-- Original code by FeXoR unless stated otherwise
-- elements moved by marghl to be usable on smaller screen
-- (we are not all rich and famous ;P)
local function update_page(page)
    if touchscreen.pages[mem.page] == page then
        local message = {
            {command = "clear"},
            {command = "set", real_coordinates = true, width = 11, height = 14},
            {command = "addlabel", label = "Page:", X=0.5,Y=0.5},
            {
                command = "addtextlist",
                name = "page",
                listelements = touchscreen.pages,
                selected_id = mem.page,
                X = 0.5,
                Y = 1,
                W = 2,
                H = 2
            },
            {command = "addlabel", label = "Lock:", X=0.5,Y=11.5},
            {
                command = "addtextlist",
                name = "lock",
                listelements = touchscreen.permissions,
                selected_id = mem.ts_lock,
                X = 0.5,
                Y = 12,
                W = 2,
                H = 1.6
            }
        }
        -- Events
        if page == "Events" then
            table.insert(
                message,
                {
                    command = "addtextarea",
                    name = "display",
                    label = "Events:",
                    default = table.concat(mem.event_catcher.touchscreen_line_table, "\n"),
                    X = 1.5,
                    Y = 0.55,
                    W = 11.25,
                    H = 9.3
                }
            )
        elseif page == "Drive" then
            table.insert(
                message,
                {command = "addbutton", name = "request_data", label = "Refresh", X = 9, Y = 5.8, W = 1.5, H = 1}
            )

            table.insert(
                message,
                {
                    command = "addlabel",
                    X = 3,
                    Y = 7,
                    5,
                    label = "Distance: " ..
                        tostring(math.ceil(mem.jumpdrive.distance)) ..
                            "  |  " ..
                                "EU needed: " ..
                                    tostring(math.ceil(mem.jumpdrive.power_req)) ..
                                        " stored: " .. tostring(math.ceil(mem.jumpdrive.powerstorage))
                }
            )
            -- Radius removed by marghl after an nuclear incident due to jump
            -- with radius set too small. TODO: move radius to "System" page maybe
            -- add something something scoutshipseperate
            --table.insert(message, {command = "addlabel", label = "Radius >", X=11.2,Y=0.5})
            table.insert(message, {command = "addlabel", label = "InstaJump", X = 3, Y = 1})
            table.insert(message, {command = "addlabel", label = "+", X = 8.2, Y = 2.3})
            table.insert(
                message,
                {command = "addbutton", name = "jump_step_increase", label = "1", X = 8.5, Y = 1.75, W = 1, H = 1}
            )
            table.insert(
                message,
                {
                    command = "addfield",
                    name = "jump_step_value",
                    label = "Distance",
                    default = tostring(mem.instant_jump.distance),
                    X = 6.5,
                    Y = 2.4,
                    W = 1.4,
                    H = 0.7
                }
            )
            table.insert(message, {command = "addlabel", label = "-", X = 8.2, Y = 3.3})
            table.insert(
                message,
                {command = "addbutton", name = "jump_step_decrease", label = "1", X = 8.5, Y = 2.75, W = 1, H = 1}
            )

            table.insert(
                message,
                {
                    command = "addbutton_exit",
                    name = "xi",
                    label = (help and "@ E") or "E",
                    X = 3,
                    Y = 1.75,
                    W = 1,
                    H = 1
                }
            )
            table.insert(
                message,
                {
                    command = "addbutton_exit",
                    name = "xd",
                    label = (help and "@ W") or "W",
                    X = 3,
                    Y = 2.75,
                    W = 1,
                    H = 1
                }
            )
            table.insert(
                message,
                {command = "addbutton_exit", name = "yi", label = (help and "@ ^") or "^", X = 4, Y = 1.5, W = 1, H = 1}
            )
            table.insert(
                message,
                {command = "addbutton_exit", name = "yd", label = (help and "@ v") or "v", X = 4, Y = 3, W = 1, H = 1}
            )
            table.insert(
                message,
                {
                    command = "addbutton_exit",
                    name = "zi",
                    label = (help and "@ N") or "N",
                    X = 5,
                    Y = 1.75,
                    W = 1,
                    H = 1
                }
            )
            table.insert(
                message,
                {
                    command = "addbutton_exit",
                    name = "zd",
                    label = (help and "@ S") or "S",
                    X = 5,
                    Y = 2.75,
                    W = 1,
                    H = 1
                }
            )
            table.insert(
                message,
                {command = "addbutton", name = "reset_target", label = "Reset", X = 7.5, Y = 5.8, W = 1.5, H = 1}
            )
            table.insert(
                message,
                {
                    command = "addlabel",
                    label = "Currend Position: " .. coordinates:to_string(mem.jumpdrive.position),
                    X = 3,
                    Y = 0.5
                }
            )
            table.insert(
                message,
                {
                    command = "addfield",
                    name = "target",
                    label = "Target:",
                    default = coordinates:to_string(mem.jumpdrive.target),
                    X = 3,
                    Y = 5,
                    W = 7.5,
                    H = 0.7
                }
            )
            table.insert(
                message,
                {command = "addbutton", name = "set_target", label = "Set", X = 3, Y = 5.8, W = 1.5, H = 1}
            )
            table.insert(
                message,
                {command = "addbutton", name = "simulate", label = "Test", X = 4.5, Y = 5.8, W = 1.5, H = 1}
            )
            table.insert(
                message,
                {
                    command = "addbutton_exit",
                    name = "jump",
                    label = (help and "Jump @") or "Jump",
                    X = 6,
                    Y = 5.8,
                    W = 1.5,
                    H = 1
                }
            )

            table.insert(
                message,
                {
                    command = "addtextarea",
                    name = "display",
                    label = "The Jumpdrive says:",
                    default = table.concat(mem.linebuffer.jumpdrive, "\n"),
                    X = 3,
                    Y = 9,
                    W = 7.5,
                    H = 4.5
                }
            )
        elseif page == "Memory" then
      table.insert(message,{command = "addtextlist",
         label = "subpages",
         name = "subpages",
          X = 0.5,
         Y = 3.5,
         W = 2,
         H = 2,
         listelements =  {"set search" , "save delete" , "backup"},
         selected_id = mem.subpage})
            -- Memory added by marghl
            -- most of this code is from Ruggilas "I wish i had an item"
            table.insert(message, {command = "addlabel", label = "Saved Locations", X = 3, Y = 0.5})
            table.insert(
                message, {
                    command = "addfield",
                    X = 3,
                    Y = 5.1,
                    W = 6,
                    H = 0.8,
                    name = "filt",
                    label = "",
                    default = mem.m.filter or ""
                }
            )
            table.insert(
                message,
                {
                    command = "addtextlist",
                    X = 3,
                    Y = 1,
                    W = 7.5,
                    H = 4,
                    name = "locations_list",
                    label = "",
                    --choices = targets,
                    listelements = mem.m.targets or {},
                    selected_id = mem.m.itemnum or 1
                }
            )
       table.insert(
                message,
                {command = "addbutton", label = "filter", name = "location", X = 9.1, Y = 5.1, W = 1.4, H = 0.8}
            )
       if mem.m.locations[mem.m.item].pos then
         table.insert(message, {command="addlabel",
            label = "Coordinates : "  .. tostring(mem.m.locations[mem.m.item].pos) or "none",
            X= 3,
            Y= 7.2}
      )
      end
           --- move to subpage
      if mem.subpage == 1 then
       table.insert(message, {command = "addbutton",
         label = "set as target" ,
         name = "location",
         X = 3,
         Y = 13,
         W = 7.5,
         H = 0.8}
            )
       else
      table.insert(
                message,
                {command = "addbutton", label = "save", name = "location", X = 9.1, Y = 12.7, W = 1.4, H = 0.8}
            )

            table.insert(
                message,
                {command = "addbutton", label = "delete", name = "location", X = 9.1, Y = 11.7, W = 1.4, H = 0.8}
            )

            table.insert(
                message,
                {command = "addfield", X = 3, Y = 12.7, W = 6, H = 0.8, name = "save", label = "", default = ""}
            )
       table.insert(message, {command = "addlabel", X=3, Y=10,label = "SUBPAGE "..mem.subpage})
       end

        else
        -- handler for missing pages
            table.insert(
                message,
                {
                    command = "addlabel",
                    label = "This page is not yet handled: " .. tostring(touchscreen.pages[mem.page]),
                    X = 4,
                    Y = 4
                }
            )
        end

        digiline_send(touchscreen.channel, message)
    end
end

-- ###########################
-- Handle touchscreen messages
-- ###########################

if event.type == "digiline" and event.channel == touchscreen.channel and event.msg then
    if event.msg.page ~= nil then
        local i_page = tonumber(string.sub(event.msg.page, 5))
        if i_page ~= mem.page then
            mem.page = i_page
       mem.subpage = 1
            update_page(touchscreen.pages[mem.page])
        end
   elseif event.msg.subpages ~= nil then
        local i_subpage = tonumber(string.sub(event.msg.subpages, 5))
        if i_subpage ~= mem.subpagepage then
            mem.subpage = i_subpage
            update_page(touchscreen.pages[mem.page])
        end
    elseif event.msg.lock ~= nil then
        local i_lock = tonumber(string.sub(event.msg.lock, 5))
        if i_lock ~= mem.ts_lock then
            mem.ts_lock = i_lock
            if mem.ts_lock == 1 then
                digiline_send(touchscreen.channel, {command = "unlock"})
                mem.permission.ignore = true
            elseif mem.ts_lock == 2 then
                digiline_send(touchscreen.channel, {command = "unlock"})
                mem.permission.ignore = false
            elseif mem.ts_lock == 3 then
                digiline_send(touchscreen.channel, {command = "lock"})
                mem.permission.ignore = false
            else
                send_to_monitors("Unhandled ts_lock value: " .. tostring(mem.ts_lock))
            end
            update_page(touchscreen.pages[mem.page])
        end
    elseif touchscreen.pages[mem.page] == "Drive" then
        -- FeXoRs code with minor changes by marghl
        local authorised = permission.check(event.msg.clicker)
        local jumpdrive_page_needs_update = false
        local min_jump_step_value = 2 * mem.jumpdrive.radius + 1

        if event.msg.jump_step_value ~= nil then
            if tonumber(event.msg.jump_step_value) < min_jump_step_value then
                mem.instant_jump.distance = min_jump_step_value
            else
                mem.instant_jump.distance = tonumber(event.msg.jump_step_value)
            end
            if tonumber(event.msg.jump_step_value) ~= mem.instant_jump.distance then
                jumpdrive_page_needs_update = true
            end
        end

        if event.msg.radius ~= nil then
            if authorised then
                mem.jumpdrive.radius = 1
                if event.msg.target ~= nil then
                    mem.jumpdrive.target = coordinates:to_table(event.msg.target)
                    digiline_send(
                        jumpdrive.channel,
                        merge_shallow_tables(
                            {command = "set", r = mem.jumpdrive.radius, formupdate = false},
                            mem.jumpdrive.target
                        )
                    )
                else
                    digiline_send(jumpdrive.channel, {command = "set", r = mem.jumpdrive.radius, formupdate = false})
                end
                digiline_send(jumpdrive.channel, {command = "get"})
            else
                send_to_monitors(
                    tostring(event.msg.clicker) .. ": You are not authorised to change the radius. See settings ;)"
                )
            end
        elseif event.msg.key_enter_field ~= nil then
            if event.msg.key_enter_field == "target" then
                mem.jumpdrive.target = coordinates:to_table(event.msg.target)
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "get"})
            elseif event.msg.key_enter_field == "jump_step_value" then
                jumpdrive_page_needs_update = true
            else
                send_to_monitors("Unknown key_enter_field: " .. tostring(event.msg.key_enter_field))
            end
        elseif event.msg.reset_target ~= nil then
            digiline_send(jumpdrive.channel, {command = "reset"})
            digiline_send(jumpdrive.channel, {command = "get"})
        elseif event.msg.set_target ~= nil then
            if event.msg.target ~= nil then
                mem.jumpdrive.target = coordinates:to_table(event.msg.target)
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "get"})
            end
        elseif event.msg.request_data ~= nil then
            mem.jumpdrive.target = coordinates:to_table(event.msg.target)
            digiline_send(
                jumpdrive.channel,
                merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
            )
            digiline_send(jumpdrive.channel, {command = "get"})
        elseif event.msg.simulate ~= nil then
            mem.jumpdrive.target = coordinates:to_table(event.msg.target)
            digiline_send(
                jumpdrive.channel,
                merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
            )
            digiline_send(jumpdrive.channel, {command = "simulate"})
        elseif event.msg.jump ~= nil then
            if authorised then
                mem.jumpdrive.target = coordinates:to_table(event.msg.target)
                --             mem.jumpdrive.target = mem.jumpdrive.position
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        elseif event.msg.jump_step_increase ~= nil then
            local target_jump_step_value = tonumber(event.msg.jump_step_value) + 1
            if target_jump_step_value > min_jump_step_value then
                mem.instant_jump.distance = target_jump_step_value
            else
                mem.instant_jump.distance = min_jump_step_value
            end
            if mem.instant_jump.distance ~= tonumber(event.msg.jump_step_value) then
                jumpdrive_page_needs_update = true
            end
        elseif event.msg.jump_step_decrease ~= nil then
            local target_jump_step_value = tonumber(event.msg.jump_step_value) - 1
            if target_jump_step_value > min_jump_step_value then
                mem.instant_jump.distance = target_jump_step_value
            else
                mem.instant_jump.distance = min_jump_step_value
            end
            if mem.instant_jump.distance ~= tonumber(event.msg.jump_step_value) then
                jumpdrive_page_needs_update = true
            end
        elseif event.msg.xi ~= nil then
            if authorised then
                --             mem.jumpdrive.target = mem.jumpdrive.position
                mem.jumpdrive.target.x = mem.jumpdrive.position.x + mem.instant_jump.distance
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        elseif event.msg.xd ~= nil then
            if authorised then
                --             mem.jumpdrive.target = mem.jumpdrive.position
                mem.jumpdrive.target.x = mem.jumpdrive.position.x - mem.instant_jump.distance
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        elseif event.msg.yi ~= nil then
            if authorised then
                --             mem.jumpdrive.target = mem.jumpdrive.position
                mem.jumpdrive.target.y = mem.jumpdrive.position.y + mem.instant_jump.distance
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        elseif event.msg.yd ~= nil then
            if authorised then
                --             mem.jumpdrive.target = mem.jumpdrive.position
                mem.jumpdrive.target.y = mem.jumpdrive.position.y - mem.instant_jump.distance
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        elseif event.msg.zi ~= nil then
            if authorised then
                --             mem.jumpdrive.target = mem.jumpdrive.position
                mem.jumpdrive.target.z = mem.jumpdrive.position.z + mem.instant_jump.distance
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        elseif event.msg.zd ~= nil then
            if authorised then
                --             mem.jumpdrive.target = mem.jumpdrive.position
                mem.jumpdrive.target.z = mem.jumpdrive.position.z - mem.instant_jump.distance
                digiline_send(
                    jumpdrive.channel,
                    merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
                )
                digiline_send(jumpdrive.channel, {command = "jump"})
            else
                send_to_monitors(tostring(event.msg.clicker) .. ": You are not authorised to jump. See settings ;)")
            end
        end

        if jumpdrive_page_needs_update == true then
            update_page("Drive")
        end

    elseif touchscreen.pages[mem.page] == "Memory" and permission.check(event.msg.clicker) then
        -- Memory by marghl
        -- based on "i wish i had an item" by Ruggila
        -- TODO: add groups?
        local s = event.msg.locations_list or ""

            --filter_locations()
            if string.sub(s, 1, 4) == "CHG:" then
                -- extract the index number in the mem.m.targets table
                --s = s:sub(5)
                local n = tonumber(string.sub(s, 5))
                if n then
                    mem.m.itemnum = n
                    mem.m.item = mem.m.targets[n] or ""
                --digiline_send("mon_ec", mem.m.item)
                end
            end
            if event.msg.location == "set as target" then
                mem.jumpdrive.target = coordinates:to_table(mem.m.locations[mem.m.item].pos)
                mem.page = 1
                update_page("Drive")
            elseif event.msg.location == "delete" then
                mem.m.locations[mem.m.item] = nil
            elseif event.msg.location == "save" then
                local save_name = ""
                if event.msg.save == "" or nil then
                    save_name = get_time_string()
                else
                    save_name = event.msg.save
                end
                mem.m.locations[save_name] = {pos = coordinates:to_string(mem.jumpdrive.target),
                  description = event.msg.desc or "",
                  group = event.msg.group or nil}
                --mem.m.desc = event.msg.desc or ""
            elseif event.msg.location == "filter" then
                mem.m.filter = event.msg.filt
            end
            filter_locations()
            update_page("Memory")

   elseif not permission.check(event.msg.clicker) then
      digiline_send("mon_ec","m: "..event.msg.clicker..":\nnot authorised")
   end
end

-- ########
-- Jumpdrive
-- ########
if mem.jumpdrive == nil then
    mem.jumpdrive = {
        radius = 1,
        power_req = 0,
        distance = 0,
        powerstorage = 0,
        position = {x = 0, y = 0, z = 0},
        target = {x = 0, y = 0, z = 0},
        success = false,
        msg = "",
        time = 0
    }
end
if event.type == "program" then
    digiline_send(jumpdrive.channel, {command = "get"})
end

if event.type == "digiline" and event.channel == jumpdrive.channel and event.msg then
    local output = ""
    local updated = {}
    for k, v in pairs(event.msg) do
        if mem.jumpdrive[k] ~= nil then
            --          if mem.jumpdrive[k] ~= v then output = output .. " " .. tostring(k) .. ": " .. get_string(mem.jumpdrive[k]) .. " -> " .. get_string(v) end
            mem.jumpdrive[k] = v
        else
            add_line_to_buffer(
                touchscreen.linebuffer.jumpdrive,
                "Unknown jumpdrive propperty: " .. get_string(k) .. ":" .. get_string(v)
            )
        end
    end

    if event.msg.success ~= nil then
        if event.msg.success == true then
            output = output .. " Success!"
        else
            output = output .. " Failure!"
        end
    end
    if event.msg.msg then
        output = output .. " " .. event.msg.msg
    end
    if event.msg.time then
        output = output .. " Jumped (" .. tostring(event.msg.time) .. ")"
        mem.jumpdrive.position = mem.jumpdrive.target
        digiline_send(jumpdrive.channel, {command = "get"})
    end
    if output ~= nil then
        if output ~= "" then
            add_line_to_buffer(touchscreen.linebuffer.jumpdrive, tostring(mem.events.count) .. ":" .. output)
        end
    else
        add_line_to_buffer(touchscreen.linebuffer.jumpdrive, tostring(mem.events.count) .. ":" .. "Output was nil!")
    end

    update_page("Drive")
end

-------------------------
-- AutoQuarry

--~ if event.type == "interrupt" and mem.minterrupt.label == "auto_jump" and mem.quarry.auto.active then
--~ -- TODO: make this interrupt somehow
--~ --    needs local function multinterrupt(time,label){ -- if you dont give iid i just take it ;P
--~ --       mem.multinterrupt.label = label
--~ --       interrupt(time)}
--~ --    if event.type == "interrupt" then
--~ --       local l = mem.multinterrupt.label
--~ --       if l == "blah" then
--~ --          blah()
--~ --       elseif l == "blubb" then
--~ --          blubb()
--~ --       else
--~ --          whatever()
--~ --       end

    --~ --we jump now
    --~ digiline_send("mon_ec", "main: AC prejump") --crude debug
    --~ --from instant jump code FeXoR
    --~ --         mem.jumpdrive.target.x = mem.jumpdrive.position.x + mem.instant_jump.distance
    --~ --       digiline_send(jumpdrive.channel, merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target))
    --~ --     digiline_send(jumpdrive.channel, {command = "jump"})]]
    --~ if mem.quarry.auto.travel == 1 then
        --~ mem.jumpdrive.target.z = mem.jumpdrive.position.z + tonumber(mem.quarry.auto.distance)
    --~ elseif mem.quarry.auto.travel == 2 then
        --~ mem.jumpdrive.target.z = mem.jumpdrive.position.z - tonumber(mem.quarry.auto.distance)
    --~ elseif mem.quarry.auto.travel == 3 then
        --~ mem.jumpdrive.target.x = mem.jumpdrive.position.x + tonumber(mem.quarry.auto.distance)
    --~ elseif mem.quarry.auto.travel == 4 then
        --~ mem.jumpdrive.target.x = mem.jumpdrive.position.x - tonumber(mem.quarry.auto.distance)
    --~ end
    --~ -- maybe this will work?

    --~ if mem.quarry.auto.steps > 0 then
        --~ add_line_to_buffer(touchscreen.linebuffer.quarry, "Jumping in automode")
   --~ mem.quarry.auto.steps = mem.quarry.auto.steps - 1
   --~ update_page("Quarry")
        --~ digiline_send(
            --~ jumpdrive.channel,
            --~ merge_shallow_tables({command = "set", formupdate = false}, mem.jumpdrive.target)
        --~ )
        --~ digiline_send(jumpdrive.channel, {command = "jump"})
        --~ digiline_send("mon_ec","AUTOJUMP") -- crude debug


        --~ minterrupt(20,"auto_active")
    --~ else
        --~ mem.quarry.auto.active = false
        --~ add_line_to_buffer(touchscreen.linebuffer.quarry, "\nDONE\nAuto mode deactivated! \n")
        --~ digiline_send(quarry_channels[mem.quarry.auto.quarry], "off")
        --~ digiline_send("mon_ec", "main: AC done") -- crude debug
    --~ end

--~ end

--~ if event.type == "interrupt" and mem.minterrupt.label == "auto_active" then
   --~ digiline_send("mon_ec","ASK: "..power_net_names[mem.quarry.powermon.i])
   --~ digiline_send(power_net_names[mem.quarry.powermon.i],"GET")
--~ end

--~ if event.type == "digiline" and event.channel == power_net_names[mem.quarry.powermon.i] then
   --~ digiline_send("mon_"..power_net_names[mem.quarry.powermon.i],"Network: ".. power_net_names[mem.quarry.powermon.i] .."\n\nSupply: ".. math.floor(event.msg.supply / 1000)..
      --~ " kEU\nDemand: ".. math.floor(event.msg.demand / 1000)..
      --~ " kEU\nLAG: ".. (event.msg.lag / 1000)..
      --~ " ms\nBattery: ".. tostring(math.floor(event.msg.battery_charge / event.msg.battery_charge_max * 1000) / 10)..
      --~ " %"
      --~ )
   --~ mem.quarry.powermon[power_net_names[mem.quarry.powermon.i]] = event.msg.demand
   --~ local demand = 0
   --~ for i, x in ipairs(power_net_names) do
      --~ demand = mem.quarry.powermon[x] + demand
   --~ end
   --~ mem.quarry.powermon.i = (mem.quarry.powermon.i % #power_net_names) +1
   --~ if demand == 0 then
      --~ minterrupt(5,"auto_jump")
   --~ else
      --~ minterrupt(20,"auto_active")
   --~ end
--~ end
-- ########
-- Event Catcher
-- ########
if mem.event_catcher == nil then
    mem.event_catcher = {
        touchscreen_line_table = {
            "Initialized at " .. get_time_string() .. ", " .. _VERSION,
            mem.environment_information
        }
    }
end
if debug then
    send_to_monitors(event)
    update_page("Events")
end

-- ########
-- Count events
-- ########
mem.events.count = mem.events.count + 1

-- MIT License
--
-- Copyright (c) 2021 Florian Finke for the jumpdrive code and a big part of the
-- helper functions
--
-- (c) 2021? Ruggila for table_concat(), filter_locations() and big parts of "Memory"
-- (c) 2021/22 marghl all the rest

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--12
