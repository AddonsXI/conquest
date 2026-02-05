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
addon.version   = '1.0.1';
addon.link      = 'https://github.com/AddonsXI';
addon.desc      = 'Shows which nations own which conquest regions.';

require('common');
local chat = require('chat');

-- Packet 0x5E: controller bytes start at 0x1D and increment by 4.
local BASE_OFFSET = 0x1D;
local OFFSET_STEP = 4;

local REGIONS = T{
    'Ronfaure',
    'Zulkheim',
    'Norvallen',
    'Gustaberg',
    'Derfland',
    'Sarutabaruta',
    'Kolshushu',
    'Aragoneu',
    'Fauregandi',
    'Valdeaunia',
    'Qufim',
    'Li\'Telor',
    'Kuzotz',
    'Vollbow',
    'Elshimo Lowlands',
    'Elshimo Uplands',
    'Tu\'Lia',
    'Movalpolos',
    'Tavnazian Archipelago',
};

-- Chat colors from libs/chat.lua
local CONTROLLERS = T{
    [1] = { name = 'San d\'Oria', color = 76 }, -- red
    [2] = { name = 'Bastok',     color = 71 }, -- blue
    [3] = { name = 'Windurst',   color = 69 }, -- yellow
    [4] = { name = 'Beastmen',   color = 79 }, -- lime
};

local conquest = T{
    regionControllers = T{},
    awaitingPacket = false,
};

--[[
* Sends packet 0x5A to request conquest data from the server.
--]]
local function requestConquest()
    local packet = struct.pack('L', 0);
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x5A, packet:totable());
end

--[[
* Prints regions grouped by faction, sorted by count (most to least).
--]]
local function printRegions()
    local buckets = T{};
    for id = 1, 4 do
        buckets[id] = T{ regions = T{}, count = 0 };
    end

    -- Controller 0 or unexpected values (no bucket for 1–4) fall into unknown.
    local unknown = T{};

    for i, regionName in ipairs(REGIONS) do
        local ctrlId = conquest.regionControllers[i];
        local bucket = buckets[ctrlId];

        if bucket then
            bucket.count = bucket.count + 1;
            bucket.regions:append(regionName);
        else
            unknown:append(regionName);
        end
    end

    local order = T{};
    for id, bucket in pairs(buckets) do
        if bucket.count > 0 then
            table.sort(bucket.regions);
            order:append(id);
        end
    end

    table.sort(order, function(a, b)
        return buckets[a].count > buckets[b].count;
    end);

    for _, id in ipairs(order) do
        local ctrl = CONTROLLERS[id];
        local bucket = buckets[id];

        print(
            chat.header(addon.name)
                :append(chat.color1(
                    ctrl.color,
                    ('%s (%d): %s'):fmt(
                        ctrl.name,
                        bucket.count,
                        table.concat(bucket.regions, ', ')
                    )
                ))
        );
    end

    if #unknown > 0 then
        table.sort(unknown);
        print(
            chat.header(addon.name)
                :append(chat.message('Unknown: ' .. table.concat(unknown, ', ')))
        );
    end
end

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args();
    if (#args == 0) then return; end

    local cmd = args[1]:lower();
    if (cmd ~= '/conquest' and cmd ~= '/regions') then return; end

    e.blocked = true;

    if (next(conquest.regionControllers)) then
        printRegions();
    else
        conquest.awaitingPacket = true;
        requestConquest();
    end
end);

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'conquest_packet_cb', function(e)
    if (e.id ~= 0x5E) then return; end
    if (not conquest.awaitingPacket) then return; end

    conquest.awaitingPacket = false;

    for i = 1, #REGIONS do
        local offset = BASE_OFFSET + (i - 1) * OFFSET_STEP;
        conquest.regionControllers[i] = struct.unpack('B', e.data, offset + 1);
    end

    printRegions();
end);
