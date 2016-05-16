-- https://github.com/slemonide/gen

local function inform(msg)
	msg = "[eastside] "..msg
	print(msg)
	minetest.chat_send_all(msg)
end

local SIZE = minetest.setting_get("generator_size") or 1000

local CAVESIZE = 3000

-- Safe size (positive and absolute)
local ssize = math.ceil(math.abs(SIZE))

-- Heights
local h = {
	sea = 0,
	ice = ssize * 3/4
}

local function simplf(x)
	y = math.abs(math.ceil(x))
	return y
end

--local recursion_depth = math.ceil(math.abs(SIZE)/10)

local function do_ws_func(depth, a, x)
	local n = math.pi * x
	local y = 0
	for k=1,depth do
		y = y + math.sin(n * k^a)/(k^a)
	end
	if math.floor(math.abs(x))%2 == 1 then
		y = -y
	end
	return y/math.pi
end

local ws_values = {}
local function get_ws_value(depth, a, x)
	local v = ws_values[depth]
	if v then
		v = v[a]
		if v then
			v = v[x]
			if v then
				return v
			end
		else
			v = ws_values[depth]
			v[a] = {}
			setmetatable(v[a], {__mode = "kv"})
		end
	else
		ws_values[depth] = {[a] = {}}
	end
	v = do_ws_func(depth, a, x)
	ws_values[depth][a][x] = v
	return v
end

local function get_vs_list(from, to, depth, a, m)
	local list = {}
	for i = from, to do
		list[i] = get_ws_value(depth, a, i / m)
	end
	return list
end


local get_distance = math.hypot

local c_water = minetest.get_content_id("default:water_source")
local c_stone = minetest.get_content_id("default:stone")
local c_dirt = minetest.get_content_id("default:dirt")
local c_dirt_with_grass = minetest.get_content_id("default:dirt_with_grass")
local c_sand = minetest.get_content_id("default:sand")
local c_sandstone = minetest.get_content_id("default:sandstone")
local c_snow = minetest.get_content_id("default:snowblock")
local c_ice = minetest.get_content_id("default:ice")
-- Trees
local c_sapling = minetest.get_content_id("default:sapling")
local c_junglesapling = minetest.get_content_id("default:junglesapling")
local c_pinesapling = minetest.get_content_id("default:pine_sapling")
-- Flowers
local c_viola = minetest.get_content_id("flowers:viola")
local c_tulip = minetest.get_content_id("flowers:tulip")
local c_rose = minetest.get_content_id("flowers:rose")
local c_geranium = minetest.get_content_id("flowers:geranium")
local c_dandelion_yellow = minetest.get_content_id("flowers:dandelion_yellow")
local c_dandelion_white = minetest.get_content_id("flowers:dandelion_white")

local c_air = minetest.get_content_id("air")


-- this on_generated must become executed first!!
table.insert(minetest.registered_on_generateds, 1, function(minp, maxp, seed)
	-- abort if mg doesn't touch eastern side
	if maxp.x <= 0 then
		return
	end

	local t1 = os.clock()
	inform("generates...")

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

	local minp2 = vector.new(minp)
	minp2.x = math.max(minp2.x, 0)
	for p_pos in area:iterp(minp2, maxp) do
		data[p_pos] = c_air
	end

	local c1listx = get_vs_list(minp2.x, maxp.x, CAVESIZE, 2, CAVESIZE * 20)
	local c2listx = get_vs_list(minp2.x, maxp.x, CAVESIZE, 6, CAVESIZE * 20)
	local hlistx = get_vs_list(minp2.x, maxp.x, ssize, 3, SIZE * 20)

	local c1listy = get_vs_list(minp.y, maxp.y, CAVESIZE, 5, CAVESIZE * 10)
	local c2listy = get_vs_list(minp.y, maxp.y, CAVESIZE, 3, CAVESIZE * 10)

	local c1listz = get_vs_list(minp.z, maxp.z, CAVESIZE, 4, CAVESIZE * 10)
	local c2listz = get_vs_list(minp.z, maxp.z, CAVESIZE, 2.5, CAVESIZE * 10)
	local hlistz = get_vs_list(minp.z, maxp.z, ssize, 5, SIZE * 20)

	local rs = 1/SIZE

	for x=minp2.x,maxp.x do
		local cave1 = c1listx[x]
		local cave2 = c2listx[x]
		local land_base = hlistx[x]
		for z=minp.z,maxp.z do
			local cave1 = cave1 + c1listz[z]
			local cave2 = cave2 + c2listz[z]
			local land_base = math.floor(SIZE * (
				land_base
				+ hlistz[z]
				+ math.sin(get_distance(x*rs,z*rs)) * 0.1
			))
			local beach = math.floor(SIZE/97*math.cos((x - z)*10*rs)) -- Also used for ice
			local lower_ground, cave_in_ended
			for y=maxp.y,minp.y,-1 do
				local p_pos = area:index(x, y, z)
				if y < h.sea
				and y > land_base then
					data[p_pos] = c_water
				else
					local cave1 = (CAVESIZE*0.25 * (cave1 + c1listy[y]))%2-1
					local cave2 = (CAVESIZE*0.25 * (cave2 + c2listy[y]))%2-1
					cave = (cave1 < 0.5 and cave1 > -0.5) and (cave2 < 0.5 and cave2 > -0.5)
					if not cave then
						if y < land_base - 1 then
							data[p_pos] = c_stone
						elseif y == land_base then
							if y > beach + h.ice then
								data[p_pos] = c_snow
							elseif y >= beach + h.sea then
								if simplf(math.sin(y)) == land_base then
									data[p_pos] = c_water
								elseif y >= h.sea - 1 then
									data[p_pos] = c_dirt_with_grass
								else
									data[p_pos] = c_dirt
								end
							else
								data[p_pos] = c_sand
							end
						elseif y == land_base - 1 then
							if y > beach + h.ice then
								data[p_pos] = c_ice
							elseif y >= beach + h.sea then
								data[p_pos] = c_dirt
							else
								data[p_pos] = c_sandstone
							end
						elseif y == land_base + 1 then
							local grid = 2*(math.sin(x * math.pi/12) + math.sin(z * math.pi/12)) --math.floor(2*(math.sin(x * 0.2) + math.sin(z * 0.2))*100+0.5)*0.01
							if y < beach + h.ice
							and y > beach + h.sea then
								if grid == 4 then
									data[p_pos] = c_sapling
								elseif grid == 3 then
									data[p_pos] = c_junglesapling
								elseif grid == 2 then
									data[p_pos] = c_pinesapling
								elseif grid == 1 then
									data[p_pos] = c_viola
								elseif grid == 0 then
									data[p_pos] = c_tulip
								elseif grid == -1 then
									data[p_pos] = c_rose
								elseif grid == -2 then
									data[p_pos] = c_geranium
								elseif grid == -3 then
									data[p_pos] = c_dandelion_yellow
								elseif grid == -4 then
									data[p_pos] = c_dandelion_white
								end
							end
						end
						if lower_ground then
							cave_in_ended = true
						end
					elseif y == land_base then
						lower_ground = land_base
					elseif lower_ground
					and not cave_in_ended then
						lower_ground = lower_ground-1
					end
				end
			end
			if lower_ground
			and lower_ground ~= minp.y then
				-- a cave appeared on land_base
				local y = lower_ground
				local p_pos = area:index(x, y, z)
				-- a copy of above where the cave wasnt on land_base
				if y > beach + h.ice then
					data[p_pos] = c_snow
				elseif y >= beach + h.sea then
					if y >= h.sea - 1 then
						data[p_pos] = c_dirt_with_grass
					else
						data[p_pos] = c_dirt
					end
				else
					data[p_pos] = c_sand
				end
			end
		end
	end

	local t2 = os.clock()
	local calcdelay = string.format("%.2fs", t2 - t1)

	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	minetest.generate_ores(vm) -- adds the ores to the mapchunk
	vm:update_liquids()
	vm:write_to_map()

	local t3 = os.clock()
	inform("done after ca.: "..calcdelay.." + "..string.format("%.2fs", t3 - t2).." = "..string.format("%.2fs", t3 - t1))
end)
