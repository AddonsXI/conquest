--[[
* Addons - Copyright (c) 2024 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Ashita is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Ashita is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'conquest';
addon.author    = 'AddonsXI';
addon.version   = '1.0.0';
addon.link      = 'https://github.com/AddonsXI';
addon.desc      = 'Shows which nations own which conquest regions.';

require('common');
local chat = require('chat');

-- Region ownership comes from packet 0x5E. Controller 1=San d'Oria, 2=Bastok, 3=Windurst, 4=Beastmen.
local REGIONS = T{
    { offset = 0x1D, name = 'Ronfaure' },
    { offset = 0x21, name = 'Zulkheim' },
    { offset = 0x25, name = 'Norvallen' },
    { offset = 0x29, name = 'Gustaberg' },
    { offset = 0x2D, name = 'Derfland' },
    { offset = 0x31, name = 'Sarutabaruta' },
    { offset = 0x35, name = 'Kolshushu' },
    { offset = 0x39, name = 'Aragoneu' },
    { offset = 0x3D, name = 'Fauregandi' },
    { offset = 0x41, name = 'Valdeaunia' },
    { offset = 0x45, name = 'Qufim' },
    { offset = 0x49, name = 'Li\'Telor' },
    { offset = 0x4D, name = 'Kuzotz' },
    { offset = 0x51, name = 'Vollbow' },
    { offset = 0x55, name = 'Elshimo Lowlands' },
    { offset = 0x59, name = 'Elshimo Uplands' },
    { offset = 0x5D, name = 'Tu\'Lia' },
    { offset = 0x61, name = 'Movalpolos' },
    { offset = 0x65, name = 'Tavnazian Archipelago' },
};

-- FFXI chat colors from libs/chat.lua: 76=Tomato(red), 71=RoyalBlue, 69=Yellow, 79=Lime
local CONTROLLERS = T{
    [1] = { name = 'San d\'Oria', color = 76 },   -- red
    [2] = { name = 'Bastok', color = 71 },       -- blue
    [3] = { name = 'Windurst', color = 69 },     -- yellow
    [4] = { name = 'Beastmen', color = 79 },     -- lime green
};

local conquest = T{
    regionControllers = {},
    pendingDisplay = false,
};

-- Prints regions grouped by faction, sorted by count (most to least). One full line per nation.
local function printRegions()
    local byController = T{};
    for _, region in ipairs(REGIONS) do
        local ctrlId = conquest.regionControllers[region.name] or 0;
        if not byController[ctrlId] then byController[ctrlId] = T{}; end
        byController[ctrlId]:append(region.name);
    end

    local order = T{};
    for ctrlId = 1, 4 do
        local regions = byController[ctrlId];
        if regions and #regions > 0 then
            order:append({ ctrlId = ctrlId, count = #regions });
        end
    end
    table.sort(order, function(a, b) return a.count > b.count; end);

    for _, entry in ipairs(order) do
        local ctrl = CONTROLLERS[entry.ctrlId];
        local regions = byController[entry.ctrlId];
        table.sort(regions);
        local line = ctrl.name .. ' (' .. entry.count .. '): ' .. table.concat(regions, ', ');
        print(chat.header(addon.name):append(chat.color1(ctrl.color, line)));
    end

    local unknown = byController[0];
    if unknown and #unknown > 0 then
        table.sort(unknown);
        print(chat.header(addon.name):append(chat.message('Unknown: ' .. table.concat(unknown, ', '))));
    end
end

-- Sends packet 0x5A to request conquest data from the server.
local function requestConquest()
    local packet = struct.pack('L', 0);
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x5A, packet:totable());
end

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if #args == 0 then return; end

    local cmd = args[1]:lower();
    if cmd ~= '/conquest' and cmd ~= '/regions' then return; end

    e.blocked = true;

    if next(conquest.regionControllers) then
        printRegions();
    else
        conquest.pendingDisplay = true;
        requestConquest();
    end
end);

ashita.events.register('packet_in', 'conquest_packet_cb', function (e)
    if e.id ~= 0x5E then return; end
    if not conquest.pendingDisplay then return; end  -- only process when user requested data

    conquest.pendingDisplay = false;
    for _, region in ipairs(REGIONS) do
        local controller = struct.unpack('B', e.data, region.offset + 1);
        conquest.regionControllers[region.name] = controller;
    end
    printRegions();
end);
