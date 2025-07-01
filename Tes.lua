--[[
    Gabungan Script: Translator + Teleport + AutoDrive Pro + ESP + Aimbot
    Dibuat oleh: OpenAI GPT & Analis AI
    Kontributor: Yusuf (ESP & Aimbot)
    Versi: Final Profesional 2.1.2 (5-in-1, Bug Fix)
    Deskripsi: Mengimplementasikan UI multi-fitur dengan Translator, Teleport, AutoDrive, ESP, dan Aimbot.
               Semua fitur diatur melalui satu GUI dan disimpan dalam satu file konfigurasi.
               [FIX] Memperbaiki crash akibat RadioButton pada menu Aimbot.
               [FIX] Memperbaiki crash "yield across C-call boundary" saat menekan tombol teleport.
    Perubahan: Mengganti header default ImGui dengan header kustom yang bisa minimize.
]]--

script_name("Menu Gabungan")
script_author("OpenAI GPT & AI Fixer & Yusuf")

--[[ ================================================= ]]--
--[[                    DEPENDENCIES                   ]]--
--[[ ================================================= ]]--

local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
local encoding = require 'encoding'
local vector3d = require 'vector3d'
local http = require('socket.http')
local ltn12 = require('ltn12')
local inicfg = require 'inicfg'
local ffi = require('ffi')
local gta = ffi.load('GTASA')
local widgets = require 'widgets'         -- Dependency untuk Aimbot
local SAMemory = require 'SAMemory'       -- Dependency untuk Aimbot
SAMemory.require('CCamera')               -- Dependency untuk Aimbot

encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new

ffi.cdef[[
    typedef struct { float x, y, z; } RwV3d;
    void _ZN4CPed15GetBonePositionER5RwV3djb(void* thiz, RwV3d* posn, uint32_t bone, bool calledFromCam);
]]

--[[ ================================================= ]]--
--[[               VARIABEL GLOBAL & KONFIGURASI       ]]--
--[[ ================================================= ]]--


--Update
local script_version = "1.0.0"
local version_url = "https://raw.githubusercontent.com/yu2sufxx/rdp/refs/heads/main/version.txt"
local script_url = "https://raw.githubusercontent.com/yu2sufxx/rdp/refs/heads/main/Tes.lua"
local update_available = false
local latest_version = "?"

-- GUI State
local show_ui = new.bool(false)
local minimized = new.bool(false) -- Variabel baru untuk status minimize
local active_menu_item = new.int(0) -- 0=Translator, 1=Teleport, 2=AutoDrive, 3=ESP, 4=Aimbot

-- INI Configuration (Satu file untuk semua fitur)
local ini_file = "ModMenuGabungan.ini"
local ini_defaults = {
    teleport_settings = { Sleep_Onfoot = 10, LoopWait_Onfoot = 100, Sleep_Incar = 5, LoopWait_Incar = 250, RenderBar_State = true },
    autodrive_settings = { ap_speed = 30.0, ap_ride_type = 0, ap_drive_type = 7 },
    esp_settings = {
        showLine = true, showBox = true, showBar = true, showSkeleton = true,
        showNametag = true, useRainbow = false, colorR = 1.0, colorG = 0.0,
        colorB = 0.0, colorA = 1.0
    },
    aimbot_settings = {
        enabled = true,
        maxDistance = 150.0,
        maxFOV = 1.0,
        selectedBone = 1, -- [FIX] Menggunakan integer: 0=Head, 1=Chest, 2=Groin
        showFOV = true
    }
}
local ini = inicfg.load(ini_defaults, ini_file)

local minimize = new.bool(false)

local show_popup = new.bool(false)

local screenX, screenY = getScreenResolution()
local MONET_DPI_SCALE = rawget(_G, 'MONET_DPI_SCALE') or (screenY / 720)



-- Translator State
local enabled_translator = new.bool(true)
local show_translator_log = new.bool(false)
local log_show_only_translated = new.bool(false)
local translator_log = {}
local input_lang = new.char[8]('id')
local target_lang = "id"
local api_url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&dt=t&tl="

-- Teleport State
local teleport, teleport_state = false, false
local one_percent, teleport_timer, distance = 0, 0, 0
local cx, cy, cz, bx, by, bz = 0, 0, 0, 0, 0, 0
local font
local vars_teleport = {
    sleep_onfoot = new.int(ini.teleport_settings.Sleep_Onfoot),
    loopwait_onfoot = new.int(ini.teleport_settings.LoopWait_Onfoot),
    sleep_incar = new.int(ini.teleport_settings.Sleep_Incar),
    loopwait_incar = new.int(ini.teleport_settings.LoopWait_Incar)
}

-- Checkpoint State (Satu untuk semua)
local checkpointCoords = { active = false, x = 0.0, y = 0.0, z = 0.0 }

-- AutoDrive Pro State
local ap = {
    active = { autopilot_on = new.bool(false), status_window = new.bool(false) },
    settings = {
        speed = new.float(ini.autodrive_settings.ap_speed),
        ride_type = new.int(ini.autodrive_settings.ap_ride_type),
        drive_type = new.int(ini.autodrive_settings.ap_drive_type)
    },
    status = { mode = 'none', target = { x = 0.0, y = 0.0, z = 0.0 }, target_dist = 0.0 }
}

-- ESP State
local esp = {
    showLine = new.bool(ini.esp_settings.showLine),
    showBox = new.bool(ini.esp_settings.showBox),
    showBar = new.bool(ini.esp_settings.showBar),
    showSkeleton = new.bool(ini.esp_settings.showSkeleton),
    showNametag = new.bool(ini.esp_settings.showNametag),
    useRainbow = new.bool(ini.esp_settings.useRainbow),
    colorFloat = new.float[4](ini.esp_settings.colorR, ini.esp_settings.colorG, ini.esp_settings.colorB, ini.esp_settings.colorA)
}
local rainbowHue = 0.0

-- Aimbot State
local aimbot = {
    enabled = new.bool(ini.aimbot_settings.enabled),
    maxDistance = new.float(ini.aimbot_settings.maxDistance),
    maxFOV = new.float(ini.aimbot_settings.maxFOV),
    selectedBoneInt = new.int(ini.aimbot_settings.selectedBone), -- [FIX] Menggunakan imgui.new.int
    showFOV = new.bool(ini.aimbot_settings.showFOV)
}
local WIDGET_FIRE = 1
local BONE = { HEAD = 5, CHEST = 3, GROIN = 2 }

--[[ ================================================= ]]--
--[[                  FUNGSI UTAMA (MAIN)              ]]--
--[[ ================================================= ]]--

function main()
    repeat wait(0) until isSampAvailable()
    font = renderCreateFont('Arial', 10, 5)
    sampRegisterChatCommand("menu", function() show_ui[0] = not show_ui[0] end)
    sampAddChatMessage("[Menu Gabungan] Ketik {00FF00}/menu{FFFFFF} untuk membuka GUI 5-in-1.", 0xFFFFFF)
    lua_thread.create(teleport_loop)
    lua_thread.create(renderInfoBar)
    lua_thread.create(aimbot_loop) -- Memulai loop logika Aimbot
end

--[[ ================================================= ]]--
--[[                  RENDER GUI (IMGUI)               ]]--
--[[ ================================================= ]]--
-- Jendela Menu Utama
imgui.OnFrame(function() return show_ui[0] end, function(player)
    local win_width = 500
    local win_height = 420
    local header_height = 35
    local btn_w = 24
    local btn_h = header_height - 6
    local btn_y = 3
    local spacing = imgui.GetStyle().ItemSpacing.x

    if minimized[0] then
        -- ========== WINDOW MINIMIZED ==========
        imgui.SetNextWindowSize(imgui.ImVec2(win_width, 50), imgui.Cond.Always)
        imgui.Begin("##ModMenuMin", show_ui, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)

        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.1, 0.1, 0.9, 1.0))
        imgui.BeginChild("##header_min", imgui.ImVec2(-1, 0), false,
    imgui.WindowFlags.NoScrollbar +
    imgui.WindowFlags.NoScrollWithMouse +
    imgui.WindowFlags.AlwaysAutoResize)

        local region = imgui.GetWindowContentRegionWidth()

        -- Tombol [+] Restore
        imgui.SetCursorPos(imgui.ImVec2(region - btn_w - 5, btn_y))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.3, 0.3, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.4, 0.4, 0.4, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.2, 0.2, 0.2, 1.0))
        if imgui.Button("+##restore", imgui.ImVec2(btn_w, btn_h)) then minimized[0] = false end
        imgui.PopStyleColor(3)

        -- Judul tengah
        local title = u8"Mod Menu"
        local text_w = imgui.CalcTextSize(title).x
        imgui.SetCursorPosY(6)
        imgui.SetCursorPosX((region / 2) - (text_w / 2))
        imgui.TextColored(imgui.ImVec4(1, 1, 1, 1), title)

        imgui.EndChild()
        imgui.PopStyleColor()
        imgui.End()
        return
    end

    -- ========== WINDOW FULL ==========
    imgui.SetNextWindowSize(imgui.ImVec2(win_width, win_height), imgui.Cond.FirstUseEver)
    imgui.Begin("##ModMenu", show_ui, imgui.WindowFlags.NoTitleBar)

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.1, 0.1, 0.9, 1.0))
    imgui.BeginChild("##header", imgui.ImVec2(-1, header_height), false)

    local region = imgui.GetWindowContentRegionWidth()

    -- Tombol [X]
    imgui.SetCursorPos(imgui.ImVec2(region - btn_w - 5, btn_y))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.0, 0.3, 0.3, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.6, 0.1, 0.1, 1.0))
    if imgui.Button("X##close", imgui.ImVec2(btn_w, btn_h)) then show_ui[0] = false end
    imgui.PopStyleColor(3)

    -- Tombol 🔄
    imgui.SetCursorPos(imgui.ImVec2(region - btn_w * 2 - spacing - 5, btn_y))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.8, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered,imgui.ImVec4(0.3, 0.7, 0.9, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,imgui.ImVec4(0.1, 0.5, 0.7, 1.0))
    -- Tombol UP (Update)
if imgui.Button("UP", imgui.ImVec2(btn_w, btn_h)) then
    imgui.OpenPopup("KonfirmasiUpdate")
end
     imgui.PopStyleColor(3)

-- Render popup langsung di dalam jendela utama
if imgui.BeginPopupModal("KonfirmasiUpdate", nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.TextWrapped("Apakah kamu yakin ingin memperbarui script sekarang?")
        imgui.Dummy(imgui.ImVec2(0, 10))

        if imgui.Button(" Ya", imgui.ImVec2(100, 35)) then
            print(">> Memulai update script...")
            updateScript("https://raw.githubusercontent.com/yu2sufxx/rdp/refs/heads/main/Tes.lua")
            Notifications.Show("Update berhasil!", Notifications.TYPE.OK)
            imgui.CloseCurrentPopup()
        end

        imgui.SameLine()

        if imgui.Button(" Batal", imgui.ImVec2(100, 35)) then
            print(">> Batal update.")
            imgui.CloseCurrentPopup()
        end

        imgui.SameLine()

        if imgui.Button("Cek Update", imgui.ImVec2(130, 35)) then
            print(">> Cek pembaruan...")
            cekUpdateOnline()
        end

        imgui.EndPopup()
    end
      

    -- Tombol [-]
    imgui.SetCursorPos(imgui.ImVec2(region - btn_w * 3 - spacing * 2 - 5, btn_y))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.3, 0.3, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.4, 0.4, 0.4, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.2, 0.2, 0.2, 1.0))
    if imgui.Button("-##minimize", imgui.ImVec2(btn_w, btn_h)) then minimized[0] = true end
    imgui.PopStyleColor(3)

    -- Judul tengah
    local title = u8"Mod Menu 1"
    local text_w = imgui.CalcTextSize(title).x
    imgui.SetCursorPosY(6)
    imgui.SetCursorPosX((region / 2) - (text_w / 2))
    imgui.TextColored(imgui.ImVec4(1, 1, 1, 1), title)

    imgui.EndChild()
    imgui.PopStyleColor()

    -- MINIMIZE MODE: Jika tidak minimize, tampilkan isi menu
    if not minimized[0] then

        -- PANEL KIRI
        imgui.BeginChild("LeftPanel", imgui.ImVec2(150, 0), true)
        if imgui.Selectable("Translator", active_menu_item[0] == 0) then active_menu_item[0] = 0 end
        if imgui.Selectable("Teleport", active_menu_item[0] == 1) then active_menu_item[0] = 1 end
        if imgui.Selectable("AutoDrive Pro", active_menu_item[0] == 2) then active_menu_item[0] = 2 end
        if imgui.Selectable("ESP", active_menu_item[0] == 3) then active_menu_item[0] = 3 end
        if imgui.Selectable("Aimbot", active_menu_item[0] == 4) then active_menu_item[0] = 4 end
        imgui.EndChild()

        imgui.SameLine()

        -- Panel Kanan (Konten Fitur)
        imgui.BeginChild("RightPanel", imgui.ImVec2(0, -35))
            if active_menu_item[0] == 0 then -- Konten Translator
                imgui.Text(u8"Pengaturan Translator"); imgui.Separator()
                imgui.Checkbox("Aktifkan Translator", enabled_translator)
                imgui.Checkbox("Tampilkan Jendela Log", show_translator_log)
                imgui.TextWrapped(u8"Jika Jendela Log aktif, terjemahan hanya akan muncul di sana (tidak di chat SA-MP).")
                imgui.Spacing()
                imgui.Text("Bahasa Target (ex: en, id, ja):")
                imgui.PushItemWidth(100)
                if imgui.InputText("##Lang", input_lang, 8) then target_lang = u8:decode(input_lang) end
                imgui.PopItemWidth()

            elseif active_menu_item[0] == 1 then -- Konten Teleport
                imgui.Text(u8"Fitur Teleport"); imgui.Separator()
                local btn_size = imgui.ImVec2(imgui.GetContentRegionAvail().x, 35)
                
                if imgui.Button("Teleport ke Marker", btn_size) then
                    lua_thread.create(function()
                        startTeleport('')
                    end)
                end
                if imgui.Button("Teleport ke Checkpoint", btn_size) then
                    lua_thread.create(function()
                        startTeleport('chp')
                    end)
                end
                
                imgui.Separator(); imgui.Text("Pengaturan Teleport")
                imgui.PushItemWidth(-1)
                if imgui.SliderInt(u8("Sleep OnFoot"), vars_teleport.sleep_onfoot, 0, 100) then ini.teleport_settings.Sleep_Onfoot = vars_teleport.sleep_onfoot[0] end
                if imgui.SliderInt(u8("LoopWait OnFoot"), vars_teleport.loopwait_onfoot, 0, 8500) then ini.teleport_settings.LoopWait_Onfoot = vars_teleport.loopwait_onfoot[0] end
                if imgui.SliderInt(u8("Sleep InCar"), vars_teleport.sleep_incar, 0, 100) then ini.teleport_settings.Sleep_Incar = vars_teleport.sleep_incar[0] end
                if imgui.SliderInt(u8("LoopWait InCar"), vars_teleport.loopwait_incar, 0, 8500) then ini.teleport_settings.LoopWait_Incar = vars_teleport.loopwait_incar[0] end
                imgui.PopItemWidth()
                local bar_text = ini.teleport_settings.RenderBar_State and "Info Bar: ON" or "Info Bar: OFF"
                if imgui.Button(bar_text, imgui.ImVec2(-1, 0)) then ini.teleport_settings.RenderBar_State = not ini.teleport_settings.RenderBar_State end

            elseif active_menu_item[0] == 2 then -- Konten AutoDrive Pro
                imgui.Text(u8"Fitur AutoDrive Pro"); imgui.Separator()
                local button_width = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) * 0.5
                if imgui.Button("Menuju Waypoint", imgui.ImVec2(button_width, 40)) then
                    getTargetBlipCoordinatesFixed(function(s, x, y, z)
                        if s then ap.status.target = {x=x, y=y, z=z}; startAutoPilot('waypoint')
                        else sampAddChatMessage("{FF0000}[AutoDrive]: Pasang waypoint dulu!", -1) end
                    end)
                end
                imgui.SameLine()
                if imgui.Button("Hentikan Autopilot", imgui.ImVec2(button_width, 40)) then stopAutoPilot("~y~Dihentikan manual.") end
                if imgui.Button("Menuju Checkpoint", imgui.ImVec2(-1, 40)) then
                    if checkpointCoords.active then ap.status.target = {x=checkpointCoords.x, y=checkpointCoords.y, z=checkpointCoords.z}; startAutoPilot('checkpoint')
                    else sampAddChatMessage("{FF0000}[AutoDrive]: Tidak ada checkpoint.", -1) end
                end
                if imgui.Button("Ikuti Rute Checkpoint", imgui.ImVec2(-1, 40)) then
                    if checkpointCoords.active then startAutoPilot('master')
                    else sampAddChatMessage("{FF0000}[AutoDrive]: Tidak ada checkpoint untuk memulai rute.", -1) end
                end
                imgui.Separator(); imgui.Text(u8"Kecepatan Maksimal:"); imgui.PushItemWidth(-1);
                if imgui.SliderFloat("##Speed", ap.settings.speed, 10.0, 150.0, "%.0f") then ini.autodrive_settings.ap_speed = ap.settings.speed[0] end; imgui.PopItemWidth()
                imgui.Text(u8"Gaya Mengemudi:");
                if imgui.RadioButtonIntPtr("Normal", ap.settings.ride_type, 0) then ini.autodrive_settings.ap_ride_type = 0 end; imgui.SameLine();
                if imgui.RadioButtonIntPtr("Langsung", ap.settings.ride_type, 2) then ini.autodrive_settings.ap_ride_type = 2 end; imgui.SameLine();
                if imgui.RadioButtonIntPtr("Agresif", ap.settings.ride_type, 3) then ini.autodrive_settings.ap_ride_type = 3 end
                imgui.Text(u8"Perilaku Berkendara:");
                if imgui.RadioButtonIntPtr("Patuhi Aturan", ap.settings.drive_type, 0) then ini.autodrive_settings.ap_drive_type = 0 end; imgui.SameLine();
                if imgui.RadioButtonIntPtr("Hindari Mobil", ap.settings.drive_type, 2) then ini.autodrive_settings.ap_drive_type = 2 end; imgui.SameLine();
                if imgui.RadioButtonIntPtr("Ugal-ugalan", ap.settings.drive_type, 7) then ini.autodrive_settings.ap_drive_type = 7 end

            elseif active_menu_item[0] == 3 then -- KONTEN ESP
                imgui.Text(u8"Pengaturan ESP"); imgui.Separator()
                if imgui.Checkbox("ESP Line", esp.showLine) then ini.esp_settings.showLine = esp.showLine[0] end
                if imgui.Checkbox("ESP Box", esp.showBox) then ini.esp_settings.showBox = esp.showBox[0] end
                if imgui.Checkbox("Health/Armor Bar", esp.showBar) then ini.esp_settings.showBar = esp.showBar[0] end
                if imgui.Checkbox("Skeleton", esp.showSkeleton) then ini.esp_settings.showSkeleton = esp.showSkeleton[0] end
                if imgui.Checkbox("NameTag + ID", esp.showNametag) then ini.esp_settings.showNametag = esp.showNametag[0] end
                imgui.Separator()
                if imgui.Checkbox("Rainbow Color", esp.useRainbow) then ini.esp_settings.useRainbow = esp.useRainbow[0] end
                if not esp.useRainbow[0] then
                    if imgui.ColorEdit4("ESP Color", esp.colorFloat) then
                        ini.esp_settings.colorR = esp.colorFloat[0]; ini.esp_settings.colorG = esp.colorFloat[1];
                        ini.esp_settings.colorB = esp.colorFloat[2]; ini.esp_settings.colorA = esp.colorFloat[3];
                    end
                end

            elseif active_menu_item[0] == 4 then -- KONTEN AIMBOT
                imgui.Text(u8"Pengaturan Aimbot"); imgui.Separator()
                if imgui.Checkbox("Aktifkan Aimbot", aimbot.enabled) then ini.aimbot_settings.enabled = aimbot.enabled[0] end
                if imgui.Checkbox("Tampilkan Lingkaran FOV", aimbot.showFOV) then ini.aimbot_settings.showFOV = aimbot.showFOV[0] end
                imgui.Separator()
                imgui.PushItemWidth(-1)
                if imgui.SliderFloat("Jarak Target Maks", aimbot.maxDistance, 10.0, 300.0, "%.0f m") then ini.aimbot_settings.maxDistance = aimbot.maxDistance[0] end
                if imgui.SliderFloat("Field of View (FOV)", aimbot.maxFOV, 0.1, 2.5, "%.2f rad") then ini.aimbot_settings.maxFOV = aimbot.maxFOV[0] end
                imgui.PopItemWidth()
                imgui.Separator()
                imgui.Text("Target Tulang (Bone):")
                if imgui.RadioButtonIntPtr("Kepala", aimbot.selectedBoneInt, 0) then ini.aimbot_settings.selectedBone = 0 end; imgui.SameLine()
                if imgui.RadioButtonIntPtr("Dada", aimbot.selectedBoneInt, 1) then ini.aimbot_settings.selectedBone = 1 end; imgui.SameLine()
                if imgui.RadioButtonIntPtr("Perut", aimbot.selectedBoneInt, 2) then ini.aimbot_settings.selectedBone = 2 end
            end
        imgui.EndChild()

        imgui.Separator()
        if imgui.Button("Simpan Semua Pengaturan", imgui.ImVec2(-1, 0)) then
            inicfg.save(ini, ini_file)
            sampAddChatMessage("{00FF00}[Menu Gabungan] Semua pengaturan telah disimpan.", 0xFFFFFF)
        end
    end -- Akhir dari blok 'if not minimized'

    imgui.End()
end)

-- Jendela Log Terjemahan
imgui.OnFrame(function() return show_translator_log[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(450, 250), imgui.Cond.FirstUseEver)
    imgui.Begin("Log Terjemahan", show_translator_log)
    imgui.Checkbox("Tampilkan Hanya Terjemahan", log_show_only_translated)
    imgui.Separator()
    imgui.BeginChild("LogScrollingRegion", imgui.ImVec2(0, 0), false, imgui.WindowFlags.HorizontalScrollbar)
    for _, log_entry in ipairs(translator_log) do
        if log_show_only_translated[0] then
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.6, 0.8, 1.0, 1.0))
            imgui.TextWrapped(u8("[T]: " .. log_entry.translated)); imgui.PopStyleColor(); imgui.Separator()
        else
            imgui.TextWrapped(u8(log_entry.original))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.6, 0.8, 1.0, 1.0))
            imgui.TextWrapped(u8("[T]: " .. log_entry.translated)); imgui.PopStyleColor(); imgui.Separator()
        end
    end
    if imgui.GetScrollY() >= imgui.GetScrollMaxY() then imgui.SetScrollHereY(1.0) end
    imgui.EndChild()
    imgui.End()
end)

imgui.OnFrame(function() return show_popup[0] end, function()
    if imgui.BeginPopupModal("PopupSederhana", nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.Text("Ini adalah popup sederhana!")

        imgui.Dummy(imgui.ImVec2(0, 10))
        if imgui.Button("Tutup") then
            imgui.CloseCurrentPopup()
            show_popup[0] = false -- WAJIB: supaya bisa dibuka lagi nanti
        end

        imgui.End()
    end
end)

-- Jendela Status Autopilot
imgui.OnFrame(function() return ap.active.status_window[0] end, function()
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw - 160, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(240, 110), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Status Autopilot", ap.active.status_window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove)
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        imgui.Text(u8(string.format("Kecepatan: %.0f", getCarSpeed(car))))
        imgui.Text(u8(string.format("Jarak: %.0f m", ap.status.target_dist)))
        imgui.Text(u8(string.format("Mode: %s", ap.status.mode)))
    end
    imgui.Separator()
    imgui.Text(u8("Mengemudi ke tujuan..."))
    imgui.End()
end)

-- ESP & Aimbot FOV Drawing Loop
imgui.OnFrame(function() return true end, function()
    local drawList = imgui.GetBackgroundDrawList()
    
    if aimbot.enabled[0] and aimbot.showFOV[0] then
        local sx, sy = getScreenResolution()
        local crossX, crossY = sx * 0.52, sy * 0.43
        local radius = (sx / 3) * (aimbot.maxFOV[0] / 2.5)
        drawList:AddCircle(imgui.ImVec2(crossX, crossY), radius, 0x8800AFFF, 64, 2.0)
    end

    local screenX, screenY = getScreenResolution()
    local centerX = screenX / 2; local lineStartY = 80
    local color = getEspColor(); local colorArmor = 0xFF00FFFF

    for i = 0, sampGetMaxPlayerId(true) do
        if sampIsPlayerConnected(i) then
            local ok, ped = sampGetCharHandleBySampPlayerId(i)
            if ok and doesCharExist(ped) and not isCharDead(ped) and isCharOnScreen(ped) then
                local headX, headY, headZ = getBonePosition(ped, 4)
                local footX, footY, footZ = getCharCoordinates(ped)
                local okTop, sxTop, syTop = convert3DCoordsToScreenEx(headX, headY, headZ + 0.3)
                local okBottom, sxBottom, syBottom = convert3DCoordsToScreenEx(footX, footY, footZ - 0.9)
                if okTop and okBottom then
                    local height = syBottom - syTop
                    local width = height * 0.5
                    local boxX = sxTop - width / 2
                    local boxY = syTop
                    if esp.showLine[0] then drawEspLine(drawList, centerX, lineStartY, sxTop, syTop, color, 2.0) end
                    if esp.showBox[0] then drawEspBox(drawList, boxX, boxY, width, height, color, 2.0) end
                    if esp.showBar[0] then
                        local hp = sampGetPlayerHealth(i); local ap = sampGetPlayerArmor(i); local barW = 8
                        drawEspBar(drawList, boxX - barW - 4, boxY, barW, height, hp, color, "HP")
                        drawEspBar(drawList, boxX + width + 4, boxY, barW, height, ap, colorArmor, "AP")
                    end
                    if esp.showSkeleton[0] then drawEspSkeleton(drawList, ped, color) end
                    if esp.showNametag[0] then
                        local name = sampGetPlayerNickname(i); local text = string.format("%s [%d]", name, i)
                        local textSize = imgui.CalcTextSize(text)
                        drawEspText(drawList, sxTop - textSize.x / 2, syTop - 18, 0xFFFFFFFF, text)
                    end
                end
            end
        end
    end
end)

--[[ ================================================= ]]--
--[[                  EVENT HANDLERS                   ]]--
--[[ ================================================= ]]--

function sampev.onSetCheckpoint(position, size)
    checkpointCoords.active = true
    checkpointCoords.x = position.x
    checkpointCoords.y = position.y
    checkpointCoords.z = position.z
end

function sampev.onDisableCheckpoint()
    checkpointCoords.active = false
end

function sampev.onSetRaceCheckpoint(type, position, nextPosition, radius)
    checkpointCoords.active = true
    checkpointCoords.x = position.x
    checkpointCoords.y = position.y
    checkpointCoords.z = position.z
end

function sampev.onDisableRaceCheckpoint()
    checkpointCoords.active = false
end

function sampev.onServerMessage(color, text)
    if enabled_translator[0] and text and text ~= "" then
        lua_thread.create(function()
            local url = api_url .. target_lang .. "&q=" .. urlencode(text)
            local body = {}
            local res, code = http.request{ url = url, sink = ltn12.sink.table(body) }
            if res and code == 200 then
                local translated = parseGoogleTranslate(table.concat(body))
                if translated and translated ~= text then
                    if not show_translator_log[0] then
                        sampAddChatMessage("[T]: " .. translated, 0xAAAAFFFF)
                    end
                    table.insert(translator_log, { original = text, translated = translated })
                    if #translator_log > 50 then table.remove(translator_log, 1) end
                end
            end
        end)
    end
end

--[[ ================================================= ]]--
--[[              FUNGSI-FUNGSI TRANSLATOR DAN UPDATE       ]]--
--[[ ================================================= ]]--

function parseGoogleTranslate(json)
    if not json then return nil end
    local match = json:match('%[%[%["(.-)"')
    if match then return match:gsub('\\"', '"'):gsub('\\n', '\n') end
    return nil
end

function urlencode(str)
    if not str then return "" end
    return str:gsub("\n", "\r\n"):gsub("([^%w%-_.~])", function(c) return string.format("%%%02X", string.byte(c)) end)
end

function cekUpdateOnline()
    lua_thread.create(function()
        sampAddChatMessage("[Updater] Mengecek versi terbaru...", 0x00FF00)
        local body, code = http.request(version_url)
        if code == 200 and body then
            latest_version = body:match("([%d%.]+)") or "?.?.?"
            if latest_version ~= script_version then
                update_available = true
                sampAddChatMessage("[Updater] Versi baru tersedia: " .. latest_version, 0x00FF00)
            else
                update_available = false
                sampAddChatMessage("[Updater] Script sudah versi terbaru (" .. script_version .. ")", 0x00FF00)
            end
        else
            sampAddChatMessage("[Updater] Gagal mengecek versi. HTTP: " .. tostring(code), 0xFF0000)
        end
    end)
end

function updateScript()
    lua_thread.create(function()
        sampAddChatMessage("[Updater] Mengunduh update...", 0x00FF00)
        local body, code = http.request(script_url)
        if code == 200 and body then
            local path = thisScript().path
            local f = io.open(path, "w")
            if f then
                f:write(body)
                f:close()
                sampAddChatMessage("[Updater] Berhasil update ke versi " .. latest_version .. ". Me-reload script...", 0x00FF00)
                wait(500)
                reloadScripts()
            else
                sampAddChatMessage("[Updater] Gagal menyimpan script!", 0xFF0000)
            end
        else
            sampAddChatMessage("[Updater] Gagal mengunduh file. HTTP: " .. tostring(code), 0xFF0000)
        end
    end)
end

--[[ ================================================= ]]--
--[[     FUNGSI-FUNGSI AUTODRIVE PRO (ANTI-NYANGKUT)   ]]--
--[[ ================================================= ]]--

function startAutoPilot(mode)
    if ap.active.autopilot_on[0] then
        printStringNow("~r~Autopilot sudah aktif!", 1000)
        return
    end
    if not isCharInAnyCar(PLAYER_PED) then
        sampAddChatMessage("{FF0000}[AutoDrive]: Anda harus di dalam mobil.", -1)
        return
    end

    ap.active.autopilot_on[0] = true
    ap.active.status_window[0] = true
    ap.status.mode = mode
    sampAddChatMessage("{00FF00}[AutoDrive]: Diaktifkan. Mengemudi...", -1)
    
    lua_thread.create(function()
        while ap.active.autopilot_on[0] do
            wait(250)
            if not isCharInAnyCar(PLAYER_PED) then
                stopAutoPilot("~y~Anda keluar dari mobil.")
                break
            end
            
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            local pX, pY, pZ = getCharCoordinates(PLAYER_PED)

            if ap.status.mode == 'master' then
                if checkpointCoords.active then
                    ap.status.target = {x = checkpointCoords.x, y = checkpointCoords.y, z = checkpointCoords.z}
                else
                    stopAutoPilot("~g~Rute selesai!")
                    break
                end
            end

            if ap.status.target then
                ap.status.target_dist = getDistanceBetweenCoords3d(pX, pY, pZ, ap.status.target.x, ap.status.target.y, ap.status.target.z)
                local stop_dist = (ap.status.mode == 'waypoint') and 10.0 or 8.0

                if ap.status.target_dist > stop_dist then
                    taskCarDriveToCoord(PLAYER_PED, car, ap.status.target.x, ap.status.target.y, ap.status.target.z, ap.settings.speed[0], ap.settings.ride_type[0], 0, ap.settings.drive_type[0])
                else
                    if ap.status.mode == 'master' then
                        printStringNow("~y~Checkpoint tercapai, menunggu berikutnya...", 1000)
                    else
                        stopAutoPilot("~g~Tujuan tercapai!")
                        break
                    end
                end
            else
                stopAutoPilot("~r~Target tidak ditemukan.")
                break
            end
        end
    end)
end

function stopAutoPilot(message)
    if ap.active.autopilot_on and not ap.active.autopilot_on[0] then return end
    if ap.status then ap.status.mode = 'none'; ap.status.target = nil end
    if ap.active.autopilot_on then ap.active.autopilot_on[0] = false end
    if ap.active.status_window then ap.active.status_window[0] = false end
    if isCharInAnyCar(PLAYER_PED) then
        clearCharTasks(PLAYER_PED)
        taskWarpCharIntoCarAsDriver(PLAYER_PED, storeCarCharIsInNoSave(PLAYER_PED))
        if last_car and doesVehicleExist(last_car) and was_in_car then
            freezeCarPosition(last_car, false); setCarCollision(last_car, true)
        end
    else
        freezeCharPosition(PLAYER_PED, false); setCharCollision(PLAYER_PED, true)
    end
    was_in_car = false
    if message then printStringNow(message, 2000) end
end

function getTargetBlipCoordinatesFixed(callback)
    lua_thread.create(function()
        local s, x, y, z = getTargetBlipCoordinates()
        if not s then callback(false); return end
        requestCollision(x, y); loadScene(x, y, z); wait(150)
        local groundZ = getGroundZFor3dCoord(x, y, z + 50.0)
        callback(true, x, y, groundZ)
    end)
end

--[[ ================================================= ]]--
--[[               FUNGSI-FUNGSI TELEPORT              ]]--
--[[ ================================================= ]]--

function startTeleport(mode)
    if teleport_state then sampAddChatMessage("Teleport sedang berjalan.", 0xFF0000FF); return end
    local found, tX, tY, tZ
    if mode == 'chp' then
        sampAddChatMessage("Mencari Checkpoint...", 0xFFFF00FF); found, tX, tY, tZ = getCheckPoint()
    else
        sampAddChatMessage("Mencari Marker...", 0xFFFF00FF); found, tX, tY, tZ = getMapMarker()
    end
    if found then
        cx, cy, cz = getCharCoordinates(PLAYER_PED); bx, by, bz = tX, tY, tZ
        if not (type(cx) == 'number' and type(bx) == 'number') then sampAddChatMessage("Error: Gagal mendapatkan koordinat yang valid.", 0xFF0000FF); return end
        distance = getDistanceBetweenCoords3d(cx, cy, cz, bx, by, bz); teleport, teleport_state = true, true
        one_percent = distance > 0 and distance / 100 or 0; teleport_timer = os.clock(); sampAddChatMessage("Teleport dimulai ke tujuan!", 0x00FF00FF)
    else
        if mode == 'chp' then sampAddChatMessage("Checkpoint tidak ditemukan!", 0xFF0000FF)
        else sampAddChatMessage("Marker tidak ditemukan!", 0xFF0000FF) end
    end
end

function teleport_loop()
    while true do wait(0)
        if teleport then
            if not isCharInAnyCar(PLAYER_PED) then onfoot_teleport_step() else incar_teleport_step() end
        end
    end
end

function onfoot_teleport_step()
    distance = getDistanceBetweenCoords3d(cx, cy, cz, bx, by, bz); local height = bz > cz
    for i = 1, math.floor(65 / 2) do
        if distance >= 20 then
            local vec = vector3d(bx - cx, by - cy, bz - cz); vec:normalize()
            cx, cy, cz = cx + vec.x * 2, cy + vec.y * 2, cz + vec.z * 2
            send_onfoot_sync(cx, cy, cz, height); distance = getDistanceBetweenCoords3d(cx, cy, cz, bx, by, bz)
            if math.random(0, 5) == 5 then wait(ini.teleport_settings.Sleep_Onfoot) end
        else
            wait(500); send_onfoot_sync(bx, by, bz, height); setCharCoordinates(PLAYER_PED, bx, by, bz)
            teleport, teleport_state = false, false; sampAddChatMessage("Teleport selesai.", 0x00FF00FF); return
        end
    end
    wait(ini.teleport_settings.LoopWait_Onfoot)
end

function incar_teleport_step()
    distance = getDistanceBetweenCoords3d(cx, cy, cz, bx, by, bz); local height = bz > cz
    for i = 1, math.floor(150 / 5) do
        if distance >= 20 then
            local vec = vector3d(bx - cx, by - cy, bz - cz); vec:normalize()
            cx, cy, cz = cx + vec.x * 5, cy + vec.y * 5, cz + vec.z * 5
            send_incar_sync(cx, cy, cz, height); distance = getDistanceBetweenCoords3d(cx, cy, cz, bx, by, bz)
            if math.random(0, 5) == 5 then wait(ini.teleport_settings.Sleep_Incar) end     
        else
            wait(1000); teleport = false; send_incar_sync(bx, by, bz, height); teleport_state = false
            setCharCoordinates(1, bx, by, bz); break
        end
        if i == stepfor then
            send_incar_sync(cx, cy, cz + 100, height); sampForceVehicleSync(); send_incar_sync(cx, cy, cz, height)
            wait(ini.teleport_settings.LoopWait_Incar)
        end
    end
end

function send_incar_sync(x, y, z, height)
    local data = samp_create_sync_data("vehicle")
    for i = 1, 3 do data.quaternion[i] = math.random(-1,1) end
    data.moveSpeed = { 0, 0, height and 0.25 or -0.25 }
    data.vehicleHealth = 1500; data.playerHealth = getCharHealth(PLAYER_PED)
    data.landingGearState = true; data.position = { x, y, z }; data.send()
end

function send_onfoot_sync(x, y, z, height)
    local data = samp_create_sync_data("player")
    data.quaternion[1] = math.random(-1,1); data.quaternion[3] = math.random(-1,1)
    data.moveSpeed = { 0.7, 0.7, height and -0.7 or 0.7 }; data.specialAction = 4
    data.animationId = 1018; data.animationFlags = 12211
    data.armor = getCharArmour(PLAYER_PED); data.weapon = getCurrentCharWeapon(PLAYER_PED)
    data.health = getCharHealth(PLAYER_PED); data.position = {x, y, z}; data.send()
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require "ffi"; local raknet = require "samp.raknet"; copy_from_player = copy_from_player or true
    local sync_traits = { player = {"PlayerSyncData", raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData}, vehicle = {"VehicleSyncData", raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData} }
    local sync_info = sync_traits[sync_type]; local data_type = "struct " .. sync_info[1]; local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast("uintptr_t", ffi.new(data_type .. "*", data)))
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED) else player_id = tonumber(copy_from_player) end
            if player_id then copy_func(player_id, raw_data_ptr) end
        end
    end
    local func_send = function() local bs = raknetNewBitStream(); raknetBitStreamWriteInt8(bs, sync_info[2]); raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data)); raknetSendBitStream(bs, 0, 3, 1); raknetDeleteBitStream(bs) end
    return setmetatable({send = func_send}, { __index = function(t, index) return data[index] end, __newindex = function(t, index, value) data[index] = value end })
end

--[[ ================================================= ]]--
--[[                  FUNGSI-FUNGSI ESP                ]]--
--[[ ================================================= ]]--

function HSVtoRGB(h, s, v)
    if s == 0 then return v, v, v end; local i = math.floor(h*6); local f = (h*6) - i
    local p = v*(1-s); local q = v*(1-s*f); local t = v*(1-s*(1-f)); i = i % 6
    if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v else return v, p, q end
end

function getEspColor()
    if esp.useRainbow[0] then
        rainbowHue = rainbowHue + 0.005; if rainbowHue > 1.0 then rainbowHue = 0.0 end
        local r, g, b = HSVtoRGB(rainbowHue, 1.0, 1.0)
        return imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, 1.0))
    else
        return imgui.GetColorU32Vec4(imgui.ImVec4(esp.colorFloat[0], esp.colorFloat[1], esp.colorFloat[2], esp.colorFloat[3]))
    end
end

function getBonePosition(ped, bone)
    local pedptr = ffi.cast('void*', getCharPointer(ped)); local pos = ffi.new("RwV3d[1]")
    gta._ZN4CPed15GetBonePositionER5RwV3djb(pedptr, pos, bone, false); return pos[0].x, pos[0].y, pos[0].z
end

function drawEspLine(drawList, x1, y1, x2, y2, color, thickness)
    drawList:AddLine(imgui.ImVec2(x1, y1), imgui.ImVec2(x2, y2), color, thickness)
end

function drawEspBox(drawList, x, y, w, h, color, thickness)
    drawList:AddRect(imgui.ImVec2(x, y), imgui.ImVec2(x + w, y + h), color, 0, 0, thickness)
end

function drawEspText(drawList, x, y, color, text)
    drawList:AddText(imgui.ImVec2(x, y), color, text)
end

function drawEspBar(drawList, x, y, w, h, value, color, label)
    if not value or value < 0 or value > 100 then return end
    local filled = h * (value / 100)
    drawList:AddRectFilled(imgui.ImVec2(x, y), imgui.ImVec2(x + w, y + h), 0x80000000)
    drawList:AddRectFilled(imgui.ImVec2(x, y + (h - filled)), imgui.ImVec2(x + w, y + h), color)
    drawList:AddRect(imgui.ImVec2(x, y), imgui.ImVec2(x + w, y + h), 0xFFFFFFFF, 0, 0, 1.0)
    if label and label ~= "" then
        local textSize = imgui.CalcTextSize(label); local textX = x + (w / 2) - (textSize.x / 2); local textY = y + h + 2
        drawEspText(drawList, textX, textY, 0xFFFFFFFF, label)
    end
end

local skeleton_connections = {{4,3},{3,2},{3,5},{5,51},{51,52},{3,4},{4,41},{41,42},{2,31},{31,32},{32,33},{2,21},{21,22},{22,23}}
function drawEspSkeleton(drawList, ped, color)
    for _, conn in ipairs(skeleton_connections) do
        local x1, y1, z1 = getBonePosition(ped, conn[1]); local x2, y2, z2 = getBonePosition(ped, conn[2])
        local r1, sx1, sy1 = convert3DCoordsToScreenEx(x1, y1, z1); local r2, sx2, sy2 = convert3DCoordsToScreenEx(x2, y2, z2)
        if r1 and r2 then drawEspLine(drawList, sx1, sy1, sx2, sy2, color, 2.0) end
    end
end

--[[ ================================================= ]]--
--[[                 FUNGSI-FUNGSI AIMBOT              ]]--
--[[ ================================================= ]]--

function convertCartesianToSpherical(src, dst)
    local vec = dst - src; local r = vec:length(); local phi = math.atan2(vec.y, vec.x)
    local theta = math.acos(vec.z / r); if phi > 0 then phi = phi - math.pi else phi = phi + math.pi end
    theta = math.pi / 2 - theta; return phi, theta
end

function getCameraRotation()
    local cam = SAMemory.camera; return cam.aCams[0].fHorizontalAngle, cam.aCams[0].fVerticalAngle
end

function setCameraRotation(phi, theta)
    local cam = SAMemory.camera; cam.aCams[0].fHorizontalAngle = phi; cam.aCams[0].fVerticalAngle = theta
end

function getDynamicCrosshairOffset(dist)
    local baseX, baseY = 0.53, 0.45; local offsetX, offsetY
    if dist <= 10.0 then offsetX = baseX - 0.003; offsetY = baseY - 0.004
    else local factor = math.min(dist/300.0, 1.0); offsetX = baseX - (0.01 * factor); offsetY = baseY - (0.015*factor) end
    return offsetX, offsetY
end

function getCrosshairSpherical(distance)
    local sx, sy = getScreenResolution(); local offsetX, offsetY = getDynamicCrosshairOffset(distance)
    local crossX, crossY = sx * offsetX, sy * offsetY
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local wx, wy, wz = convertScreenCoordsToWorld3D(crossX, crossY, distance)
    return convertCartesianToSpherical(vector3d(px, py, pz), vector3d(wx, wy, wz))
end

function aimToTarget(tx, ty, tz)
    local px, py, pz = getCharCoordinates(PLAYER_PED); local from = vector3d(px, py, pz); local to = vector3d(tx, ty, tz)
    local dist = getDistanceBetweenCoords3d(px, py, pz, tx, ty, tz)
    local phiTarget, thetaTarget = convertCartesianToSpherical(from, to)
    local phiCross, thetaCross = getCrosshairSpherical(dist)
    local phiCam, thetaCam = getCameraRotation()
    local phiFinal = phiCam + (phiTarget - phiCross); local thetaFinal = thetaCam + (thetaTarget - thetaCross)
    setCameraRotation(phiFinal, thetaFinal)
end

function getSelectedBone() -- [FIX] Menggunakan nilai integer
    local boneChoice = aimbot.selectedBoneInt[0]
    if boneChoice == 0 then return BONE.HEAD end
    if boneChoice == 2 then return BONE.GROIN end
    return BONE.CHEST -- Default untuk nilai 1
end

function getAngleDistance(a1, a2)
    local diff = a1 - a2; while diff > math.pi do diff = diff - 2*math.pi end
    while diff < -math.pi do diff = diff + 2*math.pi end; return math.abs(diff)
end

function aimbot_loop()
    while true do wait(0)
        if aimbot.enabled[0] and isWidgetPressed(WIDGET_FIRE) then
            local nearestDist = 9999; local tx, ty, tz = nil, nil, nil
            local px, py, pz = getCharCoordinates(PLAYER_PED); local phiCam, _ = getCameraRotation()
            local boneID = getSelectedBone()
            for i = 0, sampGetMaxPlayerId(true) do
                if sampIsPlayerConnected(i) then
                    local ok, ped = sampGetCharHandleBySampPlayerId(i)
                    if ok and doesCharExist(ped) and not isCharDead(ped) then
                        local x, y, z = getBonePosition(ped, boneID)
                        if x then
                            local dist = getDistanceBetweenCoords3d(px, py, pz, x, y, z)
                            if dist <= aimbot.maxDistance[0] then
                                local phiTarget, _ = convertCartesianToSpherical(vector3d(px, py, pz), vector3d(x, y, z))
                                local delta = getAngleDistance(phiTarget, phiCam)
                                if delta <= aimbot.maxFOV[0] and dist < nearestDist then
                                    nearestDist = dist; tx, ty, tz = x, y, z
                                end
                            end
                        end
                    end
                end
            end
            if tx then aimToTarget(tx, ty, tz) end
        end
    end
end

--[[ ================================================= ]]--
--[[            FUNGSI HELPER & RENDER INFO            ]]--
--[[ ================================================= ]]--

function getCheckPoint()
    if checkpointCoords.active then return true, checkpointCoords.x, checkpointCoords.y, checkpointCoords.z end
    return false, 0, 0, 0
end

function getMapMarker() return getTargetBlipCoordinates() end

function renderInfoBar()
    while true do wait(0)
        if ini.teleport_settings.RenderBar_State and teleport_state then
            local r, g, b, a = rainbow(0.5, 250, 1); local resX, resY = getScreenResolution()
            local x, y = resX / 2, resY / 1.5
            if teleport_state and one_percent > 0 then
                local time = os.clock() - teleport_timer; local percent = 100 - math.floor(distance / one_percent)
                percent = math.min(math.max(percent, 0), 100)
                renderFontDrawText(font, string.format('Teleporting... | %d%% | %.1fs', percent, time), x, y, join_argb(a, r, g, b))
            end
        end
    end
end

function join_argb(a,r,g,b) return bit.bor(b,bit.lshift(g,8),bit.lshift(r,16),bit.lshift(a,24)) end
function rainbow(s,a,o)
    local c = os.clock()+(o or 0); local r = math.floor(math.sin(c*s)*127+128)
    local g = math.floor(math.sin(c*s+2)*127+128); local b = math.floor(math.sin(c*s+4)*127+128)
    return r,g,b,a
end

--[[ ================================================= ]]--
--[[                 SAMP EVENT HOOKS                  ]]--
--[[ ================================================= ]]--

function sampev.onSendPlayerSync() if teleport_state then return false end end
function sampev.onSendVehicleSync() if teleport_state then return false end end
function sampev.onSetPlayerPos() if teleport_state then return false end end
function sampev.onClearPlayerAnimation() if teleport_state then return false end end
function sampev.onSetVehiclePosition() if teleport_state then return false end end
