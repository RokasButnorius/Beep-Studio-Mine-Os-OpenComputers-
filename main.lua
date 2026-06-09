local comp = require("component")
local event = require("event")
local compu = require("computer")
local fs = require("filesystem")
local gpu = comp.gpu
local sw, sh = gpu.getResolution()

local run, play, step, max_steps, tick, tempo = true, false, 1, 16, compu.uptime(), 0.25
local scroll, v_cols = 0, 8
local insts, c_inst = { "Normal", "Light", "Dark", "Violin", "Piano", "Guitar" }, 1
local freqs = { 659.25, 587.33, 523.25, 493.88, 440.00, 392.00, 349.23, 329.63, 261.63, 196.00 }
local names = { "E5", "D5", "C5", "B4", "A4", "G4", "F4", "E4", "C4", "G3" }

local c_bg, c_off, c_on, c_head, c_txt, c_btn, c_panel = 0x0A1220, 0x243348, 0x00FF66, 0xFFCC00, 0xDCE5F0, 0x3A5F8F, 0x162335
local gx, gy, cw, ch = 12, 5, 6, 1

local b_play, b_clr, b_inst, b_save, b_open, b_l, b_r, b_q = 
    {x1=12,y1=sh-4,x2=21,y2=sh-2}, {x1=23,y1=sh-4,x2=32,y2=sh-2}, {x1=34,y1=sh-4,x2=46,y2=sh-2},
    {x1=48,y1=sh-4,x2=56,y2=sh-2}, {x1=58,y1=sh-4,x2=66,y2=sh-2}, {x1=68,y1=sh-4,x2=72,y2=sh-2},
    {x1=74,y1=sh-4,x2=78,y2=sh-2}, {x1=80,y1=sh-4,x2=88,y2=sh-2}

local s_dir = "./"
if _G.OS and _G.OS.getCurrentUser then
    local u = _G.OS.getCurrentUser()
    if u then s_dir = "/Users/" .. u .. "/Desktop/" end
elseif fs.isDirectory("/Users/Default/Desktop/") then
    s_dir = "/Users/Default/Desktop/"
end
if s_dir:sub(-1) ~= "/" then s_dir = s_dir .. "/" end

local grid = {}
for r = 1, #freqs do
    grid[r] = {}
    for c = 1, max_steps do grid[r][c] = false end
end

local function expand(tc)
    if tc > max_steps then
        local old = max_steps
        max_steps = tc + 8
        for r = 1, #freqs do
            for c = old + 1, max_steps do grid[r][c] = false end
        end
    end
end

local function beep(f, d)
    local m = insts[c_inst]
    if m == "Light" then compu.beep(f * 2, d * 0.4)
    elseif m == "Dark" then compu.beep(f * 0.5, d * 1.2)
    elseif m == "Violin" then compu.beep(f, d) compu.beep(f * 1.01, d * 0.2)
    elseif m == "Piano" then compu.beep(f, d * 0.6)
    elseif m == "Guitar" then compu.beep(f, d * 0.1) compu.beep(f * 1.5, d * 0.3)
    else compu.beep(f, d * 0.8) end
end

local function prompt(m)
    gpu.setBackground(0x1F2E43) gpu.fill(15, 10, 50, 5, " ")
    gpu.setForeground(c_txt) gpu.set(17, 11, m) gpu.set(17, 13, "> ")
    local inp = ""
    while true do
        local e, _, ch, cd = event.pull()
        if e == "key_down" then
            if cd == 28 then break
            elseif cd == 14 and #inp > 0 then inp = inp:sub(1, #inp - 1) gpu.set(19 + #inp, 13, " ")
            elseif ch >= 32 and ch <= 126 and #inp < 20 then inp = inp .. string.char(ch) end
            gpu.set(19, 13, inp)
        end
    end
    return inp
end

local function draw()
    gpu.setBackground(c_bg) gpu.fill(1, 1, sw, sh, " ")
    gpu.setForeground(c_txt) gpu.set(4, 2, "Beep Studio v1.2  2026")
    gpu.set(4, 3, string.format("TRACK HEAD: #%02d | MODE: %s | TEMPO: 120BPM", step, insts[c_inst]))
    
    local sx = gx + (v_cols * (cw + 1)) + 3
    gpu.setBackground(c_panel) gpu.fill(sx, 2, sw - sx, sh - 6, " ")
    gpu.setForeground(c_head) gpu.set(sx + 2, 3, "=== STUDIO USER MANUAL ===")
    gpu.setForeground(c_txt)
    gpu.set(sx + 2, 5,  "- Click Grid to plot sounds")
    gpu.set(sx + 2, 6,  "- Use [<] & [>] to scroll steps")
    gpu.set(sx + 2, 8,  "- [SAVE] automatically creates")
    gpu.set(sx + 4, 9,  "a file on your desktop")
    gpu.set(sx + 2, 11, "- [OPEN] loads your .beeps files")
    gpu.set(sx + 2, 12, "  Type name without extension")
    gpu.set(sx + 2, 14, "- [INST MODE] shifts sound tones")
    
    for r = 1, #names do gpu.set(4, gy + (r - 1) * ch, names[r]) end
    for r = 1, #freqs do
        for c_idx = 1, v_cols do
            local ac = c_idx + scroll
            local x, y = gx + (c_idx - 1) * (cw + 1), gy + (r - 1) * ch
            if grid[r][ac] then gpu.setBackground(c_on) else gpu.setBackground(c_off) end
            if play and step == ac then gpu.setBackground(c_head) end
            gpu.fill(x, y, cw, ch, " ")
            if r == #freqs then
                gpu.setBackground(c_bg) gpu.setForeground(c_txt)
                gpu.set(x + 1, y + ch, string.format("#%02d", ac))
            end
        end
    end
    gpu.setBackground(c_btn) gpu.setForeground(c_txt)
    gpu.set(b_play.x1, b_play.y1, play and "[ STOP ]" or "[ PLAY ]")
    gpu.set(b_clr.x1, b_clr.y1, "[ CLEAR ]") gpu.set(b_inst.x1, b_inst.y1, "[ INST MODE ]")
    gpu.set(b_save.x1, b_save.y1, "[ SAVE ]") gpu.set(b_open.x1, b_open.y1, "[ OPEN ]")
    gpu.set(b_l.x1, b_l.y1, "[<]") gpu.set(b_r.x1, b_r.y1, "[>]") gpu.set(b_q.x1, b_q.y1, "[ QUIT ]")
end

local function click(cx, cy, btn)
    if btn ~= 0 then return end
    if cx >= b_play.x1 and cx <= b_play.x2 and cy >= b_play.y1 and cy <= b_play.y2 then
        play = not play if play then step, scroll = 1, 0 end tick = compu.uptime()
    elseif cx >= b_clr.x1 and cx <= b_clr.x2 and cy >= b_clr.y1 and cy <= b_clr.y2 then
        for r = 1, #freqs do for c = 1, max_steps do grid[r][c] = false end end
        play, step, scroll = false, 1, 0
    elseif cx >= b_inst.x1 and cx <= b_inst.x2 and cy >= b_inst.y1 and cy <= b_inst.y2 then
        c_inst = c_inst + 1 if c_inst > #insts then c_inst = 1 end
    elseif cx >= b_save.x1 and cx <= b_save.x2 and cy >= b_save.y1 and cy <= b_save.y2 then
        local fn = prompt("Enter file name to SAVE:")
        if #fn > 0 then
            local f = fs.open(s_dir .. fn .. ".beeps", "w")
            if f then
                f:write(tostring(max_steps) .. "\n")
                for r = 1, #freqs do
                    local s = ""
                    for c = 1, max_steps do s = s .. (grid[r][c] and "1" or "0") end
                    f:write(s .. "\n")
                end
                f:close()
            end
        end
    elseif cx >= b_open.x1 and cx <= b_open.x2 and cy >= b_open.y1 and cy <= b_open.y2 then
        local fn = prompt("Enter file name to LOAD:")
        if #fn > 0 then
            local f = fs.open(s_dir .. fn .. ".beeps", "r")
            if f then
                local s_st = ""
                while true do local ch = f:read(1) if not ch or ch == "\n" then break end s_st = s_st .. ch end
                max_steps = tonumber(s_st) or 16
                for r = 1, #freqs do
                    grid[r] = {} local ls = ""
                    while true do local ch = f:read(1) if not ch or ch == "\n" then break end ls = ls .. ch end
                    for c = 1, max_steps do grid[r][c] = (ls:sub(c,c) == "1") end
                end
                f:close() play, step, scroll = false, 1, 0
            end
        end
    elseif cx >= b_l.x1 and cx <= b_l.x2 and cy >= b_l.y1 and cy <= b_l.y2 then if scroll > 0 then scroll = scroll - 1 end
    elseif cx >= b_r.x1 and cx <= b_r.x2 and cy >= b_r.y1 and cy <= b_r.y2 then scroll = scroll + 1 expand(scroll + v_cols)
    elseif cx >= b_q.x1 and cx <= b_q.x2 and cy >= b_q.y1 and cy <= b_q.y2 then run = false
    else
        for r = 1, #freqs do
            for c_idx = 1, v_cols do
                local ac = c_idx + scroll
                local x, y = gx + (c_idx - 1) * (cw + 1), gy + (r - 1) * ch
                if cx >= x and cx < (x + cw) and cy == y then
                    expand(ac) grid[r][ac] = not grid[r][ac] beep(freqs[r], 0.05)
                end
            end
        end
    end
end

while run do
    draw()
    if play then
        local now = compu.uptime()
        if now - tick >= tempo then
            tick = now
            for r = 1, #freqs do if grid[r][step] then beep(freqs[r], tempo * 0.8) end end
            if step >= (scroll + v_cols) then scroll = step - v_cols + 1 expand(scroll + v_cols)
            elseif step <= scroll then scroll = step - 1 if scroll < 0 then scroll = 0 end end
            step = step + 1 expand(step)
        end
    end
    local ev, _, a1, a2, a3 = event.pull(0.02)
    if ev == "touch" then click(a1, a2, a3) end
    if ev == "key_down" and (a2 == 113 or a2 == 81) then run = false end
end

local xp = {311.13, 155.56, 466.16, 311.13, 369.99, 466.16}
for idx = 1, #xp do compu.beep(xp[idx], 0.12) end

gpu.fill(1, 1, sw, sh, " ")
print("Studio closed 🎧")
