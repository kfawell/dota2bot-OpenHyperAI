-- DotaRunner integration: sends game events to the DotaRunner desktop app.
-- All calls are wrapped in pcall so the game is unaffected if the app isn't running.

local json = require('bots.ts_libs.utils.json')
local DotaRunner = {}
local BASE_URL = "http://127.0.0.1:27016"

function DotaRunner:Post(endpoint, data)
    local ok, err = pcall(function()
        local request = CreateHTTPRequest("POST", BASE_URL .. endpoint)
        request:SetHTTPRequestHeaderValue("Content-Type", "application/json")
        request:SetHTTPRequestRawPostBody("application/json", json.encode(data))
        request:Send(function(response) end)
    end)
    if not ok then
        print('[DotaRunner] HTTP failed: ' .. tostring(err))
    end
end

return DotaRunner
