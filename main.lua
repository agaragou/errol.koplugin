local DEPENDENCIES = {
    ui = require("ui/uimanager"),
    container = require("ui/widget/container/widgetcontainer"),
    info = require("ui/widget/infomessage"),
    confirmbox = require("ui/widget/confirmbox"),
    text_util = require("util"),
    i18n = require("gettext"),
    logger = require("logger"),
    -- Lazy loaded modules placeholder
    socket = nil, 
    http = nil,
    json = nil,
    lfs = nil,
}

local function load_dep(name)
    if DEPENDENCIES[name] then return DEPENDENCIES[name] end
    if name == "socket" then DEPENDENCIES.socket = require("socket") end
    if name == "http" then 
        DEPENDENCIES.http = require("socket.http") 
        DEPENDENCIES.http.TIMEOUT = 2
    end
    if name == "json" then DEPENDENCIES.json = require("json") end
    if name == "lfs" then DEPENDENCIES.lfs = require("libs/libkoreader-lfs") end
    return DEPENDENCIES[name]
end

--------------------------------------------------------------------------------
-- Settings Manager
--------------------------------------------------------------------------------
local SettingsManager = {}

function SettingsManager.get_global_settings()
    return G_reader_settings
end

function SettingsManager.get_autosend_enabled()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_autosend_enabled") then
        return s:isTrue("errol_autosend_enabled")
    end
    return false
end

function SettingsManager.set_autosend_enabled(val)
    local s = SettingsManager.get_global_settings()
    if s then
        s:saveSetting("errol_autosend_enabled", val)
    end
end

function SettingsManager.get_interval()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_check_interval") then
        local v = tonumber(s:readSetting("errol_check_interval"))
        if v and v > 0 then return v end
    end
    return 15
end

function SettingsManager.set_interval(val)
    local s = SettingsManager.get_global_settings()
    if s then
        s:saveSetting("errol_check_interval", tonumber(val))
    end
end

function SettingsManager.get_download_dir()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_download_dir") then
        return s:readSetting("errol_download_dir")
    end
    return require("device").home_dir -- Fallback to home
end

function SettingsManager.set_download_dir(val)
    local s = SettingsManager.get_global_settings()
    if s then
        s:saveSetting("errol_download_dir", val)
    end
end

function SettingsManager.is_telegram_enabled()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_telegram_enabled") then
        return s:isTrue("errol_telegram_enabled")
    end
    return true -- Default True
end

function SettingsManager.set_telegram_enabled(val)
    local s = SettingsManager.get_global_settings()
    if s then s:saveSetting("errol_telegram_enabled", val) end
end

function SettingsManager.is_discord_enabled()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_discord_enabled") then
        return s:isTrue("errol_discord_enabled")
    end
    return true -- Default True
end

function SettingsManager.set_discord_enabled(val)
    local s = SettingsManager.get_global_settings()
    if s then s:saveSetting("errol_discord_enabled", val) end
end

function SettingsManager.is_time_24h()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_time_24h") then
        return s:isTrue("errol_time_24h")
    end
    return true -- Default 24h
end

function SettingsManager.set_time_24h(val)
    local s = SettingsManager.get_global_settings()
    if s then s:saveSetting("errol_time_24h", val) end
end

function SettingsManager.is_date_day_first()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_date_day_first") then
        return s:isTrue("errol_date_day_first")
    end
    return true -- Default DD MMM YYYY
end

function SettingsManager.set_date_day_first(val)
    local s = SettingsManager.get_global_settings()
    if s then s:saveSetting("errol_date_day_first", val) end
end

function SettingsManager.is_spoiler_enabled()
    local s = SettingsManager.get_global_settings()
    if s and s:has("errol_spoiler_enabled") then
        return s:isTrue("errol_spoiler_enabled")
    end
    return false -- Default False
end

function SettingsManager.set_spoiler_enabled(val)
    local s = SettingsManager.get_global_settings()
    if s then s:saveSetting("errol_spoiler_enabled", val) end
end

--------------------------------------------------------------------------------
-- Cache Manager
--------------------------------------------------------------------------------
local CacheManager = { _mem_cache = nil }

function CacheManager.get_cache_dir()
    local sd = require("datastorage"):getSettingsDir()
    local cache_dir = sd .. "/errol_cache"
    local lfs = load_dep("lfs")
    if not lfs.attributes(cache_dir) then
        lfs.mkdir(cache_dir)
    end
    return cache_dir
end

function CacheManager.ensure_dir()
    local lfs = load_dep("lfs")
    local dir = CacheManager.get_cache_dir()
    local attr = lfs.attributes(dir)
    if not attr then
        lfs.mkdir(dir)
    end
    return dir
end

function CacheManager.get_file_path()
    return CacheManager.ensure_dir() .. "/queue.json"
end

function CacheManager.load_queue()
    if CacheManager._mem_cache then return CacheManager._mem_cache end
    
    local json = load_dep("json")
    local path = CacheManager.get_file_path()
    local f = io.open(path, "r")
    if not f then 
        CacheManager._mem_cache = {}
        return CacheManager._mem_cache
    end
    local content = f:read("*a")
    f:close()
    
    if not content or content == "" then 
        CacheManager._mem_cache = {}
    else
        local ok, res = pcall(json.decode, content)
        CacheManager._mem_cache = ok and res or {}
    end
    
    return CacheManager._mem_cache
end

function CacheManager.save_queue(q)
    CacheManager._mem_cache = q -- Update memory cache
    local json = load_dep("json")
    local path = CacheManager.get_file_path()
    local f = io.open(path, "w")
    if f then
        f:write(json.encode(q))
        f:close()
    end
end

function CacheManager.push(msg_data)
    local q = CacheManager.load_queue()
    table.insert(q, {
        text = msg_data,
        timestamp = os.time()
    })
    CacheManager.save_queue(q)
    return #q
end

function CacheManager.remove_item(index)
    local q = CacheManager.load_queue()
    if index > 0 and index <= #q then
        table.remove(q, index)
        CacheManager.save_queue(q)
        return true
    end
    return false
end

function CacheManager.pop_all()
    -- Copy current queue to return, then clear
    local q = CacheManager.load_queue()
    local old_q = {}
    for i,v in ipairs(q) do old_q[i] = v end
    
    CacheManager.save_queue({})
    return old_q
end

function CacheManager.count()
    local q = CacheManager.load_queue()
    return #q
end

--------------------------------------------------------------------------------
-- Highlights Browser
--------------------------------------------------------------------------------
local function makeHighlightPreview(text, page)
    if not text then return "???" end
    -- Strip HTML
    local clean = text:gsub("<[^>]+>", "")
    -- Collapse whitespace
    clean = clean:gsub("%s+", " ")
    
    if page then
        return string.format("[Page: %s] %s", tostring(page), clean)
    end
    return clean
end

--------------------------------------------------------------------------------
-- Config Management (Plugin Specific)
--------------------------------------------------------------------------------
local ConfigProvider = { _cache = nil }

function ConfigProvider.get_settings()
    if ConfigProvider._cache then return ConfigProvider._cache end
    local debug_info = debug.getinfo(2, "S")
    local path = debug_info.source:sub(2)
    local dir = path:match("(.*/)") or ""
    local success, conf = pcall(dofile, dir .. "config.lua")
    if success and conf and conf.telegram then
        ConfigProvider._cache = conf
        return conf
    end
    return { token = "", chat_id = "" }
end

--------------------------------------------------------------------------------
-- Logic Controller
--------------------------------------------------------------------------------
local TelegramExporter = {}

function TelegramExporter.safe_encode(str)
    if not str then return "" end
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(str, " ", "%%20")
end

function TelegramExporter.clean_html(str)
    if not str then return "" end
    str = string.gsub(str, "&", "&amp;")
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    return str
end

function TelegramExporter.format_tag(str)
    if not str or str == "" then return nil end
    local s = tostring(str)
    s = s:gsub("%s+", "_")
    -- Replace dots with empty string or underscore to prevent tag breakage
    s = s:gsub("[%.#&<>:]", "")
    return s
end

function TelegramExporter.html_to_markdown(text)
    if not text then return "" end
    local t = text
    -- Convert bold
    t = t:gsub("<b>(.-)</b>", "**%1**")
    -- Convert italic
    t = t:gsub("<i>(.-)</i>", "*%1*")
    -- Convert spoiler
    t = t:gsub('<span class="tg%-spoiler">(.-)</span>', "||%1||")
    -- Convert blockquote (handle multiline)
    t = t:gsub("<blockquote>(.-)</blockquote>", function(q)
        -- clean optional breaks
        q = q:gsub("<br%s*/?>", "\n")
        -- prefix each line with >
        -- simpler approach for Discord: >>> is multiline blockquote, but let's stick to standard > 
        -- logic: replace newline with newline>
        return "> " .. q:gsub("\n", "\n> ")
    end)
    -- Convert leftover breaks to newlines
    t = t:gsub("<br%s*/?>", "\n")
    -- Strip remaining tags
    t = t:gsub("<.->", "")
    return t
end

function TelegramExporter.send_to_discord(cfg, html_text)
    if not cfg or not cfg.discord or not cfg.discord.webhook_url then return end
    local md_text = TelegramExporter.html_to_markdown(html_text)
    
    local json = load_dep("json")
    local http = load_dep("http")
    local ltn12 = require("ltn12")

    local payload = json.encode({ content = md_text })
    local resp = {}

    http.request{
        url = cfg.discord.webhook_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #payload
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(resp)
    }
end

function TelegramExporter.compose_message(quote, meta_bundler, options)
    local opts = options or {}
    -- Backwards compatibility: if options is boolean, treat as is_spoiler_override
    if type(options) == "boolean" then
        opts = { spoiler = options }
    end

    local props = meta_bundler.raw or {}
    local filename = meta_bundler.file_path and meta_bundler.file_path:match("([^/]+)$") or "Unknown"
    
    local title = props.title
    if not title or title == "" then title = filename end
    
    local author = props.authors or props.author or props.creator
    if type(author) == "table" then author = table.concat(author, ", ") end

    local header_text = title
    local t_tag, a_tag
    if author and author ~= "" then
        header_text = title .. " — " .. author
        t_tag = TelegramExporter.format_tag(title)
        a_tag = TelegramExporter.format_tag(author:match("^[^,]+") or author)
    end
    
    local lines = {}
    table.insert(lines, "📖 <b>" .. TelegramExporter.clean_html(header_text) .. "</b>")

    -- Chapter
    local chap_txt
    if opts.chapter then
        chap_txt = opts.chapter
    else
        -- Try current reader state
        local reader = nil 
        local ok, rui = pcall(require, "apps/reader/readerui")
        if ok and rui then reader = rui.instance end
        if reader and reader.toc and reader.view then
            local pg = reader.view.state and reader.view.state.page
            if pg then
                local ok_toc, c = pcall(function() return reader.toc:getTocTitleByPage(pg) end)
                if ok_toc and c and c ~= "" then chap_txt = c end
            end
        end
    end
    
    if chap_txt and chap_txt ~= "" then
        table.insert(lines, "📑 Chapter: <b>" .. TelegramExporter.clean_html(chap_txt) .. "</b>")
    end

    -- Page
    local cur = opts.page or tonumber(meta_bundler.page_current)
    local tot = tonumber(meta_bundler.pages_total)
    local page_str = "📄 Page: —"
    
    if cur and tot then
        if tot > 0 then
            -- If we have an override page, percentage might be approximate if not recalculated, 
            -- but simple calc here is fine.
            local pct = math.floor((cur/tot)*100 + 0.5)
            page_str = string.format("📄 Page: %d of %d [%d%%]", cur, tot, pct)
        else
            page_str = string.format("📄 Page: %d of %d", cur, tot)
        end
    elseif cur then
         page_str = string.format("📄 Page: %d", cur)
    end
    table.insert(lines, page_str)

    -- Date
    local dt_str
    if opts.datetime then
         -- Parse "YYYY-MM-DD HH:MM:SS" (SQL format used by KOReader)
         local Y, M, D, h, m, s = opts.datetime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
         if Y then
             local time = os.time({year=Y, month=M, day=D, hour=h, min=m, sec=s})
             local time_fmt = SettingsManager.is_time_24h() and "%H:%M" or "%I:%M %p"
             local date_fmt = SettingsManager.is_date_day_first() and "%d %b %Y" or "%b %d %Y"
             dt_str = os.date(time_fmt .. " " .. date_fmt, time)
         else
             dt_str = opts.datetime -- Fallback key
         end
    else
        local time_fmt = SettingsManager.is_time_24h() and "%H:%M" or "%I:%M %p"
        local date_fmt = SettingsManager.is_date_day_first() and "%d %b %Y" or "%b %d %Y"
        dt_str = os.date(time_fmt .. " " .. date_fmt)
    end
    table.insert(lines, "📆 " .. dt_str)
    
    table.insert(lines, "")

    local tags = {}
    if t_tag then table.insert(tags, "#" .. t_tag) end
    if a_tag then table.insert(tags, "#" .. a_tag) end
    if #tags > 0 then
        table.insert(lines, "🏷️ " .. table.concat(tags, " "))
        table.insert(lines, "")
    end

    local q_text = TelegramExporter.clean_html(quote)
    local use_spoiler = SettingsManager.is_spoiler_enabled()
    if opts.spoiler ~= nil then
        use_spoiler = opts.spoiler
    end
    
    if use_spoiler then
        q_text = string.format('<span class="tg-spoiler">%s</span>', q_text)
    end
    table.insert(lines, string.format("<blockquote>%s</blockquote>", q_text))
    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Background Runner
--------------------------------------------------------------------------------
local BackgroundRunner = {
    is_running = false,
    session_id = 0
}

function BackgroundRunner.tick(expected_sid)
    -- Check stale
    if expected_sid ~= BackgroundRunner.session_id then return end

    if CacheManager.count() == 0 then
        BackgroundRunner.is_running = false
        return
    end

    local http = load_dep("http")
    -- Check Connectivity
    local _, c = http.request("http://clients3.google.com/generate_204")
    if c == 204 then
        -- Online! Flush
        local queue = CacheManager.pop_all()
        local cfg = ConfigProvider.get_settings()
        
        for _, item in ipairs(queue) do
            if SettingsManager.is_telegram_enabled() then
                local url = string.format(
                    "https://api.telegram.org/bot%s/sendMessage?chat_id=%s&parse_mode=HTML&text=%s",
                    cfg.telegram.token, cfg.telegram.chat_id, TelegramExporter.safe_encode(item.text)
                )
                http.request(url)
            end
            
            -- Try Discord
            if SettingsManager.is_discord_enabled() and cfg.discord and cfg.discord.webhook_url then
                 TelegramExporter.send_to_discord(cfg, item.text)
            end
        end
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = DEPENDENCIES.i18n("Sent cached Errol highlights!"), duration = 3 })
        BackgroundRunner.is_running = false
    else
        local mins = SettingsManager.get_interval()
        -- Schedule next tick with SAME session ID
        DEPENDENCIES.ui:scheduleIn(mins * 60, function() BackgroundRunner.tick(expected_sid) end)
    end
end

function BackgroundRunner.start(immediate)
    -- Always increment session to invalidate any pending old ticks
    BackgroundRunner.session_id = BackgroundRunner.session_id + 1
    local my_sid = BackgroundRunner.session_id
    
    BackgroundRunner.is_running = true
    local mins = SettingsManager.get_interval()
    local delay = immediate and 0 or (mins * 60)
    
    DEPENDENCIES.ui:scheduleIn(delay, function() BackgroundRunner.tick(my_sid) end)
end

function BackgroundRunner.stop()
    BackgroundRunner.is_running = false
    -- Increment session ID to invalidate pending ticks
    BackgroundRunner.session_id = BackgroundRunner.session_id + 1
end

--------------------------------------------------------------------------------
-- Main Action
--------------------------------------------------------------------------------
function TelegramExporter.execute_delivery(text, ui_context)
    local cfg = ConfigProvider.get_settings()
    local http = load_dep("http")

    local function attempt_send()
         local sent_any = false
         
         if SettingsManager.is_telegram_enabled() then
             if not cfg.telegram or not cfg.telegram.token or not cfg.telegram.chat_id then
                 DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Telegram config missing", duration = 3 })
             else
                 local url = string.format(
                     "https://api.telegram.org/bot%s/sendMessage?chat_id=%s&parse_mode=HTML&text=%s",
                     cfg.telegram.token, cfg.telegram.chat_id, TelegramExporter.safe_encode(text)
                 )
                 local _, code = http.request(url)
                 if code == 200 then
                      sent_any = true
                      DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Sent to Telegram!", duration = 1 })
                 else
                      DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Telegram Error: " .. tostring(code), duration = 3 })
                 end
             end
         end
         
         if SettingsManager.is_discord_enabled() and cfg.discord and cfg.discord.webhook_url then
             TelegramExporter.send_to_discord(cfg, text)
             sent_any = true
             DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Sent to Discord!", duration = 1 })
         end

         if sent_any or (not SettingsManager.is_telegram_enabled() and not SettingsManager.is_discord_enabled()) then
             if ui_context and ui_context.saveHighlight then pcall(function() ui_context:saveHighlight(true) end) end
             if ui_context and ui_context.onClose then ui_context:onClose() end
         end
    end

    local function queue_and_autosend()
        CacheManager.push(text)
        BackgroundRunner.start()
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ 
            text = DEPENDENCIES.i18n("Saved to cache. Will send when online."), 
            duration = 3 
        })
        if ui_context and ui_context.saveHighlight then pcall(function() ui_context:saveHighlight(true) end) end
        if ui_context and ui_context.onClose then ui_context:onClose() end
    end

    local function runner_logic()
         local _, c = http.request("http://clients3.google.com/generate_204")
         if c == 204 then
             -- Online
             local count = CacheManager.count()
             if count > 0 then
                 -- If we have backlog, queue this one too and flush everything
                 CacheManager.push(text)
                 BackgroundRunner.stop() -- Ensure we interrupt any existing wait
                 BackgroundRunner.start(true) -- Immediate start
                 
                 DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ 
                     text = string.format("Sending %d cached highlights and the current one...", count + 1), 
                     duration = 3 
                 })
                 
                 if ui_context and ui_context.saveHighlight then pcall(function() ui_context:saveHighlight(true) end) end
                 if ui_context and ui_context.onClose then ui_context:onClose() end
             else
                 attempt_send()
             end
         else
             -- Offline
             if SettingsManager.get_autosend_enabled() then
                 queue_and_autosend()
             else
                 -- Wifi Prompt with Fallback to Autosend
                 local ok, net = pcall(require, "ui/network/manager")
                 if not (ok and net) then
                     DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = DEPENDENCIES.i18n("Network manager not found"), duration = 3 })
                     return
                 end

                 local function on_wifi_connected()
                      local _, c2 = http.request("http://clients3.google.com/generate_204")
                      if c2 == 204 then
                          attempt_send()
                      else
                          DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = DEPENDENCIES.i18n("Network still unreachable"), duration = 3 })
                      end
                 end

                 DEPENDENCIES.ui:show(DEPENDENCIES.confirmbox:new{
                     text = DEPENDENCIES.i18n("Turn on Wi-Fi to send highlight?"),
                     ok_text = DEPENDENCIES.i18n("Turn on"),
                     cancel_text = DEPENDENCIES.i18n("Cancel"),
                     ok_callback = function()
                         if net.enableWifi then
                             net:enableWifi()
                             DEPENDENCIES.ui:scheduleIn(5, on_wifi_connected)
                         elseif net.toggleWifiOn then
                             net:toggleWifiOn(on_wifi_connected)
                         else
                             DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Cannot toggle Wifi", duration = 3 })
                         end
                     end,
                     cancel_callback = function()
                         -- Ask to enable Autosend
                         DEPENDENCIES.ui:show(DEPENDENCIES.confirmbox:new{
                             text = DEPENDENCIES.i18n("Enable 'Autosend' and queue this highlight?"),
                             ok_text = DEPENDENCIES.i18n("Yes"),
                             cancel_text = DEPENDENCIES.i18n("No"),
                             ok_callback = function()
                                 SettingsManager.set_autosend_enabled(true)
                                 -- Update menu checks
                                 if touchmenu_instance then touchmenu_instance:updateItems() end
                                 queue_and_autosend()
                             end,
                             cancel_callback = function()
                                 DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Cancelled", duration = 1 })
                             end
                         })
                     end
                 })
             end
         end
    end

    runner_logic()
end

--------------------------------------------------------------------------------
-- Telegram Downloader
--------------------------------------------------------------------------------
local TelegramDownloader = {}

function TelegramDownloader.download_updates(callback)
    local cfg = ConfigProvider.get_settings()
    local http = load_dep("http")
    local json = load_dep("json")
    local lfs = load_dep("lfs")
    local download_dir = SettingsManager.get_download_dir()

    if not lfs.attributes(download_dir, "mode") then
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Invalid download directory!", duration = 3 })
        return
    end

    local total_downloaded = 0
    local processed_any = false
    local max_iterations = 5 -- Safety limit to prevent infinite loops
    local offset = 0
    local loop_count = 0

    local function fetch_batch()
        loop_count = loop_count + 1
        -- Naive progress indicator
        if loop_count == 1 then
             DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Checking for books...", duration = 1 })
        end

        local url = string.format("https://api.telegram.org/bot%s/getUpdates?limit=10&offset=%d", cfg.telegram.token, offset)
        local body, code = http.request(url)
        
        if code ~= 200 then return false end
        
        local ok, res = pcall(json.decode, body)
        if not (ok and res and res.ok and res.result) then return false end
        
        local updates = res.result
        if #updates == 0 then return false end

        local max_id = 0
        local docs = {}

        for _, update in ipairs(updates) do
            if update.update_id then
                max_id = update.update_id
            end

            -- Validate Chat ID and Doc existence
            if update.message and update.message.chat and tostring(update.message.chat.id) == tostring(cfg.telegram.chat_id) then
                if update.message.document then
                    table.insert(docs, {
                        doc = update.message.document,
                        message_id = update.message.message_id,
                        chat_id = update.message.chat.id
                    })
                end
            elseif update.message and update.message.chat then
                 -- Log unauthorized or ignored message?
                 -- For now, we simply ignore it, but we MUST acknowledge it via offset 
                 -- effectively "deleting" it from the queue for this bot.
            end
        end

        -- Update offset for next batch
        if max_id > 0 then
            offset = max_id + 1
            processed_any = true
        end
        
        -- Download found docs in this batch
        for i, item in ipairs(docs) do
             local doc = item.doc
             local file_id = doc.file_id
             local file_name = doc.file_name or ("doc_" .. file_id)
             local target_path = download_dir .. "/" .. file_name
             
             if not lfs.attributes(target_path) then
                 local path_url = string.format("https://api.telegram.org/bot%s/getFile?file_id=%s", cfg.telegram.token, file_id)
                 local path_body, path_code = http.request(path_url)
                 
                 if path_code == 200 then
                      local pok, pres = pcall(json.decode, path_body)
                      if pok and pres and pres.ok and pres.result and pres.result.file_path then
                          local dl_url = string.format("https://api.telegram.org/file/bot%s/%s", cfg.telegram.token, pres.result.file_path)
                          local file_content, dl_code = http.request(dl_url)
                          if dl_code == 200 and file_content then
                              local f = io.open(target_path, "wb")
                              if f then
                                  f:write(file_content)
                                  f:close()
                                  total_downloaded = total_downloaded + 1
                                  
                                  -- Delete processed message from chat
                                  local del_url = string.format("https://api.telegram.org/bot%s/deleteMessage?chat_id=%s&message_id=%s", cfg.telegram.token, item.chat_id, item.message_id)
                                  http.request(del_url)
                              end
                          end
                      end
                 end
             end
        end

        return true -- Continue loop
    end

    -- Run Loop
    while loop_count < max_iterations do
        if not fetch_batch() then break end
    end
    
    -- Final confirmation request to clear server queue
    if processed_any and offset > 0 then
        http.request(string.format("https://api.telegram.org/bot%s/getUpdates?offset=%d&limit=1&timeout=0", cfg.telegram.token, offset))
    end

    if total_downloaded > 0 then
        local filemanagerutil = require("apps/filemanager/filemanagerutil")
        local display_dir = filemanagerutil.abbreviate(download_dir)
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ 
            text = string.format("Saved %d new files to:\n%s", total_downloaded, display_dir), 
            duration = 5 
        })
    else
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "No new books found.", duration = 2 })
    end
end

--------------------------------------------------------------------------------
-- Integration
--------------------------------------------------------------------------------
local SystemLayer = {}

function SystemLayer.get_document_metadata(doc)
    local m = {}
    if not doc then return m end
    local rp = nil
    local has, ds = pcall(require, "docsettings")
    if has and doc.file then
        local ok, s = pcall(function() return ds:open(doc.file) end)
        if ok and s then rp = s.data.doc_props or s.data.props or s.data.metadata end
    end
    if not rp then rp = doc.info end
    m.raw = rp
    m.file_path = doc.file
    if doc.getPageCount then m.pages_total = doc:getPageCount() end
    if doc.getCurrentPage then m.page_current = doc:getCurrentPage() end
    return m
end

local TelegramPlugin = DEPENDENCIES.container:extend{
    name = "errol",
    is_doc_only = false,
}

function TelegramPlugin:init()
    local ACTION_ID = "tg_export_action" 
    local SPOILER_ACTION_ID = "tg_export_action_spoiler"

    if self.ui and self.ui.highlight then
        -- Standard Button
        self.ui.highlight:addToHighlightDialog(ACTION_ID, function(ctx)
            return {
                text = DEPENDENCIES.i18n("Errol: Send"), 
                callback = function()
                    if ctx.selected_text and ctx.selected_text.text then
                        local raw = ctx.selected_text.text
                        local clean = DEPENDENCIES.text_util.cleanupSelectedText(raw)
                        local data = SystemLayer.get_document_metadata(self.ui.document)
                        local msg = TelegramExporter.compose_message(clean, data, nil)
                        TelegramExporter.execute_delivery(msg, ctx)
                    else
                        if ctx.onClose then ctx:onClose() end
                    end
                end,
            }
        end)

        -- Spoiler Button
        self.ui.highlight:addToHighlightDialog(SPOILER_ACTION_ID, function(ctx)
            return {
                text = DEPENDENCIES.i18n("Errol: Spoiler"), 
                callback = function()
                    if ctx.selected_text and ctx.selected_text.text then
                        local raw = ctx.selected_text.text
                        local clean = DEPENDENCIES.text_util.cleanupSelectedText(raw)
                        local data = SystemLayer.get_document_metadata(self.ui.document)
                        local msg = TelegramExporter.compose_message(clean, data, true)
                        TelegramExporter.execute_delivery(msg, ctx)
                    else
                        if ctx.onClose then ctx:onClose() end
                    end
                end,
            }
        end)
    end
    
    -- Robust Menu Registration
    if self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    else
        DEPENDENCIES.logger.warn("[Errol] ui.menu not found in init, scheduling retry.")
        DEPENDENCIES.ui:scheduleIn(1, function()
            if self.ui.menu then
                self.ui.menu:registerToMainMenu(self)
                DEPENDENCIES.logger.info("[Errol] Registered to menu (retry).")
            else
                DEPENDENCIES.logger.warn("[Errol] Failed to register menu after retry.")
            end
        end)
    end

    -- Startup Cache Check
    DEPENDENCIES.ui:scheduleIn(2, function()
        self:check_cache_on_startup()
        self:checkRemoteVersion()
    end)
end

function TelegramPlugin:getLocalVersion()
    local debug_info = debug.getinfo(1, "S")
    local path = debug_info.source:sub(2)
    local dir = path:match("(.*/)") or ""
    local f = io.open(dir .. "_meta.lua", "r")
    if not f then return "?.?" end
    local content = f:read("*a")
    f:close()
    if content then
        local ver = content:match("version%s*=%s*[\"']([%d%.]+)[\"']")
        return ver or "?.?"
    end
    return "?.?"
end

function TelegramPlugin:compareVersions(v1, v2)
    local v1_str = tostring(v1)
    local v2_str = tostring(v2)
    
    local p1 = {}
    for part in v1_str:gmatch("%d+") do table.insert(p1, tonumber(part)) end
    local p2 = {}
    for part in v2_str:gmatch("%d+") do table.insert(p2, tonumber(part)) end
    
    for i = 1, math.max(#p1, #p2) do
        local n1 = p1[i] or 0
        local n2 = p2[i] or 0
        if n1 > n2 then return 1 end
        if n1 < n2 then return -1 end
    end
    return 0
end

function TelegramPlugin:checkRemoteVersion()
    local http = load_dep("http")
    local url = "https://raw.githubusercontent.com/agaragou/errol.koplugin/refs/heads/main/_meta.lua"
    -- Run in protected call to avoid crashes
    local function runner()
         local body, code = http.request(url)
         if code == 200 and body then
             local ver = body:match("version%s*=%s*[\"']([%d%.]+)[\"']")
             if ver then
                 self.remote_version = ver
             end
         end
    end
    -- We are already in a schedule from init, but let's not block too much.
    -- Ideally this should possess its own timeout or run in a thread, 
    -- but pure Lua threads are limited here. http.TIMEOUT is already set to 2s.
    pcall(runner)
end

function TelegramPlugin:onShowAbout()
    local DataStorage = require("datastorage")
    local current_version = self:getLocalVersion()
    local ver_status = "(latest)"
    
    if self.remote_version then
        if self:compareVersions(self.remote_version, current_version) > 0 then
            ver_status = "(v" .. self.remote_version .. " available!)"
        end
    end
    
    local settings_path = DataStorage:getSettingsDir() .. "/settings.reader.lua"
    local cache_dir = CacheManager.get_cache_dir()
    
    local text = string.format("Errol v%s %s\n\n", current_version, ver_status)
    text = text .. "Official repository:\nhttps://github.com/agaragou/errol.koplugin\n\n"
    text = text .. DEPENDENCIES.i18n("Settings stored in:") .. "\n" .. settings_path .. "\n\n"
    text = text .. DEPENDENCIES.i18n("Cache stored in:") .. "\n" .. cache_dir
    
    DEPENDENCIES.ui:show(DEPENDENCIES.info:new{
        text = text,
        timeout = nil, -- Stay until tapped
        show_icon = true,
        icon = "info",
    })
end

function TelegramPlugin:check_cache_on_startup()
    local count = CacheManager.count()
    if count == 0 then return end

    local http = load_dep("http")
    -- Check connectivity
    local _, c = http.request("http://clients3.google.com/generate_204")
    
    if c == 204 then
        -- Online: Send immediately
        BackgroundRunner.start(true)
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = string.format("Errol: Sending %d cached highlights...", count), duration = 3 })
    else
        -- Offline
        -- ... logic handled in autosend check
        if SettingsManager.get_autosend_enabled() then
             DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ 
                text = string.format("Errol: Autosend ON.\n%d highlights will be sent when online.", count), 
                duration = 5 
            })
             -- Start runner to watch for connection
             BackgroundRunner.start()
        else
            DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ 
                text = string.format("Errol:\n%d cached highlights waiting.\nAutosend is OFF!", count), 
                duration = 5 
            })
        end
    end
end

function TelegramPlugin:show_highlights_browser(callback_close)
    local Device = require("device")
    local Screen = require("device").screen
    local Menu = require("ui/widget/menu")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local ConfirmBox = require("ui/widget/confirmbox")
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager = require("ui/uimanager")

    
    -- 1. Fetch Bookmarks
    local bookmarks = {}
    
    -- Option A1: ReaderAnnotation (Active memory - Primary Source)
    -- This mimics ReaderHighlight behavior and is the most reliable source for the current session.
    if self.ui and self.ui.annotation and self.ui.annotation.annotations then
        bookmarks = self.ui.annotation.annotations
    end

    -- Option A2: DocSettings (Persisted memory - Fallback)
    local count = 0
    for _ in pairs(bookmarks) do count = count + 1 end
    
    if count == 0 and self.ui and self.ui.doc_settings and self.ui.doc_settings.data and self.ui.doc_settings.data.bookmarks then
        bookmarks = self.ui.doc_settings.data.bookmarks
    end

    -- Option B: Disk (DocSettings API - Fallback)
    -- ... (Previous disk logic omitted for brevity as memory sources should succeed now, 
    -- but if you want to be extremely safe, we could keep the manual read. 
    -- Given the user confirmed `ui.annotation` is the way, sticking to that is cleaner,
    -- but I will keep the manual read logic if I can easily fit it, or simplify.)
    
    -- Let's keep the Manual Read as a last resort "Option C"
    count = 0
    for _ in pairs(bookmarks) do count = count + 1 end
    
    if count == 0 and self.ui and self.ui.document and self.ui.document.file then
        local fpath = self.ui.document.file
        local lfs = load_dep("lfs")
        local sdr_path = fpath .. ".sdr"
        local meta_path = sdr_path .. "/metadata.lua"
        
        if lfs.attributes(meta_path) then
             local chunk = loadfile(meta_path)
             if chunk then
                 setfenv(chunk, {})
                 local success, ret = pcall(chunk)
                 if success and ret and ret.bookmarks then
                     bookmarks = ret.bookmarks
                 end
             end
        end
    end
    
    -- Helper to resolve page number from cache or XPointer
    local function getUiPage(item)
        -- 1. Try pre-calculated 'pageno' (best)
        if item.pageno and type(item.pageno) == "number" then
            return item.pageno
        end
        
        -- 2. Try 'page' (could be XPointer or string number)
        local p_in = item.page
        if type(p_in) == "number" then return p_in end
        if type(p_in) == "string" and self.ui.document then
            -- Try XPointer resolution if valid
            if self.ui.document.getGeomPageFromXPointer then
                local n = self.ui.document:getGeomPageFromXPointer(p_in)
                if n then return n end
            end
            -- Fallback: try to match simple number in string
            local num = tonumber(p_in)
            if num then return num end
        end
        return 0 -- fallback for sort
    end

    -- 2. Filter Highlights and Sort
    local highlights = {}
    for _, item in pairs(bookmarks) do
        if (item.text and item.text ~= "") or (item.type == "highlight") then
             local h = {
                 text = item.text or "[Image/Drawing]",
                 page = item.page, -- Keep original for reference
                 ui_page = getUiPage(item), -- Resolved number for UI/Sort
                 datetime = item.datetime,
                 chapter = item.chapter -- Store chapter too
             }
             if h.text ~= "" then
                table.insert(highlights, h)
             end
        end
    end
    
    -- Sort by page (numeric)
    table.sort(highlights, function(a, b)
        if a.ui_page ~= b.ui_page then return a.ui_page < b.ui_page end
        return (a.datetime or "") < (b.datetime or "")
    end)
    
    if #highlights == 0 then
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "No highlights found in this book.", duration = 3 })
        if callback_close then callback_close() end
        return
    end

    -- 3. Build Menu Items
    local menu_items = {}
    for i, item in ipairs(highlights) do
        local pg_label = (item.ui_page > 0) and item.ui_page or "?"
        table.insert(menu_items, {
            text = makeHighlightPreview(item.text, pg_label),
            keep_menu_open = true,
            callback = function(menu_instance)
                -- Construct Full Preview Text (Ghost Message)
                local data = SystemLayer.get_document_metadata(self.ui.document)
                local opts = {
                    page = item.ui_page,
                    datetime = item.datetime,
                    chapter = item.chapter
                }
                -- Generate what the message WOULD look like, for the preview
                local preview_html = TelegramExporter.compose_message(item.text, data, opts)

                -- Show Unified Action Dialog
                local actions_dialog
                actions_dialog = self:show_preview_dialog(preview_html, {
                    {
                        {
                            text = "Cancel",
                            callback = function() 
                                actions_dialog:onClose()
                            end,
                        },
                        {
                            text = "Spoiler",
                            callback = function()
                                actions_dialog:onClose()
                                -- Force spoiler override
                                opts.spoiler = true 
                                local msg = TelegramExporter.compose_message(item.text, data, opts)
                                TelegramExporter.execute_delivery(msg, nil)
                            end,
                        },
                         {
                            text = "Send",
                            callback = function()
                                actions_dialog:onClose()
                                local msg = TelegramExporter.compose_message(item.text, data, opts)
                                TelegramExporter.execute_delivery(msg, nil)
                            end,
                        },
                    }
                })
            end
        })
    end

    -- 4. Show Menu (Queue Style)
    local menu_container = CenterContainer:new{
        dimen = Screen:getSize(),
        covers_fullscreen = true,
        ignore = "height",
    }
    
    local browser_menu = Menu:new{
        title = "Book Highlights",
        item_table = menu_items,
        width = Screen:getWidth(), -- Full width
        show_parent = menu_container,
        is_popout = true, -- Better input handling
        is_enable_shortcut = false, -- Disable Q/W/E shortcuts
        close_callback = function()
            UIManager:close(menu_container)
            if callback_close then callback_close() end
        end,
    }

    -- Enable keep_menu_open support
    function browser_menu:onMenuSelect(item)
        if item.callback then item.callback(self) end
        if not item.keep_menu_open and self.close_callback then
            self.close_callback()
        end
        return true
    end
    
    table.insert(menu_container, browser_menu)
    UIManager:show(menu_container)
end

function TelegramPlugin:onAnnotationContextMenu(menu, item)
    if not (item and item.text) then return end
    menu:addItem{
        text = DEPENDENCIES.i18n("Errol"),
        callback = function()
            local data = SystemLayer.get_document_metadata(self.ui.document)
            -- Pass nil for override so it respects global setting
            local msg = TelegramExporter.compose_message(item.text, data, nil)
            TelegramExporter.execute_delivery(msg, nil)
        end
    }
    menu:addItem{
        text = DEPENDENCIES.i18n("Errol: Send as spoiler"),
        callback = function()
            local data = SystemLayer.get_document_metadata(self.ui.document)
            -- Pass true to force spoiler
            local msg = TelegramExporter.compose_message(item.text, data, true)
            TelegramExporter.execute_delivery(msg, nil)
        end
    }
end



function TelegramPlugin:addToMainMenu(menu_items)
    local item = self:onMainMenuItems()[1]
    item.sorting_hint = "tools"
    menu_items.errol = item
end

function TelegramPlugin:_showIntervalDialog(callback)
    local InputDialog = require("ui/widget/inputdialog")
    local input
    input = InputDialog:new{
        title = DEPENDENCIES.i18n("Set Check Interval (minutes)"),
        input = tostring(SettingsManager.get_interval()),
        input_type = "number",
        buttons = {
            {
                {
                    text = DEPENDENCIES.i18n("Cancel"),
                    id = "close",
                    callback = function()
                        DEPENDENCIES.ui:close(input)
                    end,
                },
                {
                    text = DEPENDENCIES.i18n("Save"),
                    id = "save",
                    is_enter_default = true,
                    callback = function()
                        local val = tonumber(input:getInputText())
                        if val and val > 0 then
                            SettingsManager.set_interval(val)
                            
                            -- Restart runner if enabled and active (or queue exists)
                            if SettingsManager.get_autosend_enabled() and CacheManager.count() > 0 then
                                BackgroundRunner.stop() -- Cancel old interval
                                BackgroundRunner.start() -- Start new interval
                                DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Interval saved & restarted!", duration = 1 })
                            else
                                DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Saved!", duration = 1 })
                            end
                            
                            if callback then callback() end
                        end
                        DEPENDENCIES.ui:close(input)
                    end,
                },
            },
        },
    }
    DEPENDENCIES.ui:show(input)
end

function TelegramPlugin:_showDownloadDirDialog(callback)
    local filemanagerutil = require("apps/filemanager/filemanagerutil")
    local current = SettingsManager.get_download_dir()
    filemanagerutil.showChooseDialog(
        DEPENDENCIES.i18n("Select Download Folder"),
        function(path)
            if path then
                SettingsManager.set_download_dir(path)
                DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Download folder saved:\n" .. path, duration = 3 })
                if callback then callback() end
            end
        end,
        current
    )
end

function TelegramPlugin:onMainMenuItems()
    local interval_item = {}
    
    local function update_interval_text()
        interval_item.text = string.format(DEPENDENCIES.i18n("Check wifi interval: %d min"), SettingsManager.get_interval())
    end
    
    update_interval_text() -- Initial set

    interval_item.keep_menu_open = true
    interval_item.callback = function(touchmenu_instance)
        self:_showIntervalDialog(function()
            update_interval_text()
            if touchmenu_instance then touchmenu_instance:updateItems() end
        end)
    end

    local download_dir_item = {
        text = DEPENDENCIES.i18n("Set Download Directory (Telegram)"),
        callback = function(touchmenu_instance)
            self:_showDownloadDirDialog(function()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end)
        end
    }

    local platforms_item = {
        text = DEPENDENCIES.i18n("Platforms"),
        sub_item_table = {
            {
                text = "Telegram",
                checked_func = function() return SettingsManager.is_telegram_enabled() end,
                callback = function(tm)
                    SettingsManager.set_telegram_enabled(not SettingsManager.is_telegram_enabled())
                    if tm then tm:updateItems() end
                end,
            },
            {
                text = "Discord",
                checked_func = function() return SettingsManager.is_discord_enabled() end,
                callback = function(tm)
                    SettingsManager.set_discord_enabled(not SettingsManager.is_discord_enabled())
                    if tm then tm:updateItems() end
                end,
            },
        }
    }

    local datetime_item = {
        text = DEPENDENCIES.i18n("Date & Time Format"),
        sub_item_table = {
            {
                text = DEPENDENCIES.i18n("24-hour Time"),
                checked_func = function() return SettingsManager.is_time_24h() end,
                callback = function(tm)
                    SettingsManager.set_time_24h(not SettingsManager.is_time_24h())
                    if tm then tm:updateItems() end
                end,
            },
            {
                text = DEPENDENCIES.i18n("Date: DD MMM YYYY (18 Dec 2025)"),
                checked_func = function() return SettingsManager.is_date_day_first() end,
                callback = function(tm)
                    SettingsManager.set_date_day_first(true)
                    if tm then tm:updateItems() end
                end,
            },
            {
                text = DEPENDENCIES.i18n("Date: MMM DD YYYY (Dec 18 2025)"),
                checked_func = function() return not SettingsManager.is_date_day_first() end,
                callback = function(tm)
                    SettingsManager.set_date_day_first(false)
                    if tm then tm:updateItems() end
                end,
            },
        }
    }

    local settings_submenu = {
        text = DEPENDENCIES.i18n("Settings"),
        sub_item_table = {
            interval_item,
            platforms_item,
            datetime_item,
            download_dir_item,
            {
                text = DEPENDENCIES.i18n("About"),
                callback = function()
                    self:onShowAbout()
                end
            }
        }
    }

    local autosend_item = {
        text = DEPENDENCIES.i18n("Autosend when online"),
        checked_func = function() return SettingsManager.get_autosend_enabled() end,
        callback = function(touchmenu_instance) 
            local new_state = not SettingsManager.get_autosend_enabled()
            SettingsManager.set_autosend_enabled(new_state)
            if touchmenu_instance then touchmenu_instance:updateItems() end

            if new_state and CacheManager.count() > 0 then
                -- If enabling and we have debt, restart runner logic
                BackgroundRunner.stop()
                BackgroundRunner.start()
                DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Autosend enabled. Waiting for connection...", duration = 3 })
            end
        end,
    }

    local queue_item = {}
    local function update_queue_text()
        local c = CacheManager.count()
        if c > 0 then
            queue_item.text = string.format(DEPENDENCIES.i18n("Queue (%d)"), c)
        else
            queue_item.text = DEPENDENCIES.i18n("Queue (empty)")
        end
    end
    update_queue_text()

    queue_item.callback = function(touchmenu_instance)
        self:show_queue_manager(function()
            update_queue_text()
            if touchmenu_instance then touchmenu_instance:updateItems() end
        end)
    end

    return {
        {
            text = "Errol",
            sub_item_table = {
                settings_submenu,
                autosend_item,
                {
                    text = DEPENDENCIES.i18n("Mark as Spoiler"),
                    checked_func = function() return SettingsManager.is_spoiler_enabled() end,
                    callback = function(tm)
                        SettingsManager.set_spoiler_enabled(not SettingsManager.is_spoiler_enabled())
                        if tm then tm:updateItems() end
                    end,
                },
                {
                    text = DEPENDENCIES.i18n("Download Books (Telegram)"),
                    callback = function()
                        TelegramDownloader.download_updates()
                    end
                },
                {
                    text = "Book Highlights", -- New Archive Item
                    callback = function(touchmenu_instance)
                         self:show_highlights_browser(function()
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end)
                    end
                },
                queue_item,
            }
        }
    }
end


function TelegramExporter.get_preview(html, full)
    local t = html or ""
    if not full then
        t = t:match("<blockquote>(.-)</blockquote>") or t
        t = t:gsub("<.->", "")
        -- Use a safe large limit if we really must, but Menu handles it.
        -- Removing manual byte truncation to fix UTF-8 display issues.
        return t
    end
    -- Backward compatibility for raw text usage
    return TelegramExporter.format_ui_text(html)
end

function TelegramExporter.format_ui_text(html)
    if not html then return "" end
    local t = html
    
    -- 1. Mark Spoilers (open only, text on new line)
    t = t:gsub('<span class="tg%-spoiler">(.-)</span>', "[SPOILER]\n%1")
    
    -- 2. Strip Metadata Emojis/Headers from Preview
    t = t:gsub("📖 ", "")
    t = t:gsub("📑 ", "")
    t = t:gsub("📄 ", "")
    t = t:gsub("📆 ", "")
    
    -- 3. Strip Hashtag lines
    t = t:gsub("🏷️.-[\r\n]+", "")
    t = t:gsub("🏷️.-$", "")

    -- 4. Newlines
    t = t:gsub("<br%s*/?>", "\n")
    t = t:gsub("<blockquote>", "") 
    t = t:gsub("</blockquote>", "")
    
    -- 5. Strip remaining tags
    t = t:gsub("<.->", "") 
    
    -- 6. Cleanup excessive whitespace and blank lines
    -- Allow one blank line (2 \n) but collapse 3+ into 2
    t = t:gsub("\n\n\n+", "\n\n") 
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    
    return t
end

function TelegramPlugin:show_preview_dialog(text_content, buttons_def)
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager = require("ui/uimanager")
    
    local clean_text = TelegramExporter.format_ui_text(text_content)
    
    -- Truncate for display if too long (approx 700 chars to fit most screens)
    if #clean_text > 700 then
        clean_text = clean_text:sub(1, 700) .. "...\n(Display truncated, full text will be sent)"
    end
    
    local d
    d = ButtonDialog:new{
        title = clean_text,
        title_align = "left", -- Better for long text reading
        buttons = buttons_def
    }
    UIManager:show(d)
    return d
end

function TelegramPlugin:show_queue_manager(on_close_callback)
    local Device = require("device")
    local Screen = Device.screen
    local Menu = require("ui/widget/menu")
    local CenterContainer = require("ui/widget/container/centercontainer")

    local q = CacheManager.load_queue()
    if #q == 0 then
        DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Queue is empty", duration = 2 })
        return
    end

    local menu_container = CenterContainer:new{
        dimen = Screen:getSize(),
        covers_fullscreen = true,
        ignore = "height",
    }

    local menu_items = {{
        text = DEPENDENCIES.i18n("Send All Now"),
        callback = function()
            BackgroundRunner.stop()
            BackgroundRunner.start(true)
            DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Sending queue...", duration = 2 })
            DEPENDENCIES.ui:close(menu_container)
            if on_close_callback then on_close_callback() end
        end
    }}

    for i, item in ipairs(q) do
        table.insert(menu_items, {
            text = string.format("%d. %s", i, TelegramExporter.get_preview(item.text)),
            keep_menu_open = true,
            callback = function()
                local actions_dialog
                actions_dialog = self:show_preview_dialog(item.text, {
                    {
                        {
                            text = DEPENDENCIES.i18n("Cancel"),
                            callback = function()
                                actions_dialog:onClose()
                            end
                        },
                        {
                            text = DEPENDENCIES.i18n("Remove"),
                            callback = function()
                                if CacheManager.remove_item(i) then
                                     DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Deleted", duration = 1 })
                                     actions_dialog:onClose()
                                     DEPENDENCIES.ui:close(menu_container)
                                     self:show_queue_manager(on_close_callback)
                                else
                                     DEPENDENCIES.ui:show(DEPENDENCIES.info:new{ text = "Error deleting", duration = 2 })
                                end
                            end
                        }
                    }
                })
            end
        })
    end


    local queue_menu = Menu:new{
        title = DEPENDENCIES.i18n("Errol Queue"),
        item_table = menu_items,
        width = Screen:getWidth(),
        show_parent = menu_container,
        is_popout = true,
        is_enable_shortcut = false, -- Disable Q/W/E shortcuts
        close_callback = function() 
            DEPENDENCIES.ui:close(menu_container) 
            if on_close_callback then on_close_callback() end
        end
    }

    -- Override onMenuSelect to support keep_menu_open
    function queue_menu:onMenuSelect(item)
        if item.callback then
            item.callback()
        end
        if not item.keep_menu_open and self.close_callback then
            self.close_callback()
        end
        return true
    end
    
    table.insert(menu_container, queue_menu)
    DEPENDENCIES.ui:show(menu_container)
end

return TelegramPlugin
