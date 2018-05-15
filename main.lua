local socket = require("socket")

local lemss
local frames = {}
local frames_len = {}
local cur_frame = 0
local dtotal = 0
local lemmings = {}
local window_w, window_h
local cell = {w = 112, h = 50}
local walls = {}
local floors = {}
local players = {}
local yzh = {frame = 0, dt = 0, frames_len = 5.0, dir = 1}
local num_floors = 6
local colors = {"blue", "red", "orange", "green", "purple"}
local fullscreen = false
local canvas
local background

local verdana = love.graphics.newFont("res/verdanab.ttf", 72)
local consolas = love.graphics.newFont("res/consola.ttf", 45)
local spbctf = {}
local binary = {0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1}
local spbctf_frame = 0
local spbctf_dt = 0

local qr

local server

function load_sprite_column(img, num, w, h, x, y)
  local quads = {}
  for i = 1, num do 
    quads[#quads + 1] = love.graphics.newQuad(x, y + (i-1) * h, w, h, img:getDimensions())
  end
  return quads
end

function spawn_lemming(x, y, mode, floor, cell, color, dir, speed)
  local mode = mode or "walk"
  local floor = floor or num_floors + 1
  local cell = cell or 1
  local color = color or "blue"
  local speed = speed or 40
  local x = x or (dir > 0 and -speed or window_w + speed)
  local y = y or window_h - 20 - 11
  lemmings[#lemmings + 1] = {x = x, y = y, 
    frame = 0, framecount = 0, dt = 0,
    walk_dir = dir, walk_speed = speed,
    fly_speed = 30,
    w = 14, h = 20,
    floor = floor, cur_floor = num_floors + 1,
    cell = cell,
    color = color,
    mode = mode}
end

function enter_lemming(floor, cell, color, dir)
  local floor = floor or num_floors + 1
  local cell = cell or 1
  local color = color or "blue"
  local dir = dir or 1
  spawn_lemming(nil, nil, nil, floor, cell, color, dir, math.random(30,50))  
end

function enter_player(name, floor, cell, color)
  print(name, floor, cell) 
  local name = name or tostring(#players + 1)
  local cell = cell or 1
  local floor = floor or num_floors + 1
  if cell > floor then print(("Invalid cell: %s %s %s"):format(name, cell, floor)); return end
  if floor > num_floors + 1 then print(("Invalid floor: %s %s %s"):format(name, cell, floor)); return end
  
  local color = color or colors[math.random(1, #colors)]

  players[name] = players[name] or {lemmings = {}, color = color}
  
  if #players[name].lemmings == 1 and 
    lemmings[players[name].lemmings[1]].floor == num_floors + 1 then 
    lemmings[players[name].lemmings[1]].floor = floor
    lemmings[players[name].lemmings[1]].cell = cell
  else
    enter_lemming(floor, cell, players[name].color, math.random(0,1) * 2 - 1)
    players[name].lemmings[#players[name].lemmings + 1] = #lemmings
  end
  
end

function draw_floors()
  local y_offset = window_h/2 - (cell.h * num_floors + num_floors + 1) / 2
  for i = 1, num_floors do
    local floor_w = cell.w * i + i + 1
    local floor_h = y_offset + cell.h * (i - 1)
    love.graphics.line((window_w - floor_w)/2, floor_h, (window_w + floor_w)/2, floor_h)
    love.graphics.setColor(255, 255, 255, 50)
    --- love.graphics.rectangle("fill", (window_w - floor_w)/2, floor_h, floor_w, cell.h)
    love.graphics.setColor(255, 255, 255)
    for j = 1, i+1 do
      love.graphics.line(walls[i][j], floor_h, 
        walls[i][j], floor_h + cell.h)
    end
  end
  
  local floor_w = cell.w * num_floors + num_floors + 1
  local floor_h = y_offset + cell.h * num_floors
  love.graphics.line((window_w - floor_w)/2, floor_h, (window_w + floor_w)/2, floor_h)
  
  love.graphics.line(0, window_h - 20, window_w, window_h - 20)
end

function love.load() 
  canvas = love.graphics.newCanvas(800, 480)
  canvas:setFilter("nearest", "nearest")
  
  server = socket.udp()
  server:settimeout(0)
  server:setsockname('*', 12345)
  
  lemss = {}
  for _, v in pairs(colors) do
    lemss[v] = love.graphics.newImage("res/lem_" .. v .. ".png")
  end
  
  background = love.graphics.newImage("res/background.png")
  
  spbctf["0"] = nil
  spbctf["s"] = love.graphics.newImage("res/logo_smooth.png")
  spbctf["p"] = love.graphics.newImage("res/logo_pix.png")
  
  qr = love.graphics.newImage("res/qr.png")
  
  yzhss = love.graphics.newImage("res/yzh.png")
  floorss = love.graphics.newImage("res/floor1.png")
  floorquad = love.graphics.newQuad(0, 0, 40, 29, floorss:getDimensions())
  
  for color, ss in pairs(lemss) do
    frames[color] = {}
    frames[color]["walk"] = load_sprite_column(lemss[color], 8, 14, 20, 74, 4)
    frames[color]["fly"] = load_sprite_column(lemss[color], 6, 20, 32, 174, 120)
    frames[color]["fly_to_walk"] = load_sprite_column(lemss[color], 3, 20, 32, 174, 24)
    frames[color]["walk_to_fly"] = load_sprite_column(lemss[color], 3, 20, 32, 174, 24)
    frames_len["walk"] = 1.0
    frames_len["fly"] = 1.0
    frames_len["fly_to_walk"] = 0.5
    frames_len["walk_to_fly"] = 0.5
  end
  frames["yzh"] = load_sprite_column(yzhss, 5, 64, 64, 0, 0)
  love.window.setMode(800, 480)
  window_w, window_h = love.window.getMode()
  
  for i = 1, num_floors do
    local floor_walls = {}
    local floor_w = cell.w * i + i + 1
    floors[#floors + 1] =  window_h/2 - (cell.h * num_floors + num_floors + 1) / 2 + cell.h * i
    for j = 1, i+1 do
      floor_walls[#floor_walls + 1] = (window_w - floor_w)/2 + (j - 1) * cell.w + (j == 1 and 0 or j) 
    end
    walls[i] = floor_walls
  end

  walls[num_floors + 1] = {0, window_w}
    
  --spawn_lemming()
  --spawn_lemming(160)
  --spawn_lemming(160, nil, "fly")  
  --enter_player(1, 1, 1, "red")
  --enter_player(2, 5, 3, "green")
  --enter_player(3, 4, 2)
  --enter_player(1, 5, 2)
end

function love.draw()
	canvas:renderTo(love.draw2)
	local w, h = love.window.getMode()
  s = h/480
	love.graphics.draw(canvas, w/2, h/2, 0, s, s, 800/2, 480/2)
end

function love.draw2()
  
  love.graphics.setColor(10, 10, 10)
  love.graphics.rectangle("fill", 0, 0, window_w, window_h)
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(background, 0, 0)
  
  -- draw_floors()
  
  for i=0,window_w,40 do 
    love.graphics.draw(floorss, floorquad, i, window_h - 21)
  end
  
  for k, v in pairs(lemmings) do
    love.graphics.draw(lemss[v.color], frames[v.color][v.mode][v.frame + 1], v.x, v.y, nil, v.walk_dir, 1, v.w/2, v.h/2)
  end
  
  love.graphics.draw(yzhss, frames["yzh"][yzh.frame + 1], window_w / 2, floors[1] - 80, nil, 1, 1, 32, 32)
  
  if binary[spbctf_frame] == 0 then
    love.graphics.draw(spbctf["p"], 570, 30, 0, 200 / 1969.0)
  else
    love.graphics.draw(spbctf["s"], 570, 30, 0, 200 / 1969.0)
  end
  
  
  -- love.graphics.setFont(verdana)
  -- love.graphics.print({{255, 255, 255, 200}, "Starts at 13:37"}, 100, 145)
  
  love.graphics.setFont(consolas)
  -- love.graphics.print({{255, 255, 255, 200}, "blzhquest.ctf.su"}, 200, 233)
  
  -- love.graphics.print({{255, 255, 255, 200}, "t.me/blzhquest"}, 225, 283)
  
  love.graphics.print({{255, 255, 255}, "blzhquest"}, 30, 30)
  love.graphics.print({{255, 255, 255}, ".ctf.su"}, 30, 80)
  
  -- love.graphics.draw(qr, 10, 10, 0, 0.6)  
  
end

function love.update(dt)
  local recv_data, msg_or_ip, port_or_nil = server:receivefrom()
  if recv_data then
    local name, floor, cell = recv_data:match("^(%S*) (%S*) (%S*)")
    enter_player(name, tonumber(floor), tonumber(cell))
  end
  
  yzh.dt = yzh.dt + dt
  if yzh.dt >= yzh.frames_len then
    yzh.dt = yzh.dt - yzh.frames_len
    yzh.dir = yzh.dir * -1
  end
  
  spbctf_dt = spbctf_dt + dt
  if spbctf_dt >= 1.0 then
    spbctf_dt = spbctf_dt - 1.0
    spbctf_frame = spbctf_frame + 1
    if spbctf_frame == #binary then
        spbctf_frame = 0
    end
  end
  
  yzh.frame = math.floor(yzh.dt / (yzh.frames_len / #frames["yzh"]))
  if yzh.dir == -1 then
    yzh.frame = #frames["yzh"] - yzh.frame - 1
  end
  
  for k, v in pairs(lemmings) do
    v.dt = v.dt + dt
    if v.dt >= frames_len[v.mode] then
      v.dt = v.dt - frames_len[v.mode]
    end
    
    local oldframe = v.frame
    v.frame = math.floor(v.dt / (frames_len[v.mode] / #frames[v.color][v.mode]))
    if oldframe ~= v.frame then v.framecount = v.framecount + 1 end
    
    if v.mode == "walk" then
      v.x = v.x + v.walk_dir * v.walk_speed * dt
      
      for _, wx in pairs(walls[v.cur_floor]) do
        if v.x < wx + v.w/2 + 2 and v.x + v.w > wx + v.w/2 - 2 then
          if v.cur_floor == num_floors + 1 and v.walk_dir == 1 and wx == 0 then
            break
          end
          if v.cur_floor == num_floors + 1 and v.walk_dir == -1 and wx == window_w then
            break
          end
          v.x = wx - (v.walk_dir * (v.w/2 + 3))
          v.walk_dir = -v.walk_dir
          break
        end
      end
      
      if v.floor < num_floors + 1 and v.cur_floor ~= v.floor then
        --for _, wx in pairs(walls[v.floor]) do
        --  if _ > 1 then
        if math.abs((walls[v.floor][v.cell + 1] - cell.w/2 - 1) - v.x) < 1 then
          v.mode = "walk_to_fly"
          v.w = 20
          v.h = 32
          v.y = v.y - 4
          v.frame = 0
          v.framecount = 0
          v.dt = 0
        --     break
        --   end
        -- end
        end
      end
    elseif v.mode == "fly" then
      v.y = v.y - v.fly_speed * dt
      --for i = 1, 5 do
        if v.y + 14 <= floors[v.floor] then
          v.mode = "fly_to_walk"
          v.cur_floor = v.floor
          v.frame = 2
          v.framecount = 0
          v.dt = 0
          break
        end
      --end
    elseif v.mode == "fly_to_walk" then
      -- correction
      if oldframe ~= v.frame then v.framecount = v.framecount - 1 end

      v.frame = (#frames[v.color][v.mode] - 1) - v.frame
      if oldframe ~= v.frame then v.framecount = v.framecount + 1 end
      
      if v.framecount == #frames[v.color][v.mode] then
          v.mode = "walk"
          v.w = 14
          v.h = 20
          v.y = math.floor(v.y) + 4
          v.frame = 0
          v.framecount = 0
          v.dt = 0
      end
    elseif v.mode == "walk_to_fly" then
      if v.framecount == #frames[v.color][v.mode] then
          v.mode = "fly"
          v.w = 20
          v.h = 32
          v.frame = 0
          v.framecount = 0
          v.dt = 0
      end
    end
  end
end

function love.keyreleased(key, scancode, repeating)
  if key == "f" then
    fullscreen = not fullscreen
    love.window.setMode(fullscreen and 1920 or 800, fullscreen and 1080 or 480,
      {fullscreen = fullscreen, display = 2})
  end
end
