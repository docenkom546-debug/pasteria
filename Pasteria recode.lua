local config = {
	databaseManagerVersion = 2,
	
	isdebug = false,

	script = "pasteria",
	build = "stable",
	version = "Recode",

	level = 2 -- 1 = stable, 2 = bliss, 3 = debug
}

config.user = config.isdebug and "admin" or ( panorama.open().MyPersonaAPI.GetName() or "user" )

local function copy_table(source_table)
	local new_table = {}

	for key, value in next, source_table do
		new_table[key] = value
	end

	return new_table
end

local table    = copy_table(table)
local math     = copy_table(math)
local string   = copy_table(string)
local ui       = copy_table(ui)
local client   = copy_table(client)
local database = copy_table(database)
local entity   = copy_table(entity)
local ffi      = copy_table(require("ffi"))
local globals  = copy_table(globals)
local panorama = copy_table(panorama)
local renderer = copy_table(renderer)
local bit      = copy_table(bit)

local function srequire(library_name, is_optional)
	local success, result_or_error = pcall(require, library_name)

	if success then
		return result_or_error
	end

	if is_optional then
		print(library_name, " library not found")
		config.isdebug = false
	else
		assert(success, "you are not subscribed to " .. library_name)
	end

	return false
end

local hui      = srequire("gamesense/pui")
local http     = srequire("gamesense/http")
local aafunc   = srequire("gamesense/antiaim_funcs")
local base64   = srequire("gamesense/base64")
local msgpack  = srequire("gamesense/msgpack")
local csweapon = srequire("gamesense/csgo_weapons")
local vector   = srequire("vector")

math.FLOAT_MAX               = 3.4028234663852886e+38
math.radindeg, math.deginrad = 180 / math.pi, math.pi / 180

math.randomseed( client.timestamp() )

function math.lerp(start, finish, amount)
	return start + (finish - start) * amount
end

function math.round(number)
	return math.floor(number + 0.5)
end

function math.sqrt3(x, y, z)
	return math.sqrt(x * x + y * y + (z and z * z or 0))
end

function math.sq3(x, y, z)
	return x * x + y * y + (z and z * z or 0)
end

function math.clamp(value, min, max)
	return value < min and min or max < value and max or value
end

function math.cycle(value, max_value)
	local remainder = value % max_value
	return remainder == 0 and max_value or remainder
end

function math.roundb(value, base)
	return math.floor(value + 0.5) / (base or 0)^1
end

function math.average(numbers_table)
	local sum = 0
	local count = #numbers_table
	if count == 0 then return 0 end

	for i = 1, count do
		sum = sum + numbers_table[i]
	end

	return sum / count
end

function math.angle_to(from_pos, to_pos)
	local delta_x = to_pos.x - from_pos.x
	local delta_y = to_pos.y - from_pos.y
	local delta_z = to_pos.z - from_pos.z

	local pitch = math.atan2(-delta_z, math.sqrt(delta_x * delta_x + delta_y * delta_y)) * math.radindeg
	local yaw = math.atan2(delta_y, delta_x) * math.radindeg
	return pitch, yaw
end

function math.angle_diff(angle1, angle2)
	return (angle1 - angle2 + 180) % 360 - 180
end

function math.tolerate(value, tolerance)
	if value < tolerance then
		return 0
	elseif value > 1 - tolerance then
		return 1
	end
	return value
end

function math.extrapolate(origin, velocity, ticks)
	return origin + velocity * globals.tickinterval * ticks
end

function math.relative_yaw(from_pos, to_pos)
	return math.atan2(from_pos.y - to_pos.y, from_pos.x - to_pos.x) * math.radindeg
end

function math.normalize_yaw(yaw)
	return (yaw + 180) % -360 + 180
end

function math.relative_pitch(from_pos, to_pos)
	local delta_x = to_pos.x - from_pos.x
	local delta_y = to_pos.y - from_pos.y
	local delta_z = to_pos.z - from_pos.z
	return math.atan2(-delta_z, math.sqrt(delta_x * delta_x + delta_y * delta_y)) * math.radindeg
end

function math.normalize_pitch(pitch)
	return math.clamp(pitch, -89, 89)
end

function math.closest_ray_point(point, ray_start, ray_end)
	local start_to_point = point - ray_start
	local start_to_end = ray_end - ray_start
	local ray_length = start_to_end:length()
	local ray_direction = start_to_end / ray_length
	local dot_product = ray_direction:dot(start_to_point)

	if dot_product < 0 then
		return ray_start
	elseif ray_length < dot_product then
		return ray_end
	end

	return ray_start + ray_direction * dot_product
end

table.new, table.clear = require("table.new"), require("table.clear")

function table.has(tbl, value)
	for i = 1, #tbl do
		if tbl[i] == value then
			return true
		end
	end
	return false
end

function table.find(tbl, value)
	for i = 1, #tbl do
		if tbl[i] == value then
			return i
		end
	end
end

function table.copy(original_table)
	if type(original_table) ~= "table" then
		return original_table
	end

	local copied_table = {}
	for key, value in pairs(original_table) do
		copied_table[table.copy(key)] = table.copy(value)
	end
	return copied_table
end

function table.place(target_table, path_keys, value)
	local current_level = target_table
	for i, key in ipairs(path_keys) do
		if type(current_level[key]) == "table" then
			current_level = current_level[key]
		else
			current_level[key] = i < #path_keys and {} or value
			current_level = current_level[key]
		end
	end
	return target_table
end

function table.filter(source_table)
	local result_table = {}
	local new_index = 1
	for i = 1, table.maxn(source_table) do
		if source_table[i] ~= nil then
			result_table[new_index] = source_table[i]
			new_index = new_index + 1
		end
	end
	return result_table
end

function table.distribute(source_table, value_key, new_key)
	local result_table = {}
	for i, item in ipairs(source_table) do
		local key = new_key and item[new_key] or i
		local value = value_key == nil and i or item[value_key]
		result_table[key] = value
	end
	return result_table
end

function string.clean(str)
	return string.gsub(string.gsub(str, "^%s+", ""), "%s+$", "")
end

function string.limit(str, max_len, suffix)
	local chars = {}
	local count = 1
	for char in string.gmatch(str, ".[\x80-\xBF]*") do
		count, chars[count] = count + 1, char
		if max_len < count then
			if suffix then
				chars[count] = suffix == true and "..." or suffix
			end
			break
		end
	end
	return table.concat(chars)
end

function string.alphen(str, alpha_multiplier)
	return string.gsub(str, "\a(%x%x%x%x%x%x)(%x%x)", function(color_hex, alpha_hex)
		local new_alpha = tonumber(alpha_hex, 16) * alpha_multiplier
		return string.format("%s%02x", color_hex, new_alpha)
	end)
end

function string.insert(original_str, str_to_insert, position)
	return string.sub(original_str, 1, position) .. str_to_insert .. string.sub(original_str, position + 1)
end

local logToConsole

local function debugLog(...)
	if config.isdebug then
		logToConsole(...)
	end
end

local function iif(condition, value_if_true, value_if_false)
	if condition then
		return value_if_true
	else
		return value_if_false
	end
end

local function sreference(arg, ...)
	local success, result_or_error = pcall(arg, ...)

	return success and result_or_error
end

-- local config = {}

local build_profiles = {
	[1] = { "stable", "pasteria • stable"},
	[2] = { "bliss",  "pasteria • bliss" },
	[3] = { "debug",  "pasteria • debug" }
}

local profile = build_profiles[config.level] or build_profiles[1]
if profile then
    config.build, config.script = profile[1], profile[2]
end

local FILESYSTEM_DLL = "filesystem_stdio.dll"
local FILESYSTEM_INTERFACE = "VFileSystem017"
local addSearchPath = vtable_bind(FILESYSTEM_DLL, FILESYSTEM_INTERFACE, 11, "void (__thiscall*)(void*, const char*, const char*, int)")
local removeSearchPath = vtable_bind(FILESYSTEM_DLL, FILESYSTEM_INTERFACE, 12, "bool (__thiscall*)(void*, const char*, const char*)")
local writeRaw = vtable_bind(FILESYSTEM_DLL, FILESYSTEM_INTERFACE, 1, "int (__thiscall*)(void*, void const*, int, void*)")
local openFile = vtable_bind(FILESYSTEM_DLL, FILESYSTEM_INTERFACE, 2, "void* (__thiscall*)(void*, const char*, const char*, const char*)")
local closeFile = vtable_bind(FILESYSTEM_DLL, FILESYSTEM_INTERFACE, 3, "void (__thiscall*)(void*, void*)")
local getGameDirectoryPath = vtable_bind("engine.dll", "VEngineClient014", 36, "const char*(__thiscall*)(void*)")

local filesystem = {}

filesystem.game_directory = string.sub( ffi.string(getGameDirectoryPath()), 1, -5 )

addSearchPath(filesystem.game_directory, "ROOT_PATH", 0)
defer(function()
	removeSearchPath(filesystem.game_directory, "ROOT_PATH")
end)

filesystem.create_directory = vtable_bind(FILESYSTEM_DLL, FILESYSTEM_INTERFACE, 22, "void (__thiscall*)(void*, const char*, const char*)")

filesystem.create_directory(config.script, "ROOT_PATH")

function filesystem.write(path, data)
	local fileHandle = openFile(path, "wb", "ROOT_PATH")

	writeRaw(data, #data, fileHandle)
	closeFile(fileHandle)
end

local eventManager, eventLogger, gui, trigger_anti_bruteforce, aa_state, active_aa_settings, final_angles, frame_flags, LocalPawn, entities_list, enemies_list, teammates_list, is_loading_config, delay_counter, target_delay_ticks

local suf = {
	set = client.set_event_callback,
	unset = client.unset_event_callback,
	fire = client.fire_event
}
local eventHandler

eventHandler = {
	set = function(self, callback)
		if type(callback) == "function" and self.proxy[callback] == nil then
			local newIndex = #self.callbacks + 1

			self.proxy[callback], self.callbacks[newIndex] = newIndex, callback
		end
	end,
	unset = function(self, callback)
		local callbackIndex = self.proxy[callback]

		if callbackIndex == nil then
			return
		end

		table.remove(self.callbacks, callbackIndex)

		self.proxy[callback] = nil

		for index, index in next, self.proxy do
			if callbackIndex < index then
				self.proxy[index] = index - 1
			end
		end
	end,
	__call = function(self, shouldSet, callback)
		if shouldSet then
			eventHandler.set(self, callback)
		else
			eventHandler.unset(self, callback)
		end
	end,
	fire = function(self, ...)
		return self.hook(...)
	end,
	gfire = function(self, ...)
		suf.fire(self[0], ...)
	end,
	unhook = function(self)
		suf.unset(self[0], self.hook)
	end
}
eventHandler.__index = eventHandler
eventManager = setmetatable({}, {
	__index = function(table, eventName)
		local handler = setmetatable({
			[0] = eventName,
			proxy = {},
			callbacks = {}
		}, eventHandler)

		function handler.hook(...)
			local lastResult

			for i = 1, #handler.callbacks do
				if handler.callbacks[i] then
					local result = handler.callbacks[i](...)

					if result ~= nil then
						lastResult = result
					end
				end
			end

			return lastResult
		end

		suf.set(handler[0], handler.hook)
		rawset(table, eventName, handler)

		return handler
	end
})

local ColorUtils

local CColorType = ffi.typeof("struct { uint8_t r; uint8_t g; uint8_t b; uint8_t a; }")

local function toHexString(color, excludeAlpha)
	return string.format(excludeAlpha and "%02X%02X%02X" or "%02X%02X%02X%02X", color.r, color.g, color.b, color.a)
end

local function fromHexString(hexStr)
	hexStr = string.gsub(hexStr, "^#", "")

	return tonumber(string.sub(hexStr, 1, 2), 16), tonumber(string.sub(hexStr, 3, 4), 16), tonumber(string.sub(hexStr, 5, 6), 16), tonumber(string.sub(hexStr, 7, 8), 16) or 255
end

local newCColor
local colorMetatable = {
	__eq = function(color, other)
		return color.r == other.r and color.g == other.g and color.b == other.b and color.a == other.a
	end,
	lerp = function(color, other, t)
		return newCColor(color.r + (other.r - color.r) * t, color.g + (other.g - color.g) * t, color.b + (other.b - color.b) * t, color.a + (other.a - color.a) * t)
	end,
	to_hex = toHexString,
	alphen = function(color, newAlpha, multiply)
		return newCColor(color.r, color.g, color.b, multiply and newAlpha * color.a or newAlpha)
	end,
	unpack = function(color)
		return color.r, color.g, color.b, color.a
	end
}

colorMetatable.__index = colorMetatable
newCColor = ffi.metatype(CColorType, colorMetatable)

local function fromRGBA(r, g, b, a)
	r = r and math.min(r, 255) or 255

	return newCColor(r, g and math.min(g, 255) or r, b and math.min(b, 255) or r, a and math.min(a, 255) or 255)
end

local function fromHex(hexStr)
	return newCColor(fromHexString(hexStr))
end

ColorUtils = setmetatable({
	rgb = fromRGBA,
	hex = fromHex,
	rgb_to_hex = toHexString,
	hex_to_rgb = fromHexString
}, {
	__call = function(self, p1, p2, p3, p4)
		return type(p1) == "string" and fromHex(p1) or fromRGBA(p1, p2, p3, p4)
	end
})

local CharArrayType_ClipBoard = ffi.typeof("char[?]")
local getClipboardTextSize = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local setClipboardText = vtable_bind("vgui2.dll", "VGUI_System010", 9, "void(__thiscall*)(void*, const char*, int)")
local getClipboardText = vtable_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")
local Clipboard = {
	get = function()
		local textSize = getClipboardTextSize()

		if textSize == 0 then
			return
		end

		local buffer = CharArrayType_ClipBoard(textSize)

		getClipboardText(0, buffer, textSize)

		return ffi.string(buffer, textSize - 1)
	end,
	set = function(text)
		text = tostring(text)

		setClipboardText(text, #text)
	end
}

local cprint

local con_print_f = vtable_bind("vstdlib.dll", "VEngineCvar007", 25, "void(__cdecl*)(void*, const void*, const char*, ...)")

local default_color = ColorUtils.rgb(217, 217, 217)

local color_map = {
	["\r"] = "\aD9D9D9",
	["\v"] = "\aA0F020"
}

local color_token_pattern = "[\r\v]"

local color_parser_pattern = "\a(%x%x%x%x%x%x)([^\a]*)"

eventManager.accent_recolor:set(function(self, new_accent_color)
	color_map["\v"] = new_accent_color
end)

function cprint(...)
	local args = { ... }

	for i = 1, #args do
		local formatted_string = "\aD9D9D9" .. string.gsub(tostring(args[i]), color_token_pattern, color_map)

		for color_hex, text_segment in string.gmatch(formatted_string, color_parser_pattern) do
			con_print_f(ColorUtils.hex(color_hex), "%s", text_segment)
		end
	end

	con_print_f(default_color, "%s", "\n")
end

function logToConsole(...)
	cprint("\vpasteria\r ", ...)
end

local databaseManager = {
	key = config.script .. "::db"
}
local storage = database.read(databaseManager.key)

if not storage then
	storage = {
		version = config.databaseManagerVersion,
		configs = {},
		stats = {
			loaded = 1,
			evaded = 0,
			killed = 0,
			missed = 0,
			shots = 0
		}
	}

	database.write(databaseManager.key, storage)
end

if storage.version ~= config.databaseManagerVersion then
	storage.stats.candies = nil
	storage.version = config.databaseManagerVersion
end

if not storage.stats.loaded then
	storage.stats.loaded = 1
end

if not storage.stats.evaded then
	storage.stats.evaded = 0
end

if not storage.stats.killed then
	storage.stats.killed = 0
end

if not storage.stats.missed then
	storage.stats.missed = 0
end

if not storage.stats.shots then
	storage.stats.shots = 0
end

storage.stats.loaded = storage.stats.loaded + 1

local function autoSave()
	eventManager.database_pre_save:fire()
	database.write(databaseManager.key, storage)
end

defer(function()
	database.write(databaseManager.key, storage)
	database.flush()
end)

databaseManager.stats = setmetatable({}, {
	__index = function(table, key)
		local value = storage.stats[key]

		if value then
			return value
		else
			storage.stats[key] = 0

			return 0
		end
	end,
	__newindex = function(table, key, value)
		storage.stats[key] = value

		eventManager.stats_update:fire()
	end
})


setmetatable(databaseManager, {
	__index = storage,
	__call = function(self, should_flush)
		database.write(databaseManager.key, storage)

		if should_flush == true then
			database.flush()
		end
	end
})

function ui.is_active(ui_element, expected_state)
	expected_state = expected_state == nil and true or expected_state

	return ui_element.value == expected_state and ui_element.hotkey:get()
end

client.open_link = panorama.open().SteamOverlayAPI.OpenExternalBrowserURL

function client.extrapolate(x, y, z, velocity_vector, time_scale)
	local time_delta = globals.tickinterval() * time_scale

	return x + velocity_vector.x * time_delta, y + velocity_vector.y * time_delta, z + velocity_vector.z * time_delta
end

local anim_state_type = ffi.typeof("struct { char pad0[0x18]; float anim_update_timer; char pad1[0xC]; float started_moving_time; float last_move_time; char pad2[0x10]; float last_lby_time; char pad3[0x8]; float run_amount; char pad4[0x10]; void* entity; void* active_weapon; void* last_active_weapon; float last_client_side_animation_update_time; int\t last_client_side_animation_update_framecount; float eye_timer; float eye_angles_y; float eye_angles_x; float goal_feet_yaw; float current_feet_yaw; float torso_yaw; float last_move_yaw; float lean_amount; char pad5[0x4]; float feet_cycle; float feet_yaw_rate; char pad6[0x4]; float duck_amount; float landing_duck_amount; char pad7[0x4]; float current_origin[3]; float last_origin[3]; float velocity_x; float velocity_y; char pad8[0x4]; float unknown_float1; char pad9[0x8]; float unknown_float2; float unknown_float3; float unknown; float m_velocity; float jump_fall_velocity; float clamped_velocity; float feet_speed_forwards_or_sideways; float feet_speed_unknown_forwards_or_sideways; float last_time_started_moving; float last_time_stopped_moving; bool on_ground; bool hit_in_ground_animation; char pad10[0x4]; float time_since_in_air; float last_origin_z; float head_from_ground_distance_standing; float stop_to_full_running_fraction; char pad11[0x4]; float magic_fraction; char pad12[0x3C]; float world_force; char pad13[0x1CA]; float min_yaw; float max_yaw; } **")
local anim_layer_type = ffi.typeof("struct { char pad_0x0000[0x18]; uint32_t sequence; float prev_cycle; float weight; float weight_delta_rate; float playback_rate; float cycle;void *entity;char pad_0x0038[0x4]; } **")
local get_client_entity_func = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

function entity.get_pointer(entity_index)
	return get_client_entity_func(entity_index)
end

function entity.get_animstate(entity_index)
	local entity_ptr = entity_index and get_client_entity_func(entity_index)

	if entity_ptr then
		return ffi.cast(anim_state_type, ffi.cast("char*", ffi.cast("void***", entity_ptr)) + 39264)[0]
	end
end

function entity.get_animlayer(entity_index, layer_index)
	local entity_ptr = get_client_entity_func(entity_index)

	if entity_ptr then
		return ffi.cast(anim_layer_type, ffi.cast("char*", ffi.cast("void***", entity_ptr)) + 10640)[0][layer_index or 0]
	end
end

function entity.get_simtime(entity_index)
	local entity_ptr = get_client_entity_func(entity_index)

	if entity_ptr then
		return entity.get_prop(entity_index, "m_flSimulationTime"), ffi.cast("float*", ffi.cast("uintptr_t", entity_ptr) + 620)[0]
	else
		return 0
	end
end

function entity.get_max_desync(anim_state)
	local speedFraction = math.clamp(anim_state.feet_speed_forwards_or_sideways, 0, 1)
	local baseDesync = (anim_state.stop_to_full_running_fraction * -0.3 - 0.2) * speedFraction + 1
	local duckAmount = anim_state.duck_amount

	if duckAmount > 0 then
		baseDesync = baseDesync + duckAmount * speedFraction * (0.5 - baseDesync)
	end

	return math.clamp(baseDesync, 0.5, 1)
end

local palette = {
	hex = "\a74A6A9FF",
	hexs = "\a74A6A9",
	accent = ColorUtils.hex("74A6A9"),
	back = ColorUtils.rgb(23, 26, 28),
	dark = ColorUtils.rgb(5, 6, 8),
	white = ColorUtils.rgb(255),
	black = ColorUtils.rgb(0),
	null = ColorUtils.rgb(0, 0, 0, 0),
	text = ColorUtils.rgb(230),
	panel = {
		l1 = ColorUtils.rgb(5, 6, 8, 96),
		g1 = ColorUtils.rgb(5, 6, 8, 140),
		l2 = ColorUtils.rgb(23, 26, 28, 96),
		g2 = ColorUtils.rgb(23, 26, 28, 140)
	}
}
local g_dpi_scale = 1
local scaled_screen_width, scaled_screen_height = client.screen_size()
local real_screen_width = scaled_screen_width
local real_screen_height = scaled_screen_height
local scaled_screen_center = {
	x = scaled_screen_width * 0.5,
	y = scaled_screen_height * 0.5
}
local real_screen_center = {
	x = real_screen_width * 0.5,
	y = real_screen_height * 0.5
}

local render_module = (function()
	local current_alpha_multiplier = 1
	local alpha_stack = {}
	local font_flag_suffix = ""
	local dpi_handler
	local dpi_scale_setting_ref = ui.reference("MISC", "Settings", "DPI scale")

	dpi_handler = {
		scalable = false,
		callback = function()
			local previous_dpi_scale = g_dpi_scale

			g_dpi_scale = dpi_handler.scalable and tonumber(string.sub(ui.get(dpi_scale_setting_ref), 1, -2)) * 0.01 or 1
			real_screen_width, real_screen_height = client.screen_size()
			scaled_screen_width, scaled_screen_height = real_screen_width / g_dpi_scale, real_screen_height / g_dpi_scale
			scaled_screen_center.x, scaled_screen_center.y = scaled_screen_width * 0.5, scaled_screen_height * 0.5
			font_flag_suffix = g_dpi_scale ~= 1 and "d" or ""

			if previous_dpi_scale ~= g_dpi_scale then
				eventManager.dpi_change:fire(g_dpi_scale, previous_dpi_scale)
			end
		end
	}

	dpi_handler.callback()
	ui.set_callback(dpi_scale_setting_ref, dpi_handler.callback)

	local function initial_resize_handler()
		if scaled_screen_width == 0 or scaled_screen_height == 0 then
			dpi_handler.callback()
		else
			eventManager.paint_ui:unset(initial_resize_handler)
		end
	end

	eventManager.paint_ui:set(initial_resize_handler)

	local floor = math.floor

	render = setmetatable({
		valid = false,
		cheap = true,
		dpi_t = dpi_handler,
		push_alpha = function(alpha)
			local stack_size = #alpha_stack

			if stack_size > 255 then
				error("alpha stack exceeded 255 objects, report to developers")
			end

			alpha_stack[stack_size + 1] = alpha
			-- current_alpha_multiplier = current_alpha_multiplier * alpha_stack[stack_size + 1] * (alpha_stack[stack_size] or 1)
			current_alpha_multiplier = current_alpha_multiplier * alpha
		end,
		pop_alpha = function()
			local old_stack_size = #alpha_stack
			local new_stack_size

			alpha_stack[old_stack_size], new_stack_size = nil, old_stack_size - 1
			current_alpha_multiplier = new_stack_size == 0 and 1 or alpha_stack[new_stack_size] * (alpha_stack[new_stack_size - 1] or 1)
		end,
		get_alpha = function()
			return current_alpha_multiplier
		end,
		blur = function(x, y, width, height, alpha)
			if not render.cheap and render.valid and (alpha or 1) * current_alpha_multiplier > 0.25 then
				blurs[#blurs + 1] = {
					floor(x * g_dpi_scale),
					floor(y * g_dpi_scale),
					floor(width * g_dpi_scale),
					floor(height * g_dpi_scale)
				}
			end
		end,
		gradient = function(x, y, width, height, start_color, end_color, is_vertical)
			renderer.gradient(floor(x * g_dpi_scale), floor(y * g_dpi_scale), floor(width * g_dpi_scale), floor(height * g_dpi_scale), start_color.r, start_color.g, start_color.b, start_color.a * current_alpha_multiplier, end_color.r, end_color.g, end_color.b, end_color.a * current_alpha_multiplier, is_vertical or false)
		end,
		gradient_outline = function(x, y, width, height, start_color, end_color, is_vertical, thickness)
			x, y, width, height, thickness = floor(x * g_dpi_scale), floor(y * g_dpi_scale), floor(width * g_dpi_scale), floor(height * g_dpi_scale), floor((thickness or 1) * g_dpi_scale)

			local start_r = start_color.r
			local start_g = start_color.g
			local start_b = start_color.b
			local start_a = start_color.a * current_alpha_multiplier
			local end_r = end_color.r
			local end_g = end_color.g
			local end_b = end_color.b
			local end_a = end_color.a * current_alpha_multiplier

			if is_vertical then
				renderer.gradient(x, y, width - thickness, thickness, start_r, start_g, start_b, start_a, end_r, end_g, end_b, end_a, is_vertical)
				renderer.rectangle(x, y + thickness, thickness, height - thickness, start_r, start_g, start_b, start_a)
				renderer.rectangle(x + width - thickness, y, thickness, height - thickness, end_r, end_g, end_b, end_a)
				renderer.gradient(x + thickness, y + height - thickness, width - thickness, thickness, start_r, start_g, start_b, start_a, end_r, end_g, end_b, end_a, is_vertical)
			else
				renderer.rectangle(x, y, width - thickness, thickness, start_r, start_g, start_b, start_a, is_vertical)
				renderer.gradient(x, y + thickness, thickness, height - thickness, start_r, start_g, start_b, start_a, end_r, end_g, end_b, end_a, is_vertical)
				renderer.gradient(x + width - thickness, y, thickness, height - thickness, start_r, start_g, start_b, start_a, end_r, end_g, end_b, end_a, is_vertical)
				renderer.rectangle(x + thickness, y + height - thickness, width - thickness, thickness, end_r, end_g, end_b, end_a, is_vertical)
			end
		end,
		line = function(x1, y1, x2, y2, color)
			renderer.line(floor(x1 * g_dpi_scale), floor(y1 * g_dpi_scale), floor(x2 * g_dpi_scale), floor(y2 * g_dpi_scale), color.r, color.g, color.b, color.a * current_alpha_multiplier)
		end,
		rectangle = function(x, y, width, height, color, rounding)
			x, y, width, height, rounding = floor(x * g_dpi_scale), floor(y * g_dpi_scale), floor(width * g_dpi_scale), floor(height * g_dpi_scale), rounding and floor(rounding * g_dpi_scale) or 0

			local r = color.r
			local g = color.g
			local b = color.b
			local a = color.a * current_alpha_multiplier

			if rounding == 0 then
				renderer.rectangle(x, y, width, height, r, g, b, a)
			else
				renderer.circle(x + rounding, y + rounding, r, g, b, a, rounding, 180, 0.25)
				renderer.rectangle(x + rounding, y, width - rounding - rounding, rounding, r, g, b, a)
				renderer.circle(x + width - rounding, y + rounding, r, g, b, a, rounding, 90, 0.25)
				renderer.rectangle(x, y + rounding, width, height - rounding - rounding, r, g, b, a)
				renderer.circle(x + rounding, y + height - rounding, r, g, b, a, rounding, 270, 0.25)
				renderer.rectangle(x + rounding, y + height - rounding, width - rounding - rounding, rounding, r, g, b, a)
				renderer.circle(x + width - rounding, y + height - rounding, r, g, b, a, rounding, 0, 0.25)
			end
		end,
		rect_outline = function(x, y, width, height, color, rounding, thickness)
			x, y, width, height, rounding, thickness = floor(x * g_dpi_scale), floor(y * g_dpi_scale), floor(width * g_dpi_scale), floor(height * g_dpi_scale), rounding and floor(rounding * g_dpi_scale) or 0, floor((thickness or 1) * g_dpi_scale)

			local r = color.r
			local g = color.g
			local b = color.b
			local a = color.a * current_alpha_multiplier

			if rounding == 0 then
				renderer.rectangle(x, y, width - thickness, thickness, r, g, b, a)
				renderer.rectangle(x, y + thickness, thickness, height - thickness, r, g, b, a)
				renderer.rectangle(x + width - thickness, y, thickness, height - thickness, r, g, b, a)
				renderer.rectangle(x + thickness, y + height - thickness, width - thickness, thickness, r, g, b, a)
			else
				renderer.circle_outline(x + rounding, y + rounding, r, g, b, a, rounding, 180, 0.25, thickness)
				renderer.rectangle(x + rounding, y, width - rounding - rounding, thickness, r, g, b, a)
				renderer.circle_outline(x + width - rounding, y + rounding, r, g, b, a, rounding, 270, 0.25, thickness)
				renderer.rectangle(x, y + rounding, thickness, height - rounding - rounding, r, g, b, a)
				renderer.circle_outline(x + rounding, y + height - rounding, r, g, b, a, rounding, 90, 0.25, thickness)
				renderer.rectangle(x + rounding, y + height - thickness, width - rounding - rounding, thickness, r, g, b, a)
				renderer.circle_outline(x + width - rounding, y + height - rounding, r, g, b, a, rounding, 0, 0.25, thickness)
				renderer.rectangle(x + width - thickness, y + rounding, thickness, height - rounding - rounding, r, g, b, a)
			end
		end,
		triangle = function(x1, y1, x2, y2, x3, y3, color)
			x1, y1, x2, y2, x3, y3 = x1 * g_dpi_scale, y1 * g_dpi_scale, x2 * g_dpi_scale, y2 * g_dpi_scale, x3 * g_dpi_scale, y3 * g_dpi_scale

			renderer.triangle(x1, y1, x2, y2, x3, y3, color.r, color.g, color.b, color.a * current_alpha_multiplier)
		end,
		circle = function(center_x, center_y, color, radius, start_angle, percent)
			renderer.circle(center_x * g_dpi_scale, center_y * g_dpi_scale, color.r, color.g, color.b, color.a * current_alpha_multiplier, radius * g_dpi_scale, start_angle or 0, percent or 1)
		end,
		circle_outline = function(center_x, center_y, color, radius, start_angle, percent, thickness)
			renderer.circle(center_x * g_dpi_scale, center_y * g_dpi_scale, color.r, color.g, color.b, color.a * current_alpha_multiplier, radius * g_dpi_scale, start_angle or 0, percent or 1, thickness * g_dpi_scale)
		end,
		screen_size = function(use_real_size)
			local width, height = client.screen_size()

			if use_real_size then
				return width, height
			else
				return width / g_dpi_scale, height / g_dpi_scale
			end
		end,
		load_rgba = function(path, width, height)
			return renderer.load_rgba(path, width, height)
		end,
		load_jpg = function(path, width, height)
			return renderer.load_jpg(path, width, height)
		end,
		load_png = function(path, width, height)
			return renderer.load_png(path, width, height)
		end,
		load_svg = function(path, width, height)
			return renderer.load_svg(path, width, height)
		end,
		texture = function(texture_id, x, y, width, height, tint_color, font_flags)
			if not texture_id then
				return
			end

			renderer.texture(texture_id, floor(x * g_dpi_scale), floor(y * g_dpi_scale), floor(width * g_dpi_scale), floor(height * g_dpi_scale), tint_color.r, tint_color.g, tint_color.b, tint_color.a * current_alpha_multiplier, font_flags or "f")
		end,
		text = function(x, y, color, font_name, flags, ...)
			renderer.text(x * g_dpi_scale, y * g_dpi_scale, color.r, color.g, color.b, color.a * current_alpha_multiplier, (font_name or "") .. font_flag_suffix, flags or 0, ...)
		end,
		measure_text = function(font_name, text_to_measure)
			local text_width, text_height = renderer.measure_text((font_name or "") .. font_flag_suffix, text_to_measure)

			return text_width / g_dpi_scale, text_height / g_dpi_scale
		end
	}, {
		__index = renderer
	})

	return render
end)()

local animation_module = (function()
	local animation_states = setmetatable({}, {
		__mode = "kv"
	})
	local frame_time = globals.absoluteframetime()
	local global_speed_multiplier = 1
	local easing_functions = {
		pow = {
			function(progress, power)
				return 1 - (1 - progress)^(power or 3)
			end,
			function(progress, power)
				return progress^(power or 3)
			end,
			function(progress, power)
				return progress < 0.5 and 4 * math.pow(progress, power or 3) or 1 - math.pow(-2 * progress + 2, power or 3) * 0.5
			end
		}
	}

	anima = {
		pulse = 0,
		easings = easing_functions,
		lerp = function(current_value, target_value, speed, threshold)
			local new_value = current_value + (target_value - current_value) * frame_time * (speed or 8) * global_speed_multiplier

			return math.abs(target_value - new_value) < (threshold or 0.005) and target_value or new_value
		end,
		condition = function(animation_id, is_active, speed_config, easing_config)
			local state = animation_id[1] and animation_id or animation_states[animation_id]

			if not state then
				animation_states[animation_id] = {
					is_active and 1 or 0,
					is_active
				}
				state = animation_states[animation_id]
			end

			speed_config = speed_config or 4

			local current_speed = speed_config

			if type(speed_config) == "table" then
				current_speed = is_active and speed_config[1] or speed_config[2]
			end

			state[1] = math.clamp(state[1] + frame_time * math.abs(current_speed) * global_speed_multiplier * (is_active and 1 or -1), 0, 1)

			return (state[1] % 1 == 0 or current_speed < 0) and state[1] or easing_functions.pow[easing_config and (is_active and easing_config[1][1] or easing_config[2][1]) or is_active and 1 or 3](state[1], easing_config and (is_active and easing_config[1][2] or easing_config[2][2]) or 3)
		end
	}

	eventManager.paint_ui:set(function()
		anima.pulse = math.sin(globals.realtime()) * 0.5 + 0.5
		frame_time = globals.frametime()
	end)

	return anima
end)()

local gfx_assets = {
	corner_h = render_module.load_svg("<svg width=\"4\" height=\"5.87\" viewBox=\"0 0 4 6\"><path fill=\"#fff\" d=\"M0 6V4c0-2 2-4 4-4v2C2 2 0 4 0 6Z\"/></svg>", 8, 12),
	corner_v = render_module.load_svg("<svg width=\"5.87\" height=\"4\" viewBox=\"0 0 6 4\"><path fill=\"#fff\" d=\"M2 0H0c0 2 2 4 4 4h2C4 4 2 2 2 0Z\"/></svg>", 12, 8),
	warning = render_module.load_svg("<svg width=\"16\" height=\"16\" viewBox=\"0 0 16 16\"><path fill=\"#fff\" d=\"m13.259 13h-10.518c-0.35787 0.0023-0.68906-0.1889-0.866-0.5-0.18093-0.3088-0.18093-0.6912 0-1l5.259-9.015c0.1769-0.31014 0.50696-0.50115 0.864-0.5 0.3568-0.00121 0.68659 0.18986 0.863 0.5l5.26 9.015c0.1809 0.3088 0.1809 0.6912 0 1-0.1764 0.3097-0.5056 0.5006-0.862 0.5zm-6.259-3v2h2v-2zm0-5v4h2v-4z\"/></svg>", 16, 16),
	manual = render_module.load_svg("<svg width=\"8\" height=\"10\" viewBox=\"0 0 8 10\"><path fill=\"#fff\" d=\"m0.384 5.802c-0.24286-0.19453-0.3842-0.48884-0.3842-0.8s0.14134-0.60547 0.3842-0.8l6.08-4c0.29513-0.22371 0.69277-0.25727 1.0212-0.086202 0.32846 0.17107 0.52889 0.51613 0.51477 0.8862l-1.92 3.96 1.92 4.04c0.01412 0.37007-0.18631 0.71513-0.51477 0.8862-0.32846 0.1711-0.7261 0.1375-1.0212-0.0862z\"/></svg>", 10, 10),
	mini_bfly = render_module.load_png("\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\t\x00\x00\x00\t\b\x06\x00\x00\x00\xE0\x91\x06\x10\x00\x00\x00\x04sBIT\b\b\b\b|\bd\x88\x00\x00\x00\xFDIDAT\x18Wc\xE4\xE7\xE7\xEF\xF8\xF8\xF1c9\x1F\x1F߮O\x9F>\xA5300<\x00b\x05..\xAE\xE5߾}\xB3\x00\xCAw2\x02\x05\xFE\xBF\x7F\xFF\x9Ea\xC1\x82\x05\f\xE5\xE5\xE5\xDF\x7F\xFD\xFA\x95\xC5\xC6\xC66\xB5\xB3\xB3\x93+!!\x81APP\x90\x01\xAC\b\b\x80\x14\x03Xabb\"\xC3\xFC\xF9\xF3\x19@\n@\x80\x91\x91\x91\x81\x91\x97\x97\xF7͡C\x87\x84\r\f\f\xE0\na\n\x0E\x1C8\xC0\x10\x1A\x1Az\x91\x11\xE4&IIɼ\xF6\xF6v΀\x80\x00\xB0B\x10ذa\x03CVV֏\xE7ϟg\x82\xACsPSS\xDBr\xF3\xE6Mn\x90\xE4\x83\a\x0F\x18\x14\x14\x14\xC0\nUTT>ݽ{\xD7\x1F\xA4H\x00\xE8\xB8\a\xFB\xF6\xED\xE3\aI\xF8\xFA\xFA\xFEټy3\v\x88mnn\x0E\xF2\b\x17H\x11\b$\xB0\xB3\xB3O\a1~\xFE\xFC\xB9\x12\xC8\x0E\a\xF9\x06\xA8\xC0\n(t\x01\xA6\b\xEE\x16l\f\x00$\xDFai]i\xDBy\x00\x00\x00\x00IEND\xAEB`\x82", 9, 9),
	logo_l = render_module.load_png("\x89PNG\x0D\x0A\x1A\x0A\x00\x00\x00\x0DIHDR\x00\x00\x00\x1A\x00\x00\x00\x0F\x08\x06\x00\x00\x00\xFAQ\xDF\xE6\x00\x00\x01YIDAT8\x11\xEDS\xB1J\xC4P\x10\x9C\xFEj\xFB\xEB\xED\xB5\xD7\xBF0\x9D)\xACS\x98:\x5C\x11H{\xA0\xD8H@\x88e\xBA\xEB\xD2\x0A)$i\x0E+\x8B\xB4v\xD1\x1Fx2\x8F7q\x8D\x82\x04\xB4s\xE1e\xB3\xBB\xB3\xBB\xF3&\x04\xF8\xB7e\x0A\xAC\x01\x1C\x86\xB3\xACs\x01z\x95$\xC9\xE0\x9CsEQ8\xDBw\x0C\xE0\xCC\x9C\x13S\x5C\x05V\xAC\x1F\x19\x96dK\xB3\xBD\xBC\xC5\x01\x80\x0D\x97\xD0\x00\xF8EQ\xDF\xF7!\xF5\xD9eY\xF6\x00`]\x96\xE5\xB3*\xC30\xB8q\x1C\xFD\x01pM\x8Cj\xF2m\xDB\xEAu\xF2d\xB3\x8D\xE3\xD8&\x9Cb\x12\xA8\xEB\xFA\x8DE\xBE\x93\x19e\xA0UU\xC5\xF8V$\xD9\x13\x98{\xCF\xBA\xC11\x07\xDF\xC4d\xD0r\x1A\xD64\x8D\xE3\x0Dh\x1A2\x8BoD\xCA\x83>\x08\xBD\xCEp-\x17E\x92#\x0C{\xA444\x0E\xB15\xB1$\x01b\xBB\xAE{\x11\x8E\xB1\xB0i\x9A>1/\x15\x98G\x9E\xE7\x8D\x9F:{\xE8\x06\x92J\x8D\x22\xC1x~\x1B\xE6\x82*{\x0E\x97yb|\x18\xC0$QXt\xA5\x85\x0B\xFD\xFD\x17\xBC\xB6\xD2\x9B\x0F\xBA\x03pJ]\x01\x5C\x98\xA6;\x00]\x88\x899\x07@/\x82\xACE\x00\xF8;lM\xFE\x92\x83\x04\x92\xE7\x7F\xF0\x9D\xB1Yf\xDF\x95\xFB\xD1k\x01=\x19\xFD\x99\xF1\xAA:\x92\xEB\xD7\x97\xBD\x03\x10\x7F\xD6\x9C\x19\x91x\xDF\x00\x00\x00\x0EeXIfMM\x00*\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\xD2S\x93\x00\x00\x00\x00IEND\xAEB`\x82", 26, 15),
	logo_r = render_module.load_png("\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x18\x00\x00\x00\x0F\b\x06\x00\x00\x00\xFE\xA4\x0F\xDB\x00\x00\x00\x04sBIT\b\b\b\b|\bd\x88\x00\x00\x02\bIDAT8O\xD5S=hZQ\x14>\xCF`\x97$(\x11\x87\xB8\xF8\b\xB5`\x92\x16%\x85\xBA\x89?%c\xA1\xA3ƀ\xE8P\x02]2\xE8T4\xA3B;\xB4\x0E\x19\xD4M\tAh\x93\xA9P\x95b\a\xC9 \x15\x92A\x9Ct\x90R\x84`\v\xA5Xh_\xBFss\x1F<)\xA4 dȅ\x8Fs\xEEy\xE7\x9C\xEF\xBB\x1F<\x85n\xF8(7\xBC\x9F\xE6!X\x9CN\xA7c\x93\xC9\xF4\xC7l6/\xFDO\xE0<\x04\xAF5M{>\x1C\x0EIU\xD5' 8\xBD\x8E\xC4H\xB0\x88F\x15\xF8\x01\f\fC\x9B\xC85y\xE7\xFA'\xC0+\xEF;\x88\x15\x99\xDB\x11y\x87qVX\xF4\xB4\xDDn\x1F\xF8|>^$N\xADV\xEB\x04\x02\x81{6\x9Bm٨n<\x1E\xFF\xB6\xDB\xED\v\\\x93/\b#\xFD:\x1A\x8D:\x0E\x87\xE3\x0E׻\xDD.y<\x1E\xAAV\xAB\x14\x8DF\x15\xA5\xDF\xEF\x7Fw\xB9\\\xCB\xF9|\x9E\x90S\xB1X\x14M^\xAF\x97&\x93\tY,\x16R\x94\xAB\x87&\x12\t\n\x06\x83\x14\x89D\x88\xFB\xD3\xE9\xF4\x16z:ܓL&\xA9T*\xD1`0 \xAB\xD5\xCAx\xCB\xE2\x15\xF8\xA9?_,ї\xF32&\x93J>K[\xBE`\xE1*\xF7aA\xABR\xA9\xD8@\xB6\xD1h4(\x1C\x0E\x1F\x97\xCB\xE5\x87\xF1x|Mޅ}\x82@_j\xB0\xE3U\xBD^\xDF\x0F\x85B\xBA\xB2\xFB\xF8v\xD1l6\xDFú\xEDV\xAB\xF5\xCB\xEF\xF7\x1F\xE5r\xB9\xDDT*\xA5\x8Bx\x06\xF2CË}\x989S\xA0B\xE3'\x1BO\xA1P\xB8\x8C\xC5b+R\xE99\xE2\x03\xCE3\x99L;\x9B\xCD\xF2\xA08l\x1D[\xE2t:ŝ\x95\xB3(>\xBD^\xEF\xA7\xDB\xED^gsg,\x92\xB3\x1F\x10\x1F\x03߀7\xC0\vY\x7F\x89\xB8o\x10\xD3A\xBE5\xA3n\xF6\xB2\xC3\x04\x8F\x80\xA8\xAC\xF3\xC2\x8F\xC0]`C\xD6NX\x9C\xCCU\xC4\x04`\x01΀w\xC0\x1E\xC0\x16\x0EY8\xB0\rL\x0017Ϗv\x8D\xE0\x7F?\xDD~\x82\xBF).\xBB\x8B\x1E\xD2\x13\xD3\x00\x00\x00\x00IEND\xAEB`\x82", 24, 15)
}

local butterfly_image_data = readfile("pasteria/butterfly.png")

local function setup_butterfly_textures(image_data)
	gfx_assets.butterfly = render_module.load_png(image_data, 1024, 1024)
	gfx_assets.butterfly_s = render_module.load_png(image_data, 64, 64)
end

if not butterfly_image_data then
	http.get("https://raw.githubusercontent.com/cr1nsova/pasteria/refs/heads/main/butterfly.png", function(success, response)
		if success and string.sub(response.body, 2, 4) == "PNG" then
			setup_butterfly_textures(response.body)
			writefile("pasteria/butterfly.png", response.body)
		end
	end)
else
	setup_butterfly_textures(butterfly_image_data)
end

if _AZAZI then
	http.get("https://raw.githubusercontent.com/cr1nsova/pasteria/refs/heads/main/logo_lo.png", function(success, response)
		if success and string.sub(response.body, 2, 4) == "PNG" then
			gfx_assets.logo_l = render_module.load_png(response.body, 35, 15)
		end
	end)
	http.get("https://raw.githubusercontent.com/cr1nsova/pasteria/refs/heads/main/logo_ro.png", function(success, response)
		if success and string.sub(response.body, 2, 4) == "PNG" then
			gfx_assets.logo_r = render_module.load_png(response.body, 35, 15)
		end
	end)
end

local drag_manager = (function()
	local active_drag_target_id
	local widget_configs = {}
	local feedback_colors = {
		bg = ColorUtils(255),
		line = ColorUtils(255)
	}
	local mouse_x = 0
	local mouse_y = 0
	local menu_x = 0
	local menu_y = 0
	local menu_width = 0
	local menu_height = 0

	eventManager.paint_ui:set(function()
		mouse_x, mouse_y = ui.mouse_position()
		mouse_x, mouse_y = mouse_x / g_dpi_scale, mouse_y / g_dpi_scale
		menu_x, menu_y = ui.menu_position()
		menu_width, menu_height = ui.menu_size()
		menu_x, menu_y, menu_width, menu_height = menu_x / g_dpi_scale, menu_y / g_dpi_scale, menu_width / g_dpi_scale, menu_height / g_dpi_scale
	end)

	local function is_point_in_rect(px, py, rx, ry, r_x2, r_y2)
		return rx <= px and ry <= py and px <= r_x2 and py <= r_y2
	end

	local animation_states = {
		menu = {
			0
		},
		bg = {
			0
		}
	}

	eventManager.paint_ui:set(function()
		local background_alpha = animation_module.condition(animation_states.bg, active_drag_target_id ~= nil, 2)

		if background_alpha == 0 then
			return
		end

		render_module.push_alpha(background_alpha)
		render_module.rectangle(0, 0, scaled_screen_width, scaled_screen_height, palette.panel.l1)
		render_module.pop_alpha()
	end)

	local function process_draggable_widget(widget)
		local drag_data = widget.__drag

		if drag_data.locked or not hui.menu_open then
			return
		end

		local is_mouse_down = client.key_state(1)
		local is_hovered_and_not_on_menu = is_point_in_rect(mouse_x, mouse_y, widget.x, widget.y, widget.x + widget.w, widget.y + widget.h) and not is_point_in_rect(mouse_x, mouse_y, menu_x, menu_y, menu_x + menu_width, menu_y + menu_height)

		if is_mouse_down and drag_data.ready == nil then
			drag_data.ready = is_hovered_and_not_on_menu
			drag_data.ix, drag_data.iy = widget.x, widget.y
			drag_data.px, drag_data.py = widget.x - mouse_x, widget.y - mouse_y
		end

		if is_mouse_down and drag_data.ready then
			if active_drag_target_id == nil and drag_data.on_held then
				drag_data.on_held(widget, drag_data)
			end

			active_drag_target_id = drag_data.ready and active_drag_target_id == nil and widget.id or active_drag_target_id
			drag_data.active = active_drag_target_id == widget.id
		elseif not is_mouse_down then
			if drag_data.active and drag_data.on_release then
				drag_data.on_release(widget, drag_data)
			end

			drag_data.active = false
			active_drag_target_id, drag_data.ready, drag_data.aligning, drag_data.px, drag_data.py, drag_data.ix, drag_data.iy = nil
		end

		drag_data.hovered = is_hovered_and_not_on_menu or drag_data.active

		local snap_positions = {}
		local real_x = widget.x * g_dpi_scale
		local real_y = widget.y * g_dpi_scale
		local real_w = widget.w * g_dpi_scale
		local real_h = widget.h * g_dpi_scale
		local drag_preview_x = drag_data.px and (drag_data.px + mouse_x) * g_dpi_scale or real_x
		local drag_preview_y = drag_data.py and (drag_data.py + mouse_y) * g_dpi_scale or real_y
		local real_center_x = real_x + real_w * 0.5
		local real_center_y = real_x + real_h * 0.5
		local hover_alpha = animation_module.condition(drag_data.progress[1], drag_data.hovered, 4)
		local active_alpha = animation_module.condition(drag_data.progress[2], drag_data.active, 4)

		render_module.rectangle(widget.x - 3, widget.y - 3, widget.w + 6, widget.h + 6, feedback_colors.bg:alphen(12 + 24 * hover_alpha), 6)
		render_module.push_alpha(active_alpha)

		if not client.key_state(162) then
			local widget_center_x = (drag_preview_x + real_w * 0.5) / g_dpi_scale
			local widget_center_y = (drag_preview_y + real_h * 0.5) / g_dpi_scale

			for i, ruler in ipairs(drag_data.rulers) do
				local ruler_x = ruler[2] / g_dpi_scale
				local ruler_y = ruler[3] / g_dpi_scale
				local is_close_to_ruler = math.abs(ruler[1] and widget_center_x - ruler_x or widget_center_y - ruler_y) < 10 * g_dpi_scale
				local snap_axis = ruler[1] and 1 or 2

				if not snap_positions[snap_axis] then
					snap_positions[snap_axis] = is_close_to_ruler and (ruler[1] and ruler_x - widget.w * 0.5 or ruler_y - widget.h * 0.5) or nil
				end

				ruler.p = ruler.p or {
					0
				}

				local distance_to_ruler = math.abs(ruler[1] and real_center_x - ruler_x or real_center_y - ruler_y)
				local ruler_alpha = animation_module.condition(ruler.p, is_close_to_ruler or distance_to_ruler < 10 * g_dpi_scale, -8) * 0.35 + 0.1

				render_module.rectangle(ruler_x, ruler_y, ruler[1] and 1 or ruler[4], ruler[1] and ruler[4] or 1, feedback_colors.line:alphen(ruler_alpha, true))
			end

			if drag_data.border[5] then
				local border_x1 = drag_data.border[1]
				local border_y1 = drag_data.border[2]
				local border_x2 = drag_data.border[3]
				local border_y2 = drag_data.border[4]
				local is_inside_border = is_point_in_rect(widget.x, widget.y, border_x1, border_y1, border_x2 - widget.w * 0.5 - 1, border_y2 - widget.h * 0.5 - 1)
				local border_alpha = animation_module.condition(drag_data.progress[3], not is_inside_border)

				render_module.rect_outline(border_x1, border_y1, border_x2 - border_x1, border_y2 - border_y1, feedback_colors.line:alphen(border_alpha * 0.75 + 0.25, true), 4)
			end
		end

		render_module.pop_alpha()

		if drag_data.active then
			local snapped_x = snap_positions[1] or drag_preview_x / g_dpi_scale
			local snapped_y = snap_positions[2] or drag_preview_y / g_dpi_scale
			local clamped_min_x = (drag_data.border[1] - real_w * 0.5) / g_dpi_scale
			local clamped_min_y = (drag_data.border[2] - real_h * 0.5) / g_dpi_scale
			local clamped_max_x = (drag_data.border[3] - real_w * 0.5) / g_dpi_scale
			local clamped_max_y = (drag_data.border[4] - real_h * 0.5) / g_dpi_scale
			local clamped_x = math.clamp(snapped_x, math.max(clamped_min_x, 0), math.min(clamped_max_x, scaled_screen_width - widget.w))
			local clamped_y = math.clamp(snapped_y, math.max(clamped_min_y, 0), math.min(clamped_max_y, scaled_screen_height - widget.h))

			widget:set_position(clamped_x, clamped_y)

			if drag_data.on_active then
				drag_data.on_active(widget, drag_data, fin)
			end
		end
	end

	drag = {
		data = widget_configs,
		new = function(widget, options)
			widget_configs[widget.id] = {
				x = hui.slider("MISC", "Settings", string.format("%s::%s-x", config.script, widget.id), 0, 10000, widget.x / scaled_screen_width * 10000),
				y = hui.slider("MISC", "Settings", string.format("%s::%s-y", config.script, widget.id), 0, 10000, widget.y / scaled_screen_height * 10000)
			}

			widget_configs[widget.id].x:set_visible(false)
			widget_configs[widget.id].y:set_visible(false)
			widget_configs[widget.id].x:set_callback(function(slider)
				widget.x = math.round(slider.value * 0.0001 * scaled_screen_width)
			end, true)
			widget_configs[widget.id].y:set_callback(function(slider)
				widget.y = math.round(slider.value * 0.0001 * scaled_screen_height)
			end, true)

			options = type(options) == "table" and options or {}
			widget.__drag = {
				locked = false,
				active = false,
				config = widget_configs[widget.id],
				progress = {
					{
						0
					},
					{
						0
					},
					{
						0
					}
				},
				ix = widget.x,
				iy = widget.y,
				rulers = options.rulers or {},
				border = options.border or {
					0,
					0,
					real_screen_width,
					real_screen_height
				},
				on_release = options.on_release,
				on_held = options.on_held,
				on_active = options.on_active,
				work = process_draggable_widget
			}

			eventManager.dpi_change:set(function()
				widget_configs[widget.id].x:set(widget_configs[widget.id].x.value)
				widget_configs[widget.id].y:set(widget_configs[widget.id].y.value)

				widget.x, widget.y = math.round(widget_configs[widget.id].x.value * 0.0001 * scaled_screen_width), math.round(widget_configs[widget.id].y.value * 0.0001 * scaled_screen_height)
			end)
			eventManager.setup_command:set(function(cmd)
				if hui.menu_open and (widget.__drag.hovered or widget.__drag.active) then
					cmd.in_attack = 0
				end
			end)
		end
	}

	return drag
end)()

local WidgetFactory = (function()
	local WidgetPrototype

	WidgetPrototype = {
		update = function(self)
			return 1
		end,
		paint = function(self, x, y, w, h)
			return
		end,
		set_position = function(self, new_x, new_y)
			if self.__drag then
				if new_x then
					self.__drag.config.x:set(new_x / scaled_screen_width * 10000)

					self.x = new_x
				end

				if new_y then
					self.__drag.config.y:set(new_y / scaled_screen_height * 10000)

					self.y = new_y
				end
			else
				self.x, self.y = new_x or self.x, new_y or self.y
			end
		end,
		get_position = function(self)
			local drag_config = self.__drag and self.__drag.config

			if not drag_config then
				return self.x, self.y
			end

			return drag_config.x.value * 0.0001 * scaled_screen_width, drag_config.y.value * 0.0001 * scaled_screen_height
		end,
		__call = function(self)
			local list_data = self.__list
			local drag_data = self.__drag

			if list_data then
				list_data.items, list_data.active = list_data.collect(), 0

				for i = 1, #list_data.items do
					if list_data.items[i].active then
						list_data.active = list_data.active + 1
					end
				end
			end

			self.alpha = self:update()

			render_module.push_alpha(self.alpha)

			if self.alpha > 0 then
				if drag_data then
					drag_data.work(self)
				end

				if list_data then
					WidgetPrototype.traverse(self)
				end

				self:paint(self.x, self.y, self.w, self.h)
			end

			render_module.pop_alpha()
		end,
		enlist = function(self, collect_func, paint_item_func)
			self.__list = {
				active = 0,
				longest = 0,
				items = {},
				progress = setmetatable({}, {
					__mode = "k"
				}),
				minwidth = self.w,
				collect = collect_func,
				paint = paint_item_func
			}
		end,
		traverse = function(self)
			local list_data = self.__list
			local current_y_offset = 0

			list_data.active, list_data.longest = 0, 0

			for i = 1, #list_data.items do
				local item = list_data.items[i]
				local item_id = item.name or i

				list_data.progress[item_id] = list_data.progress[item_id] or {
					0
				}

				local item_alpha = animation_module.condition(list_data.progress[item_id], item.active)

				if item_alpha > 0 then
					render_module.push_alpha(item_alpha)

					local item_width, item_height = list_data.paint(self, item, current_y_offset, item_alpha)

					render_module.pop_alpha()

					list_data.active, current_y_offset = list_data.active + 1, current_y_offset + item_height * item_alpha
					list_data.longest = math.max(list_data.longest, item_width)
				end
			end

			self.w = animation_module.lerp(self.w, math.max(list_data.longest, list_data.minwidth), 10, 0.5)
		end,
		lock = function(self, is_locked)
			if not self.__drag then
				return
			end

			self.__drag.locked = is_locked and true or false
		end
	}
	WidgetPrototype.__index = WidgetPrototype
	factory = {
		new = function(id, x, y, w, h, drag_options)
			local new_widget = {
				type = 0,
				alpha = 0,
				id = id,
				x = x or 0,
				y = y or 0,
				w = w or 0,
				h = h or 0,
				progress = {
					0
				}
			}

			if drag_options then
				drag_manager.new(new_widget, drag_options)
			end

			return setmetatable(new_widget, WidgetPrototype)
		end
	}

	return factory
end)()

local reference
local AntiAimConditions = {
	states = {
		{
			"default",
			"Default",
			"D"
		},
		{
			"stand",
			"Standing",
			"S"
		},
		{
			"run",
			"Running",
			"R"
		},
		{
			"walk",
			"Walking",
			"W"
		},
		{
			"air",
			"Air",
			"A"
		},
		{
			"airc",
			"Air & crouch",
			"AC"
		},
		{
			"crouch",
			"Crouching",
			"C"
		},
		{
			"sneak",
			"Sneaking",
			"3"
		},

		{
			"fakelag",
			"Fakelag",
			"FL"
		}
	},
	snaps = {
		{
			"default",
			"Default",
			"D"
		},
		{
			"stand",
			"Standing",
			"S"
		},
		{
			"run",
			"Running",
			"R"
		},
		{
			"walk",
			"Walking",
			"W"
		},
		{
			"air",
			"Air",
			"A"
		},
		{
			"airc",
			"Air & crouch",
			"AC"
		},
		{
			"crouch",
			"Crouching",
			"C"
		},
		{
			"sneak",
			"Sneaking",
			"3"
		},
		{
			"peek",
			"On peek",
			"P"
		}
	}
}

local ScriptData = {
	hitgroups = {
		[0] = "generic",
		"head",
		"chest",
		"stomach",
		"left arm",
		"right arm",
		"left leg",
		"right leg",
		"neck",
		"generic",
		"gear"
	},
	states = table.distribute(AntiAimConditions.states, nil, 1),
	snaps = table.distribute(AntiAimConditions.snaps, nil, 1),
	exploit = {
		OS = 2,
		DT = 1
	},
	aspect_ratios = {
		{
			125,
			"5:4"
		},
		{
			133,
			"4:3"
		},
		{
			150,
			"3:2"
		},
		{
			160,
			"16:10"
		},
		{
			178,
			"16:9"
		},
		{
			200,
			"2:1"
		}
	}
}

local Anti_Aim = {
	builder = {
		custom = {}
	},
	snap = {
		custom = {}
	}
}

local feature_modules = {}
local ab_state = {
	active = false,
	state = "default",
	yaw_shift_left = 0,
	yaw_shift_right = 0,
	desync_shift_left = 0,
	desync_shift_right = 0,
	timer_end = nil
}

local ab_history = {}
local generate_quadrant_offsets
local predict_real_yaw

local function get_quadrant(yaw, desync)
	if yaw >= 0 then
		return desync >= 0 and "q1" or "q2"
	else
		return desync >= 0 and "q3" or "q4"
	end
end

local function init_player_history(name)
	if not ab_history[name] then
		ab_history[name] = {
			peek_toggle = false,
			recent_quads = {}
		}
		for i = 1, #AntiAimConditions.states do
			local state_key = AntiAimConditions.states[i][1]
			ab_history[name][state_key] = { q1 = 0, q2 = 0, q3 = 0, q4 = 0 }
		end
	end
end

local function get_wall_direction()
	local local_player = entity.get_local_player()
	if not local_player or not entity.is_alive(local_player) then
		return 0
	end

	local eye_x, eye_y, eye_z = client.eye_position()
	local cam_pitch, cam_yaw = client.camera_angles()
	if not eye_x or not cam_yaw then return 0 end

	local yaw_rad = math.rad(cam_yaw)
	local left_yaw = yaw_rad + math.pi / 2
	local right_yaw = yaw_rad - math.pi / 2

	local left_x = eye_x + math.cos(left_yaw) * 45
	local left_y = eye_y + math.sin(left_yaw) * 45
	local right_x = eye_x + math.cos(right_yaw) * 45
	local right_y = eye_y + math.sin(right_yaw) * 45

	local left_fraction = client.trace_line(local_player, eye_x, eye_y, eye_z, left_x, left_y, eye_z)
	local right_fraction = client.trace_line(local_player, eye_x, eye_y, eye_z, right_x, right_y, eye_z)

	if left_fraction < right_fraction then
		return -1 -- Wall is closer to the left (prefer yaw <= 0 -> q3, q4)
	elseif right_fraction < left_fraction then
		return 1  -- Wall is closer to the right (prefer yaw >= 0 -> q1, q2)
	end
	return 0
end

local function update_quadrant_scores(name, current_state, q_left, q_right, delta)
	init_player_history(name)
	local profile = ab_history[name][current_state] or ab_history[name].default
	if profile then
		profile[q_left] = math.clamp(profile[q_left] + delta, -10, 10)
		if q_right ~= q_left then
			profile[q_right] = math.clamp(profile[q_right] + delta, -10, 10)
		end
	end
end

predict_real_yaw = function(quad, max_weight, current_state)
	local yaw_offset, desync_offset = generate_quadrant_offsets(quad, max_weight, current_state)

	local desync_settings = active_aa_settings.cur.des
	local left_limit = desync_settings.l or 60
	local right_limit = desync_settings.r or 60
	local desync_side = 1

	if frame_flags.fs_desync_side then
		desync_side = frame_flags.fs_desync_side == 1 and 1 or -1
	elseif desync_settings.j then
		desync_side = aa_state.switch and 1 or -1
	else
		desync_side = gui.antiaim.general.invert:get() and 1 or -1
	end

	local des_val = math.abs(desync_offset) * 58 * desync_side

	local desync_multiplier = LocalPawn.on_ground and 2 or 1
	if frame_flags.speeding then
		desync_multiplier = 1
	end

	local base_yaw = final_angles.yaw or 0
	local base_mod = final_angles.mod or 0
	local final_yaw = math.normalize_yaw((final_angles.snap and final_angles.snap[2]) or base_yaw + base_mod)

	local temp_yaw = final_yaw + yaw_offset
	local predicted = temp_yaw - des_val * desync_multiplier
	return math.normalize_yaw(predicted)
end

local function choose_best_quadrant(attacker, current_state, reason, max_weight)
	local name
	if attacker and attacker ~= 0 then
		name = entity.get_player_name(attacker) or tostring(attacker)
	end

	if not current_state then
		current_state = (aa_state and aa_state.state and AntiAimConditions.states[aa_state.state]) and AntiAimConditions.states[aa_state.state][1] or "default"
	end

	if name then
		init_player_history(name)
	else
		name = "_global_shared"
	end
	init_player_history("_global_shared")

	local player_history = ab_history[name]
	local profile = player_history[current_state] or player_history.default
	if profile.q1 == 0 and profile.q2 == 0 and profile.q3 == 0 and profile.q4 == 0 then
		profile = ab_history["_global_shared"][current_state] or ab_history["_global_shared"].default
	end

	-- Wall-Aware AB adjustments
	local wall_side = get_wall_direction()
	local wall_bonus = 2.0 -- virtual score bonus for hiding head behind wall

	-- On peek alternating delta mode (low vs high)
	local low_delta_bonus = 0
	local high_delta_bonus = 0
	if reason == "On peek" then
		if player_history then
			player_history.peek_toggle = not player_history.peek_toggle
			if player_history.peek_toggle then
				low_delta_bonus = 3.0  -- Prioritize q2 & q4 (low delta desync)
			else
				high_delta_bonus = 3.0 -- Prioritize q1 & q3 (high delta desync)
			end
		end
	end

	local q1_score = profile.q1 + (wall_side == 1 and wall_bonus or 0) + high_delta_bonus
	local q2_score = profile.q2 + (wall_side == 1 and wall_bonus or 0) + low_delta_bonus
	local q3_score = profile.q3 + (wall_side == -1 and wall_bonus or 0) + high_delta_bonus
	local q4_score = profile.q4 + (wall_side == -1 and wall_bonus or 0) + low_delta_bonus

	-- Dynamic trigger rotation (Anti-resolver cycle)
	if gui.antiaim.ab.cycle:get() and player_history and player_history.recent_quads then
		local num_recent = #player_history.recent_quads
		for i = 1, num_recent do
			local q = player_history.recent_quads[i]
			local penalty = (i == num_recent) and -15 or -8
			if q == "q1" then q1_score = q1_score + penalty
			elseif q == "q2" then q2_score = q2_score + penalty
			elseif q == "q3" then q3_score = q3_score + penalty
			elseif q == "q4" then q4_score = q4_score + penalty
			end
		end
	end

	if gui.antiaim.ab.avoid_same:get() and ab_state.last_head_pos and ab_state.last_real_yaw then
		local px = LocalPawn.origin.x or 0
		local py = LocalPawn.origin.y or 0
		local vx = ab_state.last_head_pos.x - px
		local vy = ab_state.last_head_pos.y - py
		
		local dist_logs = {}
		local function get_quad_score_mod(q)
			local pred_yaw = predict_real_yaw(q, max_weight, current_state)
			local rad = math.rad(math.normalize_yaw(pred_yaw - ab_state.last_real_yaw))
			
			local pred_hx = px + vx * math.cos(rad) - vy * math.sin(rad)
			local pred_hy = py + vx * math.sin(rad) + vy * math.cos(rad)
			
			local dx = pred_hx - ab_state.last_head_pos.x
			local dy = pred_hy - ab_state.last_head_pos.y
			local dist = math.sqrt(dx*dx + dy*dy)
			
			table.insert(dist_logs, string.format("%s(%.1fu)", q, dist))

			-- Overlap penalty (CS:GO head hitbox diameter ~11.0 units)
			local penalty = 0
			if dist < 11.0 then
				penalty = -15 * (1 - dist / 11.0)
			end
			
			-- Distance bonus (proportional to displacement to prioritize furthest position)
			local bonus = dist * 1.0
			
			return penalty + bonus
		end
		q1_score = q1_score + get_quad_score_mod("q1")
		q2_score = q2_score + get_quad_score_mod("q2")
		q3_score = q3_score + get_quad_score_mod("q3")
		q4_score = q4_score + get_quad_score_mod("q4")

		client.log(string.format("[ab] Avoid same position active! Head distances: %s", table.concat(dist_logs, ", ")))
	end

	local max_val = math.max(q1_score, q2_score, q3_score, q4_score)
	local best = {}

	if q1_score == max_val then table.insert(best, "q1") end
	if q2_score == max_val then table.insert(best, "q2") end
	if q3_score == max_val then table.insert(best, "q3") end
	if q4_score == max_val then table.insert(best, "q4") end

	local selected = best[client.random_int(1, #best)]
	if player_history and player_history.recent_quads then
		table.insert(player_history.recent_quads, selected)
		if #player_history.recent_quads > 2 then
			table.remove(player_history.recent_quads, 1)
		end
	end
	return selected
end

LocalPawn, entities_list, enemies_list, teammates_list = {
	vulnerable = false,
	side = 0,
	duck_amount = 0,
	max_speed = 0,
	peeking = false,
	valid = false,
	velocity = 0,
	self = entity.get_local_player(),
	origin = vector(),
	threat = client.current_threat(),
	exploit = {
		lc_left = 0,
		defensive = false,
		defensive_active = false,
		ready = false
	},
	predicted = {
		velocity = 0
	}
}, {}, {}, {}


local g_last_postpone_fire_time = 0
local g_max_tickbase_seen = 0
local g_last_command_number
local last_sim_time, defensive_until = 0, 0

eventManager.predict_command:set(function(cmd)
	if not LocalPawn.valid or g_last_command_number ~= cmd.command_number then
		return
	end

	g_last_postpone_fire_time = entity.get_prop(LocalPawn.weapon, "m_flPostponeFireReadyTime")

	local current_tickbase = entity.get_prop(LocalPawn.self, "m_nTickBase") or 0

	if math.abs(current_tickbase - g_max_tickbase_seen) > 64 then
		g_max_tickbase_seen = 0
	end

	if current_tickbase > g_max_tickbase_seen then
		g_max_tickbase_seen = current_tickbase
	elseif current_tickbase < g_max_tickbase_seen then
		-- block empty
	end

	LocalPawn.exploit.lc_left = math.min(14, math.max(0, g_max_tickbase_seen - current_tickbase - 1))
	LocalPawn.exploit.defensive = LocalPawn.exploit.lc_left > 0

	local sim_time_prop = entity.get_prop(LocalPawn.self, "m_flSimulationTime")
	if sim_time_prop then
		local sim_time = math.floor(sim_time_prop / globals.tickinterval() + 0.5)
		local sim_diff = sim_time - last_sim_time
		local tickcount = globals.tickcount()
		if sim_diff < 0 then
			defensive_until = tickcount + math.abs(sim_diff) - math.floor(client.latency() / globals.tickinterval() + 0.5)
		end
		last_sim_time = sim_time
		LocalPawn.exploit.defensive_active = defensive_until > tickcount
	else
		LocalPawn.exploit.defensive_active = false
	end
end)
eventManager.run_command:set(function(cmd)
	g_last_command_number = cmd.command_number

	if not gui or not gui.misc then
		return
	end

	if ab_state.active and ab_state.timer_end and globals.realtime() > ab_state.timer_end then
		ab_state.active = false
		ab_state.yaw_shift_left = 0
		ab_state.yaw_shift_right = 0
		ab_state.desync_shift_left = 0
		ab_state.desync_shift_right = 0
		ab_state.timer_end = nil
		
		eventLogger.push("ab", "[ab] Reset", "\aB3B3B3\x01•\aE6E6E6\x02 ab \aE6E6E6\x01->\aE6E6E6\x02 Reset")
	end
end)

local function is_grenade_being_thrown()
	if not LocalPawn.weapon then
		return false
	end

	if not entity.get_prop(LocalPawn.weapon, "m_bPinPulled") then
		return
	end

	local throw_time = entity.get_prop(LocalPawn.weapon, "m_fThrowTime")

	return throw_time and throw_time ~= 0
end

local function can_player_shoot()
	if not LocalPawn.valid or not LocalPawn.weapon or not LocalPawn.weapon_t then
		return
	end

	if LocalPawn.weapon_t.weapon_type_int == 9 or LocalPawn.weapon_t.name == "Medi-Shot" or LocalPawn.weapon_t.type == "c4" then
		return
	end

	if entity.get_prop(LocalPawn.weapon, "m_iClip1") == 0 then
		return
	end

	local current_server_time = entity.get_prop(LocalPawn.self, "m_nTickBase") * globals.tickinterval()
	local player_next_attack_time = entity.get_prop(LocalPawn.self, "m_flNextAttack")
	local weapon_next_attack_time = entity.get_prop(LocalPawn.weapon, "m_flNextPrimaryAttack")

	if not player_next_attack_time or not weapon_next_attack_time then
		return
	end

	if entity.get_prop(LocalPawn.weapon, "m_iItemDefinitionIndex") == 64 and not (g_last_postpone_fire_time < globals.curtime()) then
		return
	end

	return player_next_attack_time <= current_server_time and weapon_next_attack_time <= current_server_time
end

local function can_damage_enemy()
	local is_enemy_damageable = false
	local is_enemy_obstructed = false
	local vx, vy, vz = entity.get_prop(LocalPawn.self, "m_vecVelocity")
	local ticks_to_extrapolate = reference.misc.settings.maxshift.value - reference.rage.aimbot.dt_fl[1].value + 1
	local eye_x, eye_y, eye_z = client.eye_position()
	local ex, ey, ez = client.extrapolate(eye_x, eye_y, eye_z, {x=vx or 0, y=vy or 0, z=vz or 0}, ticks_to_extrapolate)

	-- Check if our extrapolation went through a wall
	local fraction, entindex = client.trace_line(LocalPawn.self, eye_x, eye_y, eye_z, ex, ey, ez)
	if fraction < 1.0 then
		ex, ey, ez = eye_x, eye_y, eye_z
	end

	for player_index = 1, #enemies_list do
		local current_player = enemies_list[player_index]

		if bit.band(entity.get_esp_data(current_player).flags or 0, bit.lshift(1, 11)) == 0 then
			local hx, hy, hz = entity.hitbox_position(current_player, 0)
			if hx then
				local evx, evy, evz = entity.get_prop(current_player, "m_vecVelocity")
				local ehx, ehy, ehz = client.extrapolate(hx, hy, hz, {x=evx or 0, y=evy or 0, z=evz or 0}, 4)

				-- Check if enemy head extrapolation went through a wall
				local enemy_fraction = client.trace_line(current_player, hx, hy, hz, ehx, ehy, ehz)
				if enemy_fraction < 1.0 then
					ehx, ehy, ehz = hx, hy, hz
				end
				
				-- 1. Trace from extrapolated eye position (for early prediction)
				local _, dmg_extrapolated = client.trace_bullet(LocalPawn.self, ex, ey, ez, ehx, ehy, ehz)
				
				-- 2. Trace from current eye position (for stability while in the open)
				local _, dmg_current = client.trace_bullet(LocalPawn.self, eye_x, eye_y, eye_z, hx, hy, hz)

				if (dmg_extrapolated or 0) > 0 or (dmg_current or 0) > 0 then
					is_enemy_damageable = true
					break
				end
			end
		else
			is_enemy_obstructed = true
		end
	end

	return is_enemy_damageable, is_enemy_obstructed
end

local function get_max_speed()
	if not LocalPawn.weapon_t then
		return 0
	end

	if entity.get_prop(LocalPawn.self, "m_bIsScoped") == 1 then
		return LocalPawn.weapon_t.max_player_speed_alt
	else
		return LocalPawn.weapon_t.max_player_speed
	end
end

local function get_closest_enemy()
	local local_player = entity.get_local_player()
	if not local_player or not entity.is_alive(local_player) then
		return nil
	end

	local local_origin = vector(entity.get_origin(local_player))
	local players = entity.get_players(true)
	if not players then return nil end
	local closest_enemy = nil
	local closest_dist = math.huge

	for i = 1, #players do
		local player = players[i]
		if entity.is_alive(player) and not entity.is_dormant(player) then
			local origin = vector(entity.get_origin(player))
			local dist = math.sqrt3((local_origin - origin):unpack())
			if dist < closest_dist then
				closest_dist = dist
				closest_enemy = player
			end
		end
	end

	return closest_enemy
end

local function update_local_player_state(cmd)
	LocalPawn.self = entity.get_local_player()
	LocalPawn.valid = LocalPawn.self and entity.is_alive(LocalPawn.self) and true or false
	local cur_threat = client.current_threat()
	LocalPawn.threat = LocalPawn.valid and (cur_threat ~= nil and cur_threat ~= 0 and cur_threat or get_closest_enemy()) or nil
	LocalPawn.weapon = LocalPawn.valid and entity.get_player_weapon(LocalPawn.self) or nil
	LocalPawn.weapon_t = LocalPawn.weapon and csweapon(LocalPawn.weapon)

	if LocalPawn.valid then
		LocalPawn.exploit.active = reference.rage.aimbot.double_tap[1].value and reference.rage.aimbot.double_tap[1].hotkey:get() and ScriptData.exploit.DT or reference.aa.other.onshot.value and reference.aa.other.onshot.hotkey:get() and ScriptData.exploit.OS or ScriptData.exploit.OFF

		if reference.rage.other.duck:get() then
			LocalPawn.exploit.active = nil
		end

		LocalPawn.exploit.ready = aafunc.get_double_tap()
		LocalPawn.origin = vector(entity.get_origin(LocalPawn.self))
		LocalPawn.animstate = entity.get_animstate(LocalPawn.self)
		LocalPawn.duck_amount = entity.get_prop(LocalPawn.self, "m_flDuckAmount") or 0

		local vel_x, vel_y, vel_z = entity.get_prop(LocalPawn.self, "m_vecVelocity")
		LocalPawn.velocity = math.sqrt3(vel_x or 0, vel_y or 0, vel_z or 0)

		if cmd then
			local player_flags = entity.get_prop(LocalPawn.self, "m_fFlags") or 0

			LocalPawn.throwing_nade = is_grenade_being_thrown() or false
			LocalPawn.can_shoot = can_player_shoot() or false
			LocalPawn.using = cmd.in_use == 1
			LocalPawn.in_score = cmd.in_score == 1
			LocalPawn.on_ground = bit.band(player_flags, bit.lshift(1, 0)) == 1
			LocalPawn.jumping = not LocalPawn.on_ground or cmd.in_jump == 1
			LocalPawn.walking = LocalPawn.velocity > 5 and cmd.in_speed == 1
			LocalPawn.crouching = cmd.in_duck == 1
			LocalPawn.side = cmd.in_moveright == 1 and -1 or cmd.in_moveleft == 1 and 1 or 0

			LocalPawn.peeking, LocalPawn.vulnerable = can_damage_enemy()
		end
	end
end

local function update_local_player_render_state(event_data)
	LocalPawn.self = entity.get_local_player()
	LocalPawn.valid = LocalPawn.self and entity.is_alive(LocalPawn.self) and true or false
	LocalPawn.in_game = true
	render_module.valid = LocalPawn.valid
	local cur_threat = client.current_threat()
	LocalPawn.threat = LocalPawn.valid and (cur_threat ~= nil and cur_threat ~= 0 and cur_threat or get_closest_enemy()) or nil
	LocalPawn.weapon = LocalPawn.valid and entity.get_player_weapon(LocalPawn.self) or nil
	entities_list = entity.get_players() or {}

	enemies_list = {}
	teammates_list = {}
	for i = 1, #entities_list do
		local p = entities_list[i]
		if entity.is_enemy(p) then
			enemies_list[#enemies_list + 1] = p
		else
			teammates_list[#teammates_list + 1] = p
		end
	end

	if LocalPawn.valid then
		LocalPawn.origin = vector(entity.get_origin(LocalPawn.self))
		LocalPawn.duck_amount = entity.get_prop(LocalPawn.self, "m_flDuckAmount")
		LocalPawn.max_speed = get_max_speed()

		local velocity_x, velocity_y, velocity_z = entity.get_prop(LocalPawn.self, "m_vecVelocity")

		LocalPawn.velocity = math.sqrt3(velocity_x, velocity_y, velocity_z)
		LocalPawn.movetype = entity.get_prop(LocalPawn.self, "m_MoveType")
	end
end



local function update_game_state(event_data)
	LocalPawn.self = entity.get_local_player()
	LocalPawn.valid = LocalPawn.self and entity.is_alive(LocalPawn.self) and true or false
	LocalPawn.gamerules = entity.get_game_rules()
end

eventManager.setup_command:set(update_local_player_state)
eventManager.run_command:set(update_local_player_render_state)
eventManager.net_update_end:set(update_game_state)
eventManager.player_death:set(function(event_data)
	if client.userid_to_entindex(event_data.userid) ~= LocalPawn.self then
		return
	end

	eventManager.local_death:fire(event_data)
end)
eventManager.player_spawn:set(function(event_data)
	if client.userid_to_entindex(event_data.userid) ~= LocalPawn.self then
		return
	end

	eventManager.local_spawn:fire(event_data)
end)
eventManager.player_connect_full:set(function(event_data)
	if client.userid_to_entindex(event_data.userid) ~= LocalPawn.self then
		return
	end

	eventManager.local_connect_full:fire(event_data)
end)

client.set_event_callback("round_start", function(event_data)
	ab_state.active = false
	ab_state.yaw_shift_left = 0
	ab_state.yaw_shift_right = 0
	ab_state.desync_shift_left = 0
	ab_state.desync_shift_right = 0
	ab_state.timer_end = nil
end)

client.set_event_callback("player_disconnect", function(event_data)
	if event_data.name then
		ab_history[event_data.name] = nil
	end
end)

function entity.is_lethal(target_player)
	if not LocalPawn.weapon_t or not target_player or entity.is_dormant(target_player) then
		return false
	end

	local potential_body_damage = LocalPawn.weapon_t.damage * 1.25

	return math.ceil(LocalPawn.weapon_t.armor_ratio * 0.5 * potential_body_damage) >= entity.get_prop(target_player, "m_iHealth")
end

local Gglobal

local function safe_get(pui_ref)
	if not pui_ref then return nil end
	local success, result = pcall(pui_ref.get, pui_ref)
	return success and result or nil
end

local function safe_override(pui_ref, val)
	if not pui_ref then return end
	pcall(pui_ref.override, pui_ref, val)
end

local function safe_set(pui_ref, val)
	if not pui_ref then return end
	pcall(pui_ref.set, pui_ref, val)
end


local function resetstatistic()
	storage.stats.loaded = 1
	storage.stats.evaded = 0
	storage.stats.killed = 0
	storage.stats.missed = 0
	storage.stats.shots = 0
end

reference = {
	rage = {
		weapon = hui.reference("RAGE", "Weapon type", "Weapon type"),
		aimbot = {
			enable = hui.reference("RAGE", "Aimbot", "Enabled"),
			force_baim = hui.reference("RAGE", "Aimbot", "Force body aim"),
			force_sp = hui.reference("RAGE", "Aimbot", "Force safe point"),
			hit_chance = hui.reference("RAGE", "Aimbot", "Minimum hit chance"),
			damage = hui.reference("RAGE", "Aimbot", "Minimum damage"),
			damage_ovr = {
				hui.reference("RAGE", "Aimbot", "Minimum damage override")
			},
			double_tap = {
				hui.reference("RAGE", "Aimbot", "Double tap")
			},
			dt_fl = {
				hui.reference("RAGE", "Aimbot", "Double tap fake lag limit")
			}
		},
		other = {
			peek = hui.reference("RAGE", "Other", "Quick peek assist"),
			duck = hui.reference("RAGE", "Other", "Duck peek assist"),
			log_misses = hui.reference("RAGE", "Other", "Log misses due to spread")
		}
	},
	aa = {
		angles = {
			enable = hui.reference("AA", "Anti-Aimbot angles", "Enabled"),
			pitch = {
				hui.reference("AA", "Anti-Aimbot angles", "Pitch")
			},
			yaw = {
				hui.reference("AA", "Anti-Aimbot angles", "Yaw")
			},
			base = hui.reference("AA", "Anti-Aimbot angles", "Yaw base"),
			jitter = {
				hui.reference("AA", "Anti-Aimbot angles", "Yaw jitter")
			},
			body = {
				hui.reference("AA", "Anti-Aimbot angles", "Body yaw")
			},
			edge = hui.reference("AA", "Anti-Aimbot angles", "Edge yaw"),
			fs_body = hui.reference("AA", "Anti-Aimbot angles", "Freestanding body yaw"),
			freestand = hui.reference("AA", "Anti-Aimbot angles", "Freestanding"),
			roll = hui.reference("AA", "Anti-Aimbot angles", "Roll")
		},
		fakelag = {
			enable = hui.reference("AA", "Fake lag", "Enabled"),
			amount = hui.reference("AA", "Fake lag", "Amount"),
			variance = hui.reference("AA", "Fake lag", "Variance"),
			limit = hui.reference("AA", "Fake lag", "Limit")
		},
		other = {
			slowmo = hui.reference("AA", "Other", "Slow motion"),
			legs = hui.reference("AA", "Other", "Leg movement"),
			onshot = hui.reference("AA", "Other", "On shot anti-aim"),
			fp = hui.reference("AA", "Other", "Fake peek")
		}
	},
	misc = {
		clantag = hui.reference("MISC", "Miscellaneous", "Clan tag spammer"),
		log_damage = hui.reference("MISC", "Miscellaneous", "Log damage dealt"),
		ping_spike = hui.reference("MISC", "Miscellaneous", "Ping spike"),
		settings = {
			dpi = hui.reference("MISC", "Settings", "DPI scale"),
			accent = hui.reference("MISC", "Settings", "Menu color"),
			maxshift = hui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks2")
		},
		ghelper = sreference(hui.reference, "VISUALS", "Other ESP", "Helper")
	}
}

local one_time_action_elements = {}

client.delay_call(0.1, function()
	for i = 1, #one_time_action_elements do
		local element_config = one_time_action_elements[i]

		element_config[1]:set_callback(function()
			element_config[1]:set(element_config[2])

			if element_config[3] then
				element_config[1]:set_visible(false)
			else
				element_config[1]:set_enabled(false)
			end
		end, true)
	end
end)

local ui_helpers = {
	tabs = {
		{
			"home",
			"Home"
		},
		{
			"settings",
			"Settings"
		},
		{
			"antiaim",
			"Anti-aim"
		},
		{
			"ragebot",
			"Ragebot"
		}
	},
	header = function(parent_element, label_text)
		local header_elements

		if label_text then
			header_elements = {
				parent_element:label(string.format("\v%s", label_text)),
				parent_element:label("\a373737FF‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾")
			}
		else
			header_elements = parent_element:label("\a373737FF‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾")
		end

		return header_elements
	end,
	feature = function(base_element, create_sub_elements_func)
		base_element = base_element.__type == "pui::element" and {
			base_element
		} or base_element

		local sub_elements, dependency_flag = create_sub_elements_func(base_element[1])

		for key, element in pairs(sub_elements) do
			if type(dependency_flag) == "table" then
				local dep = dependency_flag[key]
				if dep ~= nil then
					if dep[1] ~= nil and (type(dep[1]) ~= "table" or dep[1].__type == "pui::element") then
						dep = { dep }
					end
					element:depend(unpack(dep))
				else
					element:depend({
						base_element[1],
						true
					})
				end
			else
				element:depend({
					base_element[1],
					dependency_flag
				})
			end
		end

		sub_elements[base_element.key or "on"] = base_element[1]

		return sub_elements
	end,
	space = function(parent_element)
		return parent_element:label("\n")
	end,
	blissfunc = function(ui_element, required_level, default_value)
		required_level = required_level or 2

		if required_level > config.level then
			one_time_action_elements[#one_time_action_elements + 1] = {
				ui_element,
				default_value or false,
				required_level >= 3
			}
		end

		return ui_element
	end
}
local ui_groups = {
	other = hui.group("AA", "Other"),
	angles = hui.group("AA", "Anti-aimbot angles"),
	fakelag = hui.group("AA", "Fake lag")
}

hui.macros.pasteria = "\a74A6A9FF"
hui.macros.dot = "\v•\r  "
hui.macros.p = "\aCDCDCD50—  \r"
hui.macros.silent = "\aCDCDCD50"
hui.macros.insecure = "\aB6B665FF"
Gglobal = {
	title = ui_groups.fakelag:label("pasteria"),
	selector = ui_groups.fakelag:combobox("\nawselector", table.distribute(ui_helpers.tabs, 2, nil)),
	ui_helpers.header(ui_groups.fakelag),
	home = {
		info = {
			user = ui_groups.fakelag:label(string.format("Welcome, \v%s", config.user)),
			version = ui_groups.fakelag:label(string.format("Version: \v%s", config.version)),

			ui_helpers.space(ui_groups.fakelag),
			ui_helpers.header(ui_groups.fakelag, "Statistic"),
			loaded   = ui_groups.fakelag:label("Loaded: \v 0"),
			evaded   = ui_groups.fakelag:label("Evaded: \v0"),
			killed   = ui_groups.fakelag:label("Killed: \v0"),
			missed   = ui_groups.fakelag:label("Missed: \v0"),
			shots    = ui_groups.fakelag:label("Shots: \v0"),

			ui_groups.fakelag:button("Reset statistic", function()
				resetstatistic()
			end),
		},
		config = {
			ui_helpers.header(ui_groups.other, "New config"),
			name = ui_groups.other:textbox("Name"),
			create = ui_groups.other:button("Create"),
			import = ui_groups.other:button("Import"),
			ui_helpers.header(ui_groups.angles, "Configs"),
			list = ui_groups.angles:listbox("Configs", {
				"Default"
			}),
			selected = ui_groups.angles:label("Selected: \vDefault"),
			list_report = ui_groups.angles:label(" "),
			load = ui_groups.angles:button("\f<pasteria>Load"),
			loadaa = ui_groups.angles:button("Load AA only"),
			save = ui_groups.angles:button("Save"),
			export = ui_groups.angles:button("Export"),
			delete = ui_groups.angles:button("\aD95148FFDelete"),
			deleteb = ui_groups.angles:button("\aD9514840Delete")
		},
		verify = {
			ui_helpers.space(ui_groups.other),
			ui_helpers.header(ui_groups.other, "Other"),
			ui_groups.other:button("Discord", function()
				client.open_link("https://dsc.gg/pasteria")
			end),
			ui_groups.other:button("Site", function()
				client.open_link("https://dsc.gg/pasteria")
			end)
		}
	},
	settings = {
		tab = ui_groups.angles:combobox("\nstab", {
			"Features",
			"Visual"
		}),
		space = ui_helpers.space(ui_groups.angles)
	}
}
gui = {
	rage = {
		ui_helpers.header(ui_groups.angles, "Ragebot"),
		exswitch = ui_helpers.feature({ui_groups.angles:checkbox("Auto hide shots")}, function(checkbox_element)
			return {
				allow = ui_groups.angles:multiselect("\f<p>Additional weapons", {"Pistols", "Desert Eagle"})}, true
		end),
		recharge = ui_groups.angles:checkbox("Allow force recharge"),
		peekfix = ui_helpers.blissfunc(ui_groups.angles:checkbox("Early defensive")),
		aimbot_helper = ui_helpers.feature({ui_groups.angles:checkbox("Aimbot helper")}, function(helper_enable)
			local weapon = ui_groups.angles:combobox("\nWeapon", {"SSG-08", "AWP", "Auto Snipers"})
			
			local ssg_select = ui_groups.angles:multiselect("\nSelect SSG08", {"Force safe point", "Prefer body aim", "Force body aim", "Ping spike"})
			local ssg_force_safe = ui_groups.angles:multiselect("Force safe point triggers SSG08", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local ssg_force_safe_hp = ui_groups.angles:slider("Force safe point HP Trigger SSG08", 1, 100, 50, true, "hp")
			local ssg_force_safe_miss = ui_groups.angles:slider("Force safe point Missed Trigger SSG08", 1, 10, 2, true, "shots")
			local ssg_prefer_body = ui_groups.angles:multiselect("Prefer body aim triggers SSG08", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local ssg_prefer_body_hp = ui_groups.angles:slider("Prefer body aim HP Trigger SSG08", 1, 100, 50, true, "hp")
			local ssg_prefer_body_miss = ui_groups.angles:slider("Prefer body aim Missed Trigger SSG08", 1, 10, 2, true, "shots")
			local ssg_force_body = ui_groups.angles:multiselect("Force body aim triggers SSG08", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local ssg_force_body_hp = ui_groups.angles:slider("Force body aim HP Trigger SSG08", 1, 100, 50, true, "hp")
			local ssg_force_body_miss = ui_groups.angles:slider("Force body aim Missed Trigger SSG08", 1, 10, 2, true, "sh")
			local ssg_ping_spike_value = ui_groups.angles:slider("Ping spike value SSG08", 1, 200, 80, true, "ms")

			local awp_select = ui_groups.angles:multiselect("\nSelect AWP", {"Force safe point", "Prefer body aim", "Force body aim", "Ping spike"})
			local awp_force_safe = ui_groups.angles:multiselect("Force safe point triggers AWP", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local awp_force_safe_hp = ui_groups.angles:slider("Force safe point HP Trigger AWP", 1, 100, 50, true, "hp")
			local awp_force_safe_miss = ui_groups.angles:slider("Force safe point Missed Trigger AWP", 1, 10, 2, true, "sh")
			local awp_prefer_body = ui_groups.angles:multiselect("Prefer body aim triggers AWP", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local awp_prefer_body_hp = ui_groups.angles:slider("Prefer body aim HP Trigger AWP", 1, 100, 50, true, "hp")
			local awp_prefer_body_miss = ui_groups.angles:slider("Prefer body aim Missed Trigger AWP", 1, 10, 2, true, "sh")
			local awp_force_body = ui_groups.angles:multiselect("Force body aim triggers AWP", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local awp_force_body_hp = ui_groups.angles:slider("Force body aim HP Trigger AWP", 1, 100, 50, true, "hp")
			local awp_force_body_miss = ui_groups.angles:slider("Force body aim Missed Trigger AWP", 1, 10, 2, true, "sh")
			local awp_ping_spike_value = ui_groups.angles:slider("Ping spike value AWP", 1, 200, 130, true, "ms")

			local auto_select = ui_groups.angles:multiselect("\nSelect AUTO", {"Force safe point", "Prefer body aim", "Force body aim", "Ping spike"})
			local auto_force_safe = ui_groups.angles:multiselect("Force safe point triggers AUTO", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local auto_force_safe_hp = ui_groups.angles:slider("Force safe point HP Trigger AUTO", 1, 100, 50, true, "hp")
			local auto_force_safe_miss = ui_groups.angles:slider("Force safe point Missed Trigger AUTO", 1, 10, 2, true, "sh")
			local auto_prefer_body = ui_groups.angles:multiselect("Prefer body aim triggers AUTO", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local auto_prefer_body_hp = ui_groups.angles:slider("Prefer body aim HP Trigger AUTO", 1, 100, 50, true, "hp")
			local auto_prefer_body_miss = ui_groups.angles:slider("Prefer body aim Missed Trigger AUTO", 1, 10, 2, true, "sh")
			local auto_force_body = ui_groups.angles:multiselect("Force body aim triggers AUTO", {"Enemy HP < X", "X Missed Shots", "Lethal", "Height advantage", "Enemy higher than you"})
			local auto_force_body_hp = ui_groups.angles:slider("Force body aim HP Trigger AUTO", 1, 100, 50, true, "hp")
			local auto_force_body_miss = ui_groups.angles:slider("Force body aim Missed Trigger AUTO", 1, 10, 2, true, "sh")
			local auto_ping_spike_value = ui_groups.angles:slider("Ping spike value AUTO", 1, 200, 105, true, "ms")

			-- Set up dependencies manually
			ssg_select:depend({weapon, "SSG-08"})
			ssg_force_safe:depend({weapon, "SSG-08"}, {ssg_select, "Force safe point"})
			ssg_force_safe_hp:depend({weapon, "SSG-08"}, {ssg_select, "Force safe point"}, {ssg_force_safe, "Enemy HP < X"})
			ssg_force_safe_miss:depend({weapon, "SSG-08"}, {ssg_select, "Force safe point"}, {ssg_force_safe, "X Missed Shots"})
			ssg_prefer_body:depend({weapon, "SSG-08"}, {ssg_select, "Prefer body aim"})
			ssg_prefer_body_hp:depend({weapon, "SSG-08"}, {ssg_select, "Prefer body aim"}, {ssg_prefer_body, "Enemy HP < X"})
			ssg_prefer_body_miss:depend({weapon, "SSG-08"}, {ssg_select, "Prefer body aim"}, {ssg_prefer_body, "X Missed Shots"})
			ssg_force_body:depend({weapon, "SSG-08"}, {ssg_select, "Force body aim"})
			ssg_force_body_hp:depend({weapon, "SSG-08"}, {ssg_select, "Force body aim"}, {ssg_force_body, "Enemy HP < X"})
			ssg_force_body_miss:depend({weapon, "SSG-08"}, {ssg_select, "Force body aim"}, {ssg_force_body, "X Missed Shots"})
			ssg_ping_spike_value:depend({weapon, "SSG-08"}, {ssg_select, "Ping spike"})

			awp_select:depend({weapon, "AWP"})
			awp_force_safe:depend({weapon, "AWP"}, {awp_select, "Force safe point"})
			awp_force_safe_hp:depend({weapon, "AWP"}, {awp_select, "Force safe point"}, {awp_force_safe, "Enemy HP < X"})
			awp_force_safe_miss:depend({weapon, "AWP"}, {awp_select, "Force safe point"}, {awp_force_safe, "X Missed Shots"})
			awp_prefer_body:depend({weapon, "AWP"}, {awp_select, "Prefer body aim"})
			awp_prefer_body_hp:depend({weapon, "AWP"}, {awp_select, "Prefer body aim"}, {awp_prefer_body, "Enemy HP < X"})
			awp_prefer_body_miss:depend({weapon, "AWP"}, {awp_select, "Prefer body aim"}, {awp_prefer_body, "X Missed Shots"})
			awp_force_body:depend({weapon, "AWP"}, {awp_select, "Force body aim"})
			awp_force_body_hp:depend({weapon, "AWP"}, {awp_select, "Force body aim"}, {awp_force_body, "Enemy HP < X"})
			awp_force_body_miss:depend({weapon, "AWP"}, {awp_select, "Force body aim"}, {awp_force_body, "X Missed Shots"})
			awp_ping_spike_value:depend({weapon, "AWP"}, {awp_select, "Ping spike"})

			auto_select:depend({weapon, "Auto Snipers"})
			auto_force_safe:depend({weapon, "Auto Snipers"}, {auto_select, "Force safe point"})
			auto_force_safe_hp:depend({weapon, "Auto Snipers"}, {auto_select, "Force safe point"}, {auto_force_safe, "Enemy HP < X"})
			auto_force_safe_miss:depend({weapon, "Auto Snipers"}, {auto_select, "Force safe point"}, {auto_force_safe, "X Missed Shots"})
			auto_prefer_body:depend({weapon, "Auto Snipers"}, {auto_select, "Prefer body aim"})
			auto_prefer_body_hp:depend({weapon, "Auto Snipers"}, {auto_select, "Prefer body aim"}, {auto_prefer_body, "Enemy HP < X"})
			auto_prefer_body_miss:depend({weapon, "Auto Snipers"}, {auto_select, "Prefer body aim"}, {auto_prefer_body, "X Missed Shots"})
			auto_force_body:depend({weapon, "Auto Snipers"}, {auto_select, "Force body aim"})
			auto_force_body_hp:depend({weapon, "Auto Snipers"}, {auto_select, "Force body aim"}, {auto_force_body, "Enemy HP < X"})
			auto_force_body_miss:depend({weapon, "Auto Snipers"}, {auto_select, "Force body aim"}, {auto_force_body, "X Missed Shots"})
			auto_ping_spike_value:depend({weapon, "Auto Snipers"}, {auto_select, "Ping spike"})

			return {
				weapon = weapon,
				ssg_select = ssg_select,
				ssg_force_safe = ssg_force_safe,
				ssg_force_safe_hp = ssg_force_safe_hp,
				ssg_force_safe_miss = ssg_force_safe_miss,
				ssg_prefer_body = ssg_prefer_body,
				ssg_prefer_body_hp = ssg_prefer_body_hp,
				ssg_prefer_body_miss = ssg_prefer_body_miss,
				ssg_force_body = ssg_force_body,
				ssg_force_body_hp = ssg_force_body_hp,
				ssg_force_body_miss = ssg_force_body_miss,
				ssg_ping_spike_value = ssg_ping_spike_value,

				awp_select = awp_select,
				awp_force_safe = awp_force_safe,
				awp_force_safe_hp = awp_force_safe_hp,
				awp_force_safe_miss = awp_force_safe_miss,
				awp_prefer_body = awp_prefer_body,
				awp_prefer_body_hp = awp_prefer_body_hp,
				awp_prefer_body_miss = awp_prefer_body_miss,
				awp_force_body = awp_force_body,
				awp_force_body_hp = awp_force_body_hp,
				awp_force_body_miss = awp_force_body_miss,
				awp_ping_spike_value = awp_ping_spike_value,

				auto_select = auto_select,
				auto_force_safe = auto_force_safe,
				auto_force_safe_hp = auto_force_safe_hp,
				auto_force_safe_miss = auto_force_safe_miss,
				auto_prefer_body = auto_prefer_body,
				auto_prefer_body_hp = auto_prefer_body_hp,
				auto_prefer_body_miss = auto_prefer_body_miss,
				auto_force_body = auto_force_body,
				auto_force_body_hp = auto_force_body_hp,
				auto_force_body_miss = auto_force_body_miss,
				auto_ping_spike_value = auto_ping_spike_value
			}, true
		end)
	},
	visuals = {
		ui_groups.angles:label("Accent color"),
		accent = ui_groups.angles:color_picker("\nacccent", palette.accent.r, palette.accent.g, palette.accent.b, 255),
		ui_helpers.space(ui_groups.angles),
		ui_helpers.header(ui_groups.angles, "Screen"),
		crosshair = ui_helpers.feature(ui_groups.angles:checkbox("Crosshair indicators"), function(checkbox_element)
			return {
				style = ui_groups.angles:combobox("\nch_style", {
					"Classic",
					"Mini"
				}),
				logo = ui_groups.angles:checkbox("\f<p>Butterfly")
			}, true
		end),
		damage = ui_groups.angles:checkbox("Damage indicator"),
		arrows = ui_groups.angles:checkbox("Anti-aim arrows"),
		debugger = ui_groups.angles:checkbox("AA Debugger"),
		water = ui_helpers.feature(ui_groups.angles:checkbox("Watermark"), function()
			return {
				hide = ui_groups.angles:checkbox("\f<p>Hide logo"),
				ui_groups.angles:label("\f<p>Custom name"),
				name = ui_groups.angles:textbox("\ncustomname")
			}, true
		end),
		keylist = ui_groups.angles:checkbox("Keylist"),
		speclist = ui_groups.angles:checkbox("Speclist"),
		slowdown = ui_groups.angles:checkbox("Slowdown warning"),
		marker = ui_groups.angles:checkbox("Hitmarker"),
		ui_helpers.space(ui_groups.angles),
		ui_helpers.header(ui_groups.angles, "Other"),
		aspect = ui_helpers.feature(ui_groups.angles:checkbox("Aspect ratio"), function()
			return {
				ratio = ui_groups.angles:slider("\naratio", 80, 200, 133, true, nil, 0.01, table.distribute(ScriptData.aspect_ratios, 2, 1))
			}, true
		end),
		dpi = ui_groups.angles:checkbox("DPI scaling")
	},
	misc = {
		ui_helpers.header(ui_groups.angles, "Miscellaneous"),
		clantag = ui_groups.angles:checkbox("Clantag"),
		filter = ui_groups.angles:checkbox("Console filter"),
		logs = ui_helpers.feature(ui_groups.angles:checkbox("Eventlogger"), function(checkbox_element)
			return {
				events = ui_groups.angles:multiselect("\f<p>Events", {
					"Ragebot shots",
					"Harming enemies",
					"Getting harmed",
					"Anti-aim info"
				}),
				output = ui_groups.angles:multiselect("\f<p>Output", {
					"Console",
					"Screen"
				})
			}, true
		end),
		ladder = ui_groups.angles:checkbox("Fast ladder"),
		breaker = ui_helpers.feature(ui_groups.angles:checkbox("Animation breaker"), function(checkbox_element)
			return {
				pitch = ui_groups.angles:checkbox("\f<p>Pitch 0 on land"),
				air = ui_groups.angles:combobox("\f<p>Air", {
					"Disabled",
					"Static",
					"Jitter",
					"Moonwalk"
				}),
				ground = ui_groups.angles:combobox("\f<p>Ground", {
					"Disabled",
					"Static",
					"Jitter",
					"Moonwalk"
				})
			}, true
		end)
	},
	antiaim = {
		on = ui_groups.fakelag:checkbox("Enable\naa"),
		tab = ui_groups.fakelag:combobox("\naatab", {
			"General",
			"Builder",
			"Anti-bruteforce",
			"Defensive"
		}, nil, false),
		ab = {
			on = ui_groups.angles:slider("\v•  Anti-bruteforce", 0, 1, 0, true, nil, 1, { [0] = "Off", [1] = "On" }),
			warning = ui_groups.angles:label("\aD95148FFRequires Pasteria AA operator!"),
			triggers = ui_groups.angles:multiselect("Triggers", { "Local shot", "Evade", "On damage", "On peek" }),
			power = ui_groups.angles:slider("Power", 0, 100, 25, true, "%", 1, { [0] = "Auto" }),
			timer = ui_groups.angles:slider("Timer", 0, 100, 30, true, "s", 0.1, { [0] = "On trigger" }),
			split = ui_groups.angles:checkbox("Split-side offsets"),
			avoid_same = ui_groups.angles:checkbox("Avoid same position"),
			cycle = ui_groups.angles:checkbox("Dynamic trigger rotation")
		},
		general = {
			ui_helpers.header(ui_groups.angles, "General"),
			mode = ui_groups.angles:combobox("Anti-aim operator", {
				"gamesense",
				"pasteria"
			}),
			invert = ui_groups.angles:hotkey("Inverter", false, 0),
			edge = ui_groups.angles:hotkey("Edge yaw", false, 0),
			fs = ui_helpers.feature(ui_groups.angles:checkbox("Freestanding", 0), function(checkbox_element)
				return {
					static = ui_groups.angles:checkbox("\f<p>Static\nfs")
				}, true
			end),
			manual = ui_helpers.feature(ui_groups.angles:checkbox("Manual yaw"), function()
				return {
					static = ui_groups.angles:checkbox("\f<p>Static\nmy"),
					left = ui_groups.angles:hotkey("\f<p>Left \f<silent>HK\r", false, 0),
					right = ui_groups.angles:hotkey("\f<p>Right \f<silent>HK\r", false, 0),
					reset = ui_groups.angles:hotkey("\f<p>Reset \f<silent>HK\r", false, 0)
				}, true
			end),
			ui_helpers.space(ui_groups.angles),
			ui_helpers.header(ui_groups.angles, "Misc"),
			head = ui_helpers.feature(ui_groups.angles:checkbox("Safe head"), function()
				return {
					smart = ui_groups.angles:checkbox("\f<p>Smart")
				}, true
			end),
			jmove = ui_groups.angles:checkbox("Jitter move"),
			stab = ui_groups.angles:checkbox("Avoid backstab"),
			use = ui_groups.angles:checkbox("Legit AA"),
			fl = ui_helpers.feature(ui_groups.angles:checkbox("Fakelag"), function()
				return {
					mode = ui_groups.angles:combobox("\nflmode", {
						"Dynamic",
						"Maximum",
						"Fluctuate",
						"Random"
					}),
					limit = ui_groups.angles:slider("\nflLimit", 1, 15, 14, true, "t"),
					variance = ui_groups.angles:slider("\nflvariance", 0, 100, 0, true, "%")
				}, true
			end)
		},
		state = {
			ui_groups.angles:label("\v•  states builder"),
			selector = ui_groups.angles:combobox("\nstateselector", table.distribute(AntiAimConditions.states, 2), nil, false),
		},
		builder = {},
		def = {
			ui_helpers.header(ui_groups.other, "General"),
			snap = ui_helpers.feature(ui_groups.other:checkbox("\f<insecure>Defensive AA", 0), function()
				return {
					os = ui_groups.other:checkbox("\f<p>Allow with On shot AA")
				}, true
			end),
			ui_helpers.space(ui_groups.other),
			ui_helpers.header(ui_groups.other, "Misc"),
			triggers = ui_groups.other:multiselect("LC break triggers", {
				"Jumping",
				"Crouching",
				"Weapon change"
			}),
			setup = {
				ui_groups.angles:label("\v•  defensive setup"),
				selector = ui_groups.angles:combobox("\nstateselector", table.distribute(AntiAimConditions.snaps, 2), nil, false),
			}
		},
		snaps = {}
	},
	drag = drag_manager.data
}

local function create_aa_builder_control(config_path, ui_element)
	ui_element:set_callback(function(callback_data)
		table.place(Anti_Aim.builder.custom, config_path, callback_data.value)
	end, true)

	return ui_element
end

local aa_builder_slider_labels = {
	delay = {
		[0] = "Off"
	},
	speed = {
		[0] = "RD"
	},
	freeze = {
		[0] = "RD",
		[17] = "FL"
	},
	freeze_chance = {
		[0] = "DS"
	},
	rand_step = {
		[0] = "RD",
		[16] = "FL"
	}
}

for i, condition_data in ipairs(AntiAimConditions.states) do
	local condition_id = condition_data[1]
	local condition_name = condition_data[2]
	local condition_suffix = condition_data[3]

	gui.antiaim.builder[condition_id], hui.macros.z = {}, "\n" .. condition_suffix

	local current_builder_tab = gui.antiaim.builder[condition_id]
	local parent_group = ui_groups.angles

	if not (condition_id == "default") then
		current_builder_tab.override = create_aa_builder_control({
			condition_id,
			"override"
		}, parent_group:checkbox("override \v" .. string.lower(condition_name)))
		current_builder_tab[#current_builder_tab + 1] = parent_group:label("\n")
	end

	current_builder_tab[#current_builder_tab + 1] = parent_group:label("\v•  yaw\f<z>")
	current_builder_tab.off = create_aa_builder_control({
		condition_id,
		"off"
	}, parent_group:slider("offset\f<z>", -60, 60, 0, true, "°"))
	current_builder_tab.add = ui_helpers.feature(create_aa_builder_control({
		condition_id,
		"add",
		"on"
	}, parent_group:checkbox("add yaw left / right\f<z>")), function(checkbox_element)
		return {
			l = create_aa_builder_control({
				condition_id,
				"add",
				"l"
			}, parent_group:slider("\nleft limit\f<z>add", -60, 60, 0, true, "L°")),
			r = create_aa_builder_control({
				condition_id,
				"add",
				"r"
			}, parent_group:slider("\nright limit\f<z>add", -60, 60, 0, true, "R°"))
		}, true
	end)
	current_builder_tab.mod = ui_helpers.feature(create_aa_builder_control({
		condition_id,
		"mod",
		"type"
	}, parent_group:combobox("modifier\f<z>", {
		"Off",
		"Jitter",
		"Ways",
		"Skitter",
		"Rotate",
		"Random",
		"Sway Jitter"
	})), function(combobox_element)
		return {
			ways = create_aa_builder_control({
				condition_id,
				"mod",
				"ways"
			}, parent_group:slider("ways\f<z>", 3, 7, 3)):depend({
				combobox_element,
				"Ways",
				"Skitter"
			}),
			deg = create_aa_builder_control({
				condition_id,
				"mod",
				"deg"
			}, parent_group:slider("degree\f<z>", 0, 60, 0, true, "°"))
		}, function(dependency_element)
			return dependency_element.value ~= "Off"
		end
	end)
	current_builder_tab[#current_builder_tab + 1] = parent_group:label("\n")
	current_builder_tab[#current_builder_tab + 1] = parent_group:label("\v•  body yaw\f<z>")
	current_builder_tab.des = ui_helpers.feature(create_aa_builder_control({
		condition_id,
		"des",
		"on"
	}, parent_group:checkbox("desync\f<z>")), function()
		return {
			j = create_aa_builder_control({
				condition_id,
				"des",
				"j"
			}, parent_group:checkbox("jitter\f<z>des")),
			l = create_aa_builder_control({
				condition_id,
				"des",
				"l"
			}, parent_group:slider("\nleft limit\f<z>des", 0, 60, 60, true, "L°")):depend({
				gui.antiaim.general.mode,
				"pasteria"
			}),
			r = create_aa_builder_control({
				condition_id,
				"des",
				"r"
			}, parent_group:slider("\nright limit\f<z>des", 0, 60, 60, true, "R°")):depend({
				gui.antiaim.general.mode,
				"pasteria"
			}),
			rand = create_aa_builder_control({
				condition_id,
				"des",
				"rand"
			}, parent_group:checkbox("elusive desync\f<z>des")):depend({
				gui.antiaim.general.mode,
				"pasteria"
			}),
			rand_mode = create_aa_builder_control({
				condition_id,
				"des",
				"rand_mode"
			}, parent_group:combobox("\nrandmode\f<z>des", { "default", "fluctuate" })),
			l_fluctuate = create_aa_builder_control({
				condition_id,
				"des",
				"l_fluctuate"
			}, parent_group:slider("\n(left min)\f<z>des", 0, 60, 20, true, "L°")),
			r_fluctuate = create_aa_builder_control({
				condition_id,
				"des",
				"r_fluctuate"
			}, parent_group:slider("\n(right min)\f<z>des", 0, 60, 20, true, "R°")),
			rand_step = create_aa_builder_control({
				condition_id,
				"des",
				"rand_step"
			}, parent_group:slider("\nrandstep\f<z>des", 0, 16, 0, true, "°", 1, aa_builder_slider_labels.rand_step))
		}, true
	end)

	current_builder_tab.des.rand_mode:depend({
		current_builder_tab.des.on,
		true
	}, {
		gui.antiaim.general.mode,
		"pasteria"
	}, {
		current_builder_tab.des.rand,
		true
	})

	current_builder_tab.des.rand_step:depend({
		current_builder_tab.des.on,
		true
	}, {
		gui.antiaim.general.mode,
		"pasteria"
	}, {
		current_builder_tab.des.rand,
		true
	}, {
		current_builder_tab.des.rand_mode,
		"default"
	})

	current_builder_tab.des.l_fluctuate:depend({
		current_builder_tab.des.on,
		true
	}, {
		gui.antiaim.general.mode,
		"pasteria"
	}, {
		current_builder_tab.des.rand,
		true
	})

	current_builder_tab.des.r_fluctuate:depend({
		current_builder_tab.des.on,
		true
	}, {
		gui.antiaim.general.mode,
		"pasteria"
	}, {
		current_builder_tab.des.rand,
		true
	})

	current_builder_tab[#current_builder_tab + 1] = parent_group:label("\n")
	current_builder_tab[#current_builder_tab + 1] = parent_group:label("\v•  misc\f<z>")
	current_builder_tab.misc = ui_helpers.feature(create_aa_builder_control({
		condition_id,
		"misc",
		"on"
	}, parent_group:checkbox("accidental yaw\f<z>misc")), function(base_element)
		local sync_mode = create_aa_builder_control({
			condition_id,
			"misc",
			"sync_mode"
		}, parent_group:combobox("\nsync_mode\f<z>misc", { "single", "synced" }))

		local single = {
			mode = create_aa_builder_control({
				condition_id,
				"misc",
				"mode"
			}, parent_group:combobox("\nmode\f<z>misc", { "default", "flick", "sway" })),
			range = create_aa_builder_control({
				condition_id,
				"misc",
				"range"
			}, parent_group:slider("\nrange\f<z>misc", 0, 45, 25, true, "°")),
			speed = create_aa_builder_control({
				condition_id,
				"misc",
				"speed"
			}, parent_group:slider("\nspeed\f<z>misc", 0, 30, 10, true, "t", 1, aa_builder_slider_labels.speed))
		}

		local left = {
			label = parent_group:label("\v•  left side\f<z>"),
			mode = create_aa_builder_control({
				condition_id,
				"misc",
				"mode_l"
			}, parent_group:combobox("\nmode_l\f<z>misc_l", { "default", "flick", "sway" })),
			range = create_aa_builder_control({
				condition_id,
				"misc",
				"range_l"
			}, parent_group:slider("\nrange_l\f<z>misc_l", 0, 45, 25, true, "°")),
			speed = create_aa_builder_control({
				condition_id,
				"misc",
				"speed_l"
			}, parent_group:slider("\nspeed_l\f<z>misc_l", 0, 30, 10, true, "t", 1, aa_builder_slider_labels.speed))
		}

		local right = {
			label = parent_group:label("\v•  right side\f<z>"),
			mode = create_aa_builder_control({
				condition_id,
				"misc",
				"mode_r"
			}, parent_group:combobox("\nmode_r\f<z>misc_r", { "default", "flick", "sway" })),
			range = create_aa_builder_control({
				condition_id,
				"misc",
				"range_r"
			}, parent_group:slider("\nrange_r\f<z>misc_r", 0, 45, 25, true, "°")),
			speed = create_aa_builder_control({
				condition_id,
				"misc",
				"speed_r"
			}, parent_group:slider("\nspeed_r\f<z>misc_r", 0, 30, 10, true, "t", 1, aa_builder_slider_labels.speed))
		}

		local independent_cycles = create_aa_builder_control({
			condition_id,
			"misc",
			"independent_cycles"
		}, parent_group:checkbox("Independent cycles\f<z>misc"))

		local dep_single = {
			{ base_element, true },
			{ independent_cycles, function() return independent_cycles.value == true or sync_mode.value == "single" end },
			{ sync_mode, function() return independent_cycles.value == true or sync_mode.value == "single" end }
		}

		local dep_sides = {
			{ base_element, true },
			{ independent_cycles, function() return independent_cycles.value == true or sync_mode.value == "synced" end },
			{ sync_mode, function() return independent_cycles.value == true or sync_mode.value == "synced" end }
		}

		return {
			sync_mode = sync_mode,
			independent_cycles = independent_cycles,

			mode = single.mode,
			range = single.range,
			speed = single.speed,

			label_l = left.label,
			mode_l = left.mode,
			range_l = left.range,
			speed_l = left.speed,

			label_r = right.label,
			mode_r = right.mode,
			range_r = right.range,
			speed_r = right.speed
		}, {
			sync_mode = {
				{ base_element, true },
				{ independent_cycles, function() return independent_cycles.value == false end }
			},
			independent_cycles = {
				{ base_element, true }
			},

			mode = dep_single,
			range = dep_single,
			speed = dep_single,

			label_l = dep_sides,
			mode_l = dep_sides,
			range_l = dep_sides,
			speed_l = dep_sides,

			label_r = dep_sides,
			mode_r = dep_sides,
			range_r = dep_sides,
			speed_r = dep_sides
		}
	end)
	current_builder_tab.delay = ui_helpers.feature(create_aa_builder_control({
		condition_id,
		"delay",
		"on"
	}, ui_groups.other:checkbox("delay\f<z>")), function(checkbox_element)
		local type_element = create_aa_builder_control({
			condition_id,
			"delay",
			"type"
		}, ui_groups.other:combobox("\ntype\f<z>", { "single", "synced" }))

		local single_mode = create_aa_builder_control({
			condition_id,
			"delay",
			"single_mode"
		}, ui_groups.other:combobox("\nmode\f<z>", { "static", "random", "break", "increment", "fluctuate" })):depend({
			type_element,
			"single"
		})

		local single_value = create_aa_builder_control({
			condition_id,
			"delay",
			"single_value"
		}, ui_groups.other:slider("\nvalue\f<z>", 0, 16, 0, true, "t", 1, aa_builder_slider_labels.delay)):depend({
			type_element,
			"single"
		})

		local single_freeze_on = create_aa_builder_control({
			condition_id,
			"delay",
			"single_freeze_on"
		}, ui_groups.other:checkbox("random freeze\f<z>")):depend({
			type_element,
			"single"
		})

		local single_freeze_chance = create_aa_builder_control({
			condition_id,
			"delay",
			"single_freeze_chance"
		}, ui_groups.other:slider("\nchance\f<z>", 0, 100, 30, true, "%", 1, aa_builder_slider_labels.freeze_chance)):depend({
			type_element,
			"single"
		}, single_freeze_on)

		local single_freeze_ticks = create_aa_builder_control({
			condition_id,
			"delay",
			"single_freeze_ticks"
		}, ui_groups.other:slider("\nfreeze ticks\f<z>", 0, 17, 0, true, "t", 1, aa_builder_slider_labels.freeze)):depend({
			type_element,
			"single"
		}, single_freeze_on)

		local left_label = ui_groups.other:label("\v•  left side\f<z>")
		left_label:depend({
			type_element,
			"synced"
		})

		local left_mode = create_aa_builder_control({
			condition_id,
			"delay",
			"left_mode"
		}, ui_groups.other:combobox("\nleft_mode\f<z>", { "static", "random", "break", "increment", "fluctuate" })):depend({
			type_element,
			"synced"
		})

		local left_value = create_aa_builder_control({
			condition_id,
			"delay",
			"left_value"
		}, ui_groups.other:slider("\nleft_value\f<z>", 0, 16, 0, true, "t", 1, aa_builder_slider_labels.delay)):depend({
			type_element,
			"synced"
		})

		local left_freeze_on = create_aa_builder_control({
			condition_id,
			"delay",
			"left_freeze_on"
		}, ui_groups.other:checkbox("random freeze\f<z>left")):depend({
			type_element,
			"synced"
		})

		local left_freeze_chance = create_aa_builder_control({
			condition_id,
			"delay",
			"left_freeze_chance"
		}, ui_groups.other:slider("\nleft chance\f<z>", 0, 100, 30, true, "%", 1, aa_builder_slider_labels.freeze_chance)):depend({
			type_element,
			"synced"
		}, left_freeze_on)

		local left_freeze_ticks = create_aa_builder_control({
			condition_id,
			"delay",
			"left_freeze_ticks"
		}, ui_groups.other:slider("\nleft freeze ticks\f<z>", 0, 17, 0, true, "t", 1, aa_builder_slider_labels.freeze)):depend({
			type_element,
			"synced"
		}, left_freeze_on)

		local right_label = ui_groups.other:label("\v•  right side\f<z>")
		right_label:depend({
			type_element,
			"synced"
		})

		local right_mode = create_aa_builder_control({
			condition_id,
			"delay",
			"right_mode"
		}, ui_groups.other:combobox("\nright_mode\f<z>", { "static", "random", "break", "increment", "fluctuate" })):depend({
			type_element,
			"synced"
		})

		local right_value = create_aa_builder_control({
			condition_id,
			"delay",
			"right_value"
		}, ui_groups.other:slider("\nright_value\f<z>", 0, 16, 0, true, "t", 1, aa_builder_slider_labels.delay)):depend({
			type_element,
			"synced"
		})

		local right_freeze_on = create_aa_builder_control({
			condition_id,
			"delay",
			"right_freeze_on"
		}, ui_groups.other:checkbox("random freeze\f<z>right")):depend({
			type_element,
			"synced"
		})

		local right_freeze_chance = create_aa_builder_control({
			condition_id,
			"delay",
			"right_freeze_chance"
		}, ui_groups.other:slider("\nright chance\f<z>", 0, 100, 30, true, "%", 1, aa_builder_slider_labels.freeze_chance)):depend({
			type_element,
			"synced"
		}, right_freeze_on)

		local right_freeze_ticks = create_aa_builder_control({
			condition_id,
			"delay",
			"right_freeze_ticks"
		}, ui_groups.other:slider("\nright freeze ticks\f<z>", 0, 17, 0, true, "t", 1, aa_builder_slider_labels.freeze)):depend({
			type_element,
			"synced"
		}, right_freeze_on)

		return {
			type = type_element,
			single_mode = single_mode,
			single_value = single_value,
			single_freeze_on = single_freeze_on,
			single_freeze_chance = single_freeze_chance,
			single_freeze_ticks = single_freeze_ticks,
			left_label = left_label,
			left_mode = left_mode,
			left_value = left_value,
			left_freeze_on = left_freeze_on,
			left_freeze_chance = left_freeze_chance,
			left_freeze_ticks = left_freeze_ticks,
			right_label = right_label,
			right_mode = right_mode,
			right_value = right_value,
			right_freeze_on = right_freeze_on,
			right_freeze_chance = right_freeze_chance,
			right_freeze_ticks = right_freeze_ticks
		}, true
	end)

	hui.traverse(current_builder_tab, function(element, key_path)
		element:depend({
			gui.antiaim.state.selector,
			condition_name
		}, key_path[1] ~= "override" and current_builder_tab.override or nil)
	end)
end

local function create_aa_snap_control(config_path, ui_element)
	ui_element:set_callback(function(callback_data)
		table.place(Anti_Aim.snap.custom, config_path, callback_data.value)
	end, true)

	return ui_element
end

local aa_snap_slider_labels = {
	delay = {
		[0] = "Off"
	},
	duration = {
		[13] = "Max"
	},
	pitch = {
		[0] = "Zero",
		[89] = "Down",
		[-89] = "Up"
	}
}

for i, condition_data in ipairs(AntiAimConditions.snaps) do
	local snap_id = condition_data[1]
	local snap_name = condition_data[2]

	gui.antiaim.snaps[snap_id], hui.macros.z = {}, "\nS" .. condition_data[3]

	local current_snap_tab = gui.antiaim.snaps[snap_id]
	local parent_group = ui_groups.angles
	local is_default_snap = snap_id == "default"

	current_snap_tab.on = create_aa_snap_control({
		snap_id,
		"on"
	}, parent_group:combobox("\f<z>", is_default_snap and {
		"Off",
		"Custom"
	} or {
		"Default",
		"Off",
		"Custom"
	}))
	current_snap_tab[#current_snap_tab + 1] = ui_helpers.space(parent_group)
	current_snap_tab.pitch = ui_helpers.feature(create_aa_snap_control({
		snap_id,
		"x",
		"on"
	}, parent_group:checkbox("\vPitch\f<z>")), function()
		local pitch_mode_combobox = create_aa_snap_control({
			snap_id,
			"x",
			"mode"
		}, parent_group:combobox("\f<p>Mode\f<z>x", {
			"Static",
			"Jitter",
			"Random",
			"Random Static",
			"Spin",
			"180v"
		}))

		return {
			mode = pitch_mode_combobox,
			ang = create_aa_snap_control({
				snap_id,
				"x",
				"ang"
			}, parent_group:slider("\f<p>Angle\f<z>x", -89, 89, -89, true, "°", 1, aa_snap_slider_labels.pitch)):depend({
				pitch_mode_combobox,
				"Static",
				"Jitter",
				"Random",
				"Random Static",
				"Spin",
				"180v"
			}),
			ang2 = create_aa_snap_control({
				snap_id,
				"x",
				"ang2"
			}, parent_group:slider("\f<p>Angle 2\f<z>x", -89, 89, -89, true, "°", 1, aa_snap_slider_labels.pitch)):depend({
				pitch_mode_combobox,
				"Jitter",
				"Random",
				"Random Static",
				"Spin",
				"180v"
			}),
			speed = create_aa_snap_control({
				snap_id,
				"x",
				"speed"
			}, parent_group:slider("\f<p>Speed\f<z>x", -50, 50, 20, true, "", 0.1)):depend({
				pitch_mode_combobox,
				"Spin",
				"180v"
			})
		}, true
	end)
	current_snap_tab[#current_snap_tab + 1] = ui_helpers.space(parent_group)
	current_snap_tab.yaw = ui_helpers.feature(create_aa_snap_control({
		snap_id,
		"y",
		"on"
	}, parent_group:checkbox("\vYaw\f<z>")), function()
		local yaw_mode_combobox = create_aa_snap_control({
			snap_id,
			"y",
			"mode"
		}, parent_group:combobox("\f<p>Mode\f<z>y", {
			"Static",
			"Jitter",
			"Random",
			"Random Jitter",
			"Random Static",
			"Spin",
			"Spin Jitter",
			"90w",
			"180v",
			"Opposite"
		}))

		return {
			mode = yaw_mode_combobox,
			ang = create_aa_snap_control({
				snap_id,
				"y",
				"ang"
			}, parent_group:slider("\f<p>Angle\f<z>y", 0, 360, 180, true, "°")):depend({
				yaw_mode_combobox,
				"Static",
				"Jitter",
				"Random",
				"Random Jitter",
				"Random Static",
				"Spin",
				"Spin Jitter",
				"90w",
				"180v"
			}),
			delay = create_aa_snap_control({
				snap_id,
				"y",
				"delay"
			}, parent_group:slider("\f<p>Delay\f<z>y", 0, 14, 0, true, "t", 1, aa_snap_slider_labels.delay)):depend({
				yaw_mode_combobox,
				"Jitter",
				"Spin Jitter"
			}),
			speed = create_aa_snap_control({
				snap_id,
				"y",
				"speed"
			}, parent_group:slider("\f<p>Speed\f<z>y", -50, 50, 20, true, "", 0.1)):depend({
				yaw_mode_combobox,
				"Spin",
				"Spin Jitter",
				"90w",
				"180v"
			})
		}, true
	end)
	current_snap_tab[#current_snap_tab + 1] = ui_helpers.space(parent_group)
	current_snap_tab[#current_snap_tab + 1] = parent_group:label("\vMisc")
	current_snap_tab.time = create_aa_snap_control({
		snap_id,
		"time"
	}, parent_group:slider("Duration\f<z>", 1, 13, 13, true, "t", 1, aa_snap_slider_labels.duration))
	current_snap_tab.sd = create_aa_snap_control({
		snap_id,
		"sd"
	}, parent_group:checkbox("Control desync side\f<z>"))

	hui.traverse(current_snap_tab, function(element, key_path)
		element:depend({
			gui.antiaim.def.setup.selector,
			snap_name
		}, {
			gui.antiaim.def.snap.on,
			true
		}, key_path[1] ~= "on" and {
			current_snap_tab.on,
			"Custom"
		} or nil)
	end)
end

hui.traverse(gui.antiaim.def.setup, function(element, key_path)
	element:depend({
		gui.antiaim.def.snap.on,
		true
	})
end)

hui.macros.z = nil

hui.traverse(reference.aa, function(element)
	element:set_visible(false)
end)
reference.aa.angles.yaw[2]:depend({
	reference.aa.angles.yaw[1],
	1
})
reference.aa.angles.pitch[2]:depend({
	reference.aa.angles.pitch[1],
	1
})
reference.aa.angles.jitter[1]:depend({
	reference.aa.angles.yaw[1],
	1
})
reference.aa.angles.jitter[2]:depend({
	reference.aa.angles.jitter[1],
	1
})
reference.aa.angles.body[2]:depend({
	reference.aa.angles.body[1],
	1
})
reference.aa.angles.fs_body:depend({
	reference.aa.angles.body[1],
	1
})

for key, element in next, reference.aa.other do
	if key ~= "legs" then
		element:depend({
			Gglobal.selector,
			"Settings"
		})

		if element.hotkey then
			element.hotkey:depend({
				Gglobal.selector,
				"Settings"
			})
		end
	end
end

eventManager.shutdown:set(function()
	hui.traverse(reference.aa, function(element)
		element:set_visible(true)
	end)
end)

hui.traverse(Gglobal.home, function(element)
	if element ~= Gglobal.home.config.list_report then
		element:depend({
			Gglobal.selector,
			"Home"
		})
	end
end)

local tab_visibility_map = {
	"Features",
	"Visual"
}

for key, element in next, Gglobal.settings do
	element:depend({
		Gglobal.selector,
		"Settings"
	})
end

hui.traverse({
	gui.misc,
	gui.visuals
}, function(element, key_path)
	element:depend({
		Gglobal.selector,
		"Settings"
	}, {
		Gglobal.settings.tab,
		tab_visibility_map[key_path[1]]
	})
end)

hui.traverse(gui.rage, function(element)
	element:depend({
		Gglobal.selector,
		"Ragebot"
	})
end)

tab_visibility_map = {
	def = "Defensive",
	general = "General",
	state = "Builder",
	snaps = "Defensive",
	builder = "Builder",
	ab = "Anti-bruteforce"
}

hui.traverse(gui.antiaim, function(element, key_path)
	local target_tab_name = tab_visibility_map[key_path[1]]

	element:depend({
		Gglobal.selector,
		"Anti-aim"
	}, key_path[1] ~= "on" and {
		gui.antiaim.on,
		true
	} or nil, target_tab_name and {
		gui.antiaim.tab,
		target_tab_name
	})
end)

tab_visibility_map = nil

gui.antiaim.ab.warning:depend({
	gui.antiaim.general.mode,
	"gamesense"
})

gui.antiaim.ab.triggers:depend({
	gui.antiaim.ab.on,
	1
}, {
	gui.antiaim.general.mode,
	"pasteria"
})

gui.antiaim.ab.power:depend({
	gui.antiaim.ab.on,
	1
}, {
	gui.antiaim.general.mode,
	"pasteria"
})

gui.antiaim.ab.timer:depend({
	gui.antiaim.ab.on,
	1
}, {
	gui.antiaim.general.mode,
	"pasteria"
})

gui.antiaim.ab.split:depend({
	gui.antiaim.ab.on,
	1
}, {
	gui.antiaim.general.mode,
	"pasteria"
})

gui.antiaim.ab.avoid_same:depend({
	gui.antiaim.ab.on,
	1
}, {
	gui.antiaim.general.mode,
	"pasteria"
})

gui.antiaim.ab.cycle:depend({
	gui.antiaim.ab.on,
	1
}, {
	gui.antiaim.general.mode,
	"pasteria"
})

gui.antiaim.ab.on:set_callback(function(slider_self)
	if is_loading_config then return end
	if slider_self.value == 1 and gui.antiaim.general.mode:get() ~= "pasteria" then
		slider_self:set(0)
		client.log("Requires Pasteria AA operator!")
	end
end, true)

gui.antiaim.ab.timer:set_callback(function(slider_self)
	if ab_state.active then
		ab_state.active = false
		ab_state.timer_end = nil
		ab_state.yaw_shift_left = 0
		ab_state.yaw_shift_right = 0
		ab_state.desync_shift_left = 0
		ab_state.desync_shift_right = 0
		client.log("[ab] Reset on timer change")
	end
end)

gui.antiaim.general.mode:set_callback(function(mode_self)
	if is_loading_config then return end
	if mode_self.value ~= "pasteria" and gui.antiaim.ab.on:get() == 1 then
		gui.antiaim.ab.on:set(0)
	end
end, true)

gui.visuals.accent:set_callback(function(color_picker)
	local r, g, b = unpack(color_picker.value)
	local new_accent_color = ColorUtils.rgb(r, g, b, 255)

	eventManager.accent_recolor:fire(new_accent_color, palette.hexs, palette.hex)

	palette.accent = new_accent_color
	palette.hexs = string.format("\a%02X%02X%02X", r, g, b)
	palette.hex = palette.hexs .. "FF"
end, true)
gui.visuals.dpi:set_callback(function(checkbox_element)
	render_module.dpi_t.scalable = checkbox_element.value

	render_module.dpi_t.callback()
end, true)

local anim_data = {
	target_chars = {},
	current_display = {},
	active_index = 1,
	current_pos = 0,
	last_update = 0,
	hold_until = 0,
	state = "animating"
}

local color2 = {}

local function init_anim()
	anim_data.target_chars = {}
	for char in string.gmatch("Pasteria — " .. config.build, ".[\x80-\xBF]*") do
		anim_data.target_chars[#anim_data.target_chars + 1] = char
	end
	
	for i = 1, #anim_data.target_chars do
		if not color2[i] then
			color2[i] = {
				n = 0,
				d = false,
				p = { 0 }
			}
		end
	end

	anim_data.current_display = {}
	for i = 1, #anim_data.target_chars do
		local c = anim_data.target_chars[i]
		if c == " " then
			anim_data.current_display[i] = " "
		else
			anim_data.current_display[i] = "-"
		end
	end
	anim_data.active_index = 1
	while anim_data.active_index <= #anim_data.target_chars and anim_data.target_chars[anim_data.active_index] == " " do
		anim_data.active_index = anim_data.active_index + 1
	end
	anim_data.current_pos = #anim_data.target_chars
	anim_data.state = "animating"
end

local is_menu_painting = false

eventManager.paint_ui:set(function()
	if not hui.menu_open then
		if is_menu_painting then
			collectgarbage()

			is_menu_painting = false
		end

		return
	end

	is_menu_painting = true

	if globals.frametime() % 2 == 0 then
		return
	end

	local time = globals.realtime()

	if #anim_data.target_chars == 0 then
		init_anim()
	end

	if time >= anim_data.last_update then
		anim_data.last_update = time + 0.05

		if anim_data.state == "holding" then
			if time >= anim_data.hold_until then
				init_anim()
			end
		elseif anim_data.state == "animating" then
			for i = anim_data.active_index, #anim_data.target_chars do
				if anim_data.target_chars[i] == " " then
					anim_data.current_display[i] = " "
				else
					anim_data.current_display[i] = "-"
				end
			end

			if anim_data.active_index <= #anim_data.target_chars then
				local moving_char = anim_data.target_chars[anim_data.active_index]
				anim_data.current_display[anim_data.current_pos] = moving_char

				if anim_data.current_pos == anim_data.active_index then
					anim_data.active_index = anim_data.active_index + 1
					while anim_data.active_index <= #anim_data.target_chars and anim_data.target_chars[anim_data.active_index] == " " do
						anim_data.active_index = anim_data.active_index + 1
					end

					if anim_data.active_index > #anim_data.target_chars then
						anim_data.state = "holding"
						anim_data.hold_until = time + 4.0
					else
						anim_data.current_pos = #anim_data.target_chars
					end
				else
					anim_data.current_pos = anim_data.current_pos - 1
					if anim_data.current_pos > anim_data.active_index and anim_data.target_chars[anim_data.current_pos] == " " then
						anim_data.current_pos = anim_data.current_pos - 1
					end
				end
			end
		end
	end

	local color = {}
	local accent = ColorUtils(unpack(reference.misc.settings.accent.value))
	local gray = ColorUtils.rgb(205, 205, 205, 80)

	for i = 1, #anim_data.target_chars do
		local char_to_show = anim_data.current_display[i] or "-"

		if i < 9 then
			local char_animation_data = color2[i]
			if time >= char_animation_data.n then
				char_animation_data.d = not char_animation_data.d
				char_animation_data.n = time + client.random_float(1, 3)
			end

			local animation_progress = animation_module.condition(char_animation_data.p, char_animation_data.d, -1)
			local interpolated_color = gray:lerp(accent, math.min(animation_progress + 0.5, 1))

			color[#color + 1] = string.format("\a%02x%02x%02x%02x%s", interpolated_color.r, interpolated_color.g, interpolated_color.b, 200 * animation_progress + 55, char_to_show)
		else
			color[#color + 1] = string.format("\aCDCDCDFF%s", char_to_show)
		end
	end

	Gglobal.title:set(table.concat(color))
end)

local HomeConfig = Gglobal.home.config
local HomeInfo = Gglobal.home.info

local was_in_game_last_frame

eventManager.paint_ui:set(function()
   	HomeInfo.loaded:set(hui.format("Loaded: \v")      .. storage.stats.loaded)
 	HomeInfo.evaded:set(hui.format("Evaded: \v")      .. storage.stats.evaded)
 	HomeInfo.killed:set(hui.format("Killed: \v")      .. storage.stats.killed)
	HomeInfo.missed:set(hui.format("Missed: \v")      .. storage.stats.missed)
 	HomeInfo.shots:set(hui.format("Shots: \v")        .. storage.stats.shots)

	autoSave()

	local is_in_game_now = globals.mapname() ~= nil

	if was_in_game_last_frame and not is_in_game_now then
		LocalPawn.self, LocalPawn.valid = nil, false
		LocalPawn.in_game = false

		eventManager.local_disconnect:fire()

		was_in_game_last_frame = false
	end

	was_in_game_last_frame = is_in_game_now
end)

local function StatisticUpd(arg) -- 1 - evaded, 2 - killed, 3 - shots, 4 - missed
	if arg == 1 then
		val_storage_evaded = storage.stats.evaded
		storage.stats.evaded = ( val_storage_evaded + 1 )
	elseif arg == 2 then
		val_storage_killed = storage.stats.killed
		storage.stats.killed = ( val_storage_killed + 1 )
	elseif arg == 3 then
		val_storage_shots = storage.stats.shots
		storage.stats.shots = ( val_storage_shots + 1 )
	elseif arg == 4 then
		val_storage_missed = storage.stats.missed
		storage.stats.missed = ( val_storage_missed + 1 )
	end
end

local config_manager_state

config_manager_state = {
	default = "pasteria::KG15IHByZXNldClbYWRtaW5de4WkZHJhZ4ioc3BlY2xpc3SCoXnNE4iheM0LZKZhcnJvd3OCoXnNE2KheM0Sfqljcm9zc2hhaXKCoXnNFLCheM0TC6hzbG93ZG93boKhec0NvqF4zRJPp2tleWxpc3SCoXnNE4iheM0LZKZkYW1hZ2WCoXnNE62heM0TnKl3YXRlcm1hcmuDoXnMuaF4zSa2oWECpGxvZ3OCoXnNHBGheM0Qeqd2aXN1YWxzjKNkcGnCpWNoZWFww6Zhc3BlY3SCpXJhdGlvzIWib27Cpm1hcmtlcsOoc3BlY2xpc3TCpmFycm93c8Ona2V5bGlzdMKoc2xvd2Rvd27DpmFjY2VudKkjNzRBNkE5RkamZGFtYWdlw6V3YXRlcoOkaGlkZcKkbmFtZaCib27DqWNyb3NzaGFpcoOkbG9nb8Olc3R5bGWnQ2xhc3NpY6JvbsOkbWlzY4WmZmlsdGVyw6ZsYWRkZXLCp2NsYW50YWfCp2JyZWFrZXKEpHNsaWHCpXBpdGNowqJvbsKkbGVnc6ROb25lpGxvZ3ODpmV2ZW50c5WtUmFnZWJvdCBzaG90c69IYXJtaW5nIGVuZW1pZXOuR2V0dGluZyBoYXJtZWStQW50aS1haW0gaW5mb6Fz113Zpm91dHB1dJOnQ29uc29sZaZTY3JlZW6hfqJvbsOnYW50aWFpbYWnYnVpbGRlcomlc25lYWuGo2Rlc4ShcjyhasKhbDyib27Co21vZIOjZGVnAKR3YXlzA6JvbqNPZmajb2ZmAKVkZWxheQGjYWRkg6FyAKFsAKJvbsKob3ZlcnJpZGXCp2Zha2VsYWeGo2Rlc4ShcjyhasKhbDyib27Co21vZIOjZGVnAKR3YXlzA6JvbqNPZmajb2ZmAKVkZWxheQGjYWRkg6FyAKFsAKJvbsKob3ZlcnJpZGXCpHdhbGuGo2Rlc4Shch6hasOhbB6ib27Do21vZIOjZGVnDqR3YXlzA6JvbqZSYW5kb22jb2ZmAKVkZWxheQijYWRkg6FyGaFs5KJvbsOob3ZlcnJpZGXDo2FpcoajZGVzhKFyHqFqw6FsHqJvbsOjbW9kg6NkZWcdpHdheXMDom9upkppdHRlcqNvZmYHpWRlbGF5AqNhZGSDoXIAoWwAom9uwqhvdmVycmlkZcOkYWlyY4ajZGVzhKFyPKFqw6FsPKJvbsOjbW9kg6NkZWchpHdheXMDom9upkppdHRlcqNvZmYHpWRlbGF5AaNhZGSDoXIooWznom9uwqhvdmVycmlkZcOlc3RhbmSGo2Rlc4ShcjyhasOhbDyib27Do21vZIOjZGVnAKR3YXlzA6JvbqNPZmajb2ZmAKVkZWxheQGjYWRkg6FyAKFsAKJvbsKob3ZlcnJpZGXDpmNyb3VjaIajZGVzhKFyPKFqw6FsPKJvbsKjbW9kg6NkZWcApHdheXMDom9uo09mZqNvZmYApWRlbGF5AaNhZGSDoXIAoWwAom9uwqhvdmVycmlkZcKjcnVuhqNkZXOEoXI8oWrDoWw8om9uw6Ntb2SDo2RlZyGkd2F5cwOib26mSml0dGVyo29mZgalZGVsYXkBo2FkZIOhcgChbACib27CqG92ZXJyaWRlw6dkZWZhdWx0haNkZXOEoXIeoWrDoWweom9uw6Ntb2SDo2RlZx2kd2F5cwOib26mSml0dGVyo29mZgelZGVsYXkCo2FkZIOhcgChbACib27CpXNuYXBzhqRwZWVrhaVwaXRjaIWkYW5nMtCno2FuZ9Cnom9uwqRtb2RlplN0YXRpY6VzcGVlZBSkdGltZQ2ic2TCom9upkN1c3RvbaN5YXeFpWRlbGF5AKNhbmfMtKJvbsKkbW9kZaM5MHelc3BlZWQUo2FpcoWlcGl0Y2iFpGFuZzIAo2FuZ9Cnom9uw6Rtb2RlrVJhbmRvbSBTdGF0aWOlc3BlZWQUpHRpbWUNonNkwqJvbqZDdXN0b22jeWF3haVkZWxheQCjYW5nzPCib27DpG1vZGWtUmFuZG9tIFN0YXRpY6VzcGVlZAqkYWlyY4WlcGl0Y2iFpGFuZzIto2FuZwCib27DpG1vZGWmU3RhdGljpXNwZWVkFKR0aW1lDaJzZMKib26mQ3VzdG9to3lhd4WlZGVsYXkAo2FuZ80BaKJvbsOkbW9kZaRTcGlupXNwZWVkCqZjcm91Y2iFpXBpdGNohaRhbmcy0KejYW5n0Keib27DpG1vZGWmU3RhdGljpXNwZWVkFKR0aW1lDaJzZMOib26mQ3VzdG9to3lhd4WlZGVsYXkAo2FuZ8y0om9uw6Rtb2RlplN0YXRpY6VzcGVlZBSlc25lYWuFpXBpdGNohaRhbmcy0KejYW5n0Keib27CpG1vZGWmU3RhdGljpXNwZWVkFKR0aW1lDaJzZMKib26nRGVmYXVsdKN5YXeFpWRlbGF5AKNhbmfMtKJvbsKkbW9kZaZTdGF0aWOlc3BlZWQUp2RlZmF1bHSFpXBpdGNohaRhbmcy0KejYW5n0Keib27CpG1vZGWmU3RhdGljpXNwZWVkFKR0aW1lDaJzZMKib26mQ3VzdG9to3lhd4WlZGVsYXkAo2FuZ8y0om9uwqRtb2RlplN0YXRpY6VzcGVlZBSnZ2VuZXJhbIqjdXNlw6ZpbnZlcnSTAQChfqJmbIOlbGltaXQOpG1vZGWnRHluYW1pY6JvbsOkaGVhZIGib27Dpm1hbnVhbIWlcmlnaHSTAQChfqRsZWZ0kwEAoX6lcmVzZXSTAQChfqJvbsKmc3RhdGljwqRlZGdlkwEAoX6lam1vdmXDomZzg6Rvbl9okwEAoX6ib27CpnN0YXRpY8Kkc3RhYsOoaW1wbGljaXTCom9uw6NkZWaCpHNuYXCDom9zwqRvbl9okwAAoX6ib27DqHRyaWdnZXJzlKdKdW1waW5nqUNyb3VjaGluZ61XZWFwb24gY2hhbmdloX6kcmFnZYWocmVjaGFyZ2XDqGV4c3dpdGNogqVhbGxvd5GhfqJvbsKodGVsZXBvcnSEpG9uX2iTAQChfqZwaXN0b2zCom9uwqRsYW5kwqdwZWVrZml4wqhyZXNvbHZlcsJ9",
	name = "",
	selected = 0,
	badge = hui.format("\v•\r "),
	list = {},
	loaded = storage.last_loaded_config or "Default"
}

HomeConfig.save:depend(true, {
	HomeConfig.list,
	0,
	true
})
HomeConfig.export:depend(true, {
	HomeConfig.list,
	0,
	true
})
HomeConfig.delete:depend({
	HomeConfig.list,
	0,
	true
})
HomeConfig.deleteb:depend({
	HomeConfig.list,
	0
})
HomeConfig.deleteb:depend(true, {
	HomeConfig.list,
	0,
	true
})

local config_api = {
	eval = function(config_string, load_only_meta)
		if not config_string then
			return "\fConfig not found."
		end

		local encoded_part, padding_chars = string.match(config_string, "^pasteria::([%w%+%/]+)(_*)")

		local padding_equals

		padding_equals = padding_chars and string.rep("=", #padding_chars) or ""

		local fixed_base64_string = string.gsub(encoded_part, "z%d%d%dZ", {
			z113Z = "+",
			z143Z = "/"
		})
		local decoded_string = base64.decode(fixed_base64_string .. padding_equals)
		local config_name, author, packed_settings = string.match(decoded_string, "^%((.*)%)%[(.*)%]%{(.+)%}")

		return config_name, author, load_only_meta ~= true and packed_settings ~= nil and msgpack.unpack(packed_settings) or {}
	end
}

function config_api.save(config_name, keep_author)
	if config_name == "Default" then
		return "\fCan't overwrite Default"
	end

	config_name = tostring(config_name)

	local author

	if keep_author == true then
		local old_config_name

		old_config_name, author = config_api.eval(databaseManager.configs[config_name], true)
	end

	local current_settings = config_manager_state.system:save()
	local full_config_string = string.format("(%s)[%s]{%s}", config_name, author or config.user, msgpack.pack(current_settings))
	local encoded_config = string.gsub(base64.encode(full_config_string), "[%+%/%=]", {
		["="] = "_",
		["/"] = "z143Z",
		["+"] = "z113Z"
	})
	local final_config_string = string.format("pasteria::%s", encoded_config)

	databaseManager.configs[config_name] = final_config_string

	return "\a" .. config_name .. " saved"
end

function config_api.create(config_name)
	if config_name == "" then
		return "\fEnter the name"
	elseif config_name == "Default" then
		return "\fCan't overwrite Default"
	elseif #config_name > 24 then
		return "\fThis name is too long"
	elseif databaseManager.configs[config_name] then
		return "\f" .. config_name .. " is in the list"
	end

	return config_api.save(config_name, true)
end

function config_api.delete(config_name)
	databaseManager.configs[config_name] = nil

	if storage.last_loaded_config == config_name then
		storage.last_loaded_config = nil
		autoSave()
	end
end

function config_api.export(config_name)
	if not config_name or config_name == "" then
		return "\fNot selected"
	end

	Clipboard.set(databaseManager.configs[config_name])

	return "\aCopied to clipboard."
end

function config_api.import()
	local clipboard_content = Clipboard.get()

	if not clipboard_content then
		return "\fEmpty clipboard"
	end

	local config_name, author, settings = config_api.eval(clipboard_content, true)

	if not author then
		return config_name
	end

	local full_config_string = clipboard_content:match("^pasteria::[%w%+%/]+_*")

	if config_name == "Default" then
		return "\fCan't import default config"
	end

	databaseManager.configs[config_name] = full_config_string

	return "\a" .. config_name .. " by " .. author .. " added"
end

function config_api.load(config_name, ...)
	if not config_name or config_name == "" then
		return "ERR: can't load: not selected"
	end

	local config_string_to_load = config_name == "Default" and config_manager_state.default or databaseManager.configs[config_name]
	local name, author, settings = config_api.eval(config_string_to_load)

	if not author or not settings then
		return name
	end

	if ({
		...
	})[1] == "antiaim" then
		settings.antiaim.general.manual = nil
		settings.antiaim.general.edge = nil
		if settings and settings.antiaim and settings.antiaim.general and type(settings.antiaim.general.fs) == "table" then
			settings.antiaim.general.fs.on_h = nil
		end
	end

	if settings and settings.antiaim and settings.antiaim.builder then
		for condition_id, condition_settings in pairs(settings.antiaim.builder) do
			if type(condition_settings) == "table" and type(condition_settings.delay) ~= "table" then
				condition_settings.delay = nil
			end
		end
	end

	if settings and settings.antiaim and settings.antiaim.general then
		if settings.antiaim.general.fs ~= nil and type(settings.antiaim.general.fs) ~= "table" then
			settings.antiaim.general.fs = {
				on = not not settings.antiaim.general.fs,
				static = false
			}
		end
	end

	is_loading_config = true
	config_manager_state.system:load(settings, ...)
	is_loading_config = false

	if gui.antiaim.ab.on:get() == 1 and gui.antiaim.general.mode:get() ~= "pasteria" then
		gui.antiaim.ab.on:set(0)
	end

	if ... then
		return
	end

	config_manager_state.loaded = config_name
	storage.last_loaded_config = config_name
	autoSave()
end

local report_hide_timestamp = 0
local is_report_timer_active = false

local function hide_report_on_timer()
	if report_hide_timestamp < globals.realtime() then
		HomeConfig.list_report:set_visible(false)
		HomeConfig.selected:set_visible(true)
		eventManager.paint_ui:unset(hide_report_on_timer)

		is_report_timer_active = false
	end
end

local function show_report_message(message_text)
	if not message_text then
		return
	end

	report_hide_timestamp = globals.realtime() + 1

	local colored_message = message_text:gsub("[\f\a]", {
		["\f"] = "\aFF4040FF",
		["\a"] = "\aB6DE47FF"
	})

	HomeConfig.list_report:set(colored_message)

	if not is_report_timer_active then
		HomeConfig.list_report:set_visible(true)
		HomeConfig.selected:set_visible(false)
		eventManager.paint_ui:set(hide_report_on_timer)

		is_report_timer_active = true
	end
end

local function update_config_list_ui(is_selection_only)
	if is_selection_only ~= true then
		config_manager_state.list = {}

		for config_name in next, databaseManager.configs do
			config_manager_state.list[#config_manager_state.list + 1] = config_name
		end

		table.sort(config_manager_state.list)
		table.insert(config_manager_state.list, 1, "Default")

		local loaded_config_index = table.find(config_manager_state.list, config_manager_state.loaded)

		if loaded_config_index then
			config_manager_state.list[loaded_config_index] = config_manager_state.badge .. config_manager_state.list[loaded_config_index]
		else
			config_manager_state.loaded = 0
		end

		HomeConfig.list:update(config_manager_state.list)
	end

	config_manager_state.selected = HomeConfig.list.value + 1
	config_manager_state.name = string.gsub(config_manager_state.list[config_manager_state.selected] or "", "^\a%x%x%x%x%x%x%x%x•\a%x%x%x%x%x%x%x%x ", "")

	HomeConfig.selected:set(hui.format("Selected: \v") .. config_manager_state.name)
	HomeConfig.list:set(config_manager_state.selected - 1)
end

local function execute_config_action(action_name, ...)
	local success, result1, result2, result3 = pcall(config_api[action_name], ...)

	debugLog(action_name, ": ", success, ", ", result1, ", ", result2, ", ", result3)
	show_report_message(result2 or result1)
	update_config_list_ui()
end

update_config_list_ui()
HomeConfig.list:set_callback(function()
	update_config_list_ui(true)
end)
HomeConfig.create:set_callback(function()
	execute_config_action("create", HomeConfig.name:get())
end)
HomeConfig.import:set_callback(function()
	execute_config_action("import", HomeConfig.name:get())
end)
HomeConfig.load:set_callback(function()
	execute_config_action("load", config_manager_state.name)
end)
HomeConfig.loadaa:set_callback(function()
	execute_config_action("load", config_manager_state.name, "antiaim")
end)
HomeConfig.save:set_callback(function()
	execute_config_action("save", config_manager_state.name)
end)
HomeConfig.delete:set_callback(function()
	execute_config_action("delete", config_manager_state.name)
end)
HomeConfig.export:set_callback(function()
	execute_config_action("export", config_manager_state.name)
end)

HomeConfig.list_report:set_visible(false)

Gglobal.selector:set_callback(function()
	HomeConfig.list_report:set_visible(false)
	is_report_timer_active = false
	eventManager.paint_ui:unset(hide_report_on_timer)
end)

local AntiAim

local cmd
active_aa_settings = {}
aa_state = {
	counter = 0,
	send_packet = false,
	sent = 0,
	state = 1,
	switch = false
}
final_angles = {
	yaw = 0,
	pitch = 89,
	mod = 0,
	des = 0
}
frame_flags = {}
local aa_references = {
	pitch = reference.aa.angles.pitch[2],
	base = reference.aa.angles.base,
	yaw = reference.aa.angles.yaw[2],
	body = reference.aa.angles.body[2],
	pitch_mode = reference.aa.angles.pitch[1],
	yaw_mode = reference.aa.angles.yaw[1],
	jitter_mode = reference.aa.angles.jitter[1],
	jitter = reference.aa.angles.jitter[2],
	body_mode = reference.aa.angles.body[1]
}

local function get_player_movement_state()
	if not LocalPawn.jumping then
		if LocalPawn.duck_amount > 0 then
			return LocalPawn.velocity > 5 and ScriptData.states.sneak or ScriptData.states.crouch
		end

		if LocalPawn.velocity > 5 then
			return cmd.in_speed == 1 and ScriptData.states.walk or ScriptData.states.run
		end

		return ScriptData.states.stand
	else
		return LocalPawn.duck_amount > 0 and ScriptData.states.airc or ScriptData.states.air
	end
end

local function select_aa_profile()
	local aa_builder_profile
	local profile_index = 0
	local current_movement_state = aa_state.state

	if profile_index == 0 then
		aa_builder_profile = Anti_Aim.builder.custom
	else
		aa_builder_profile = Anti_Aim.builder[profile_index]
	end

	local is_edge_yaw_active = gui.antiaim.general.edge:get()
	local is_freestanding_active = not is_edge_yaw_active and not aa_state.manual_yaw and ui.is_active(gui.antiaim.general.fs.on)

	if aa_builder_profile.fakelag.override and LocalPawn.exploit.active == ScriptData.exploit.OFF then
		current_movement_state = ScriptData.states.fakelag
	elseif not aa_builder_profile.airc.override and current_movement_state == ScriptData.states.airc then
		current_movement_state = ScriptData.states.air
	elseif not aa_builder_profile.sneak.override and current_movement_state == ScriptData.states.sneak then
		current_movement_state = ScriptData.states.crouch
	end

	current_movement_state = aa_builder_profile[AntiAimConditions.states[current_movement_state][1]].override and current_movement_state or ScriptData.states.default
	active_aa_settings = {
		[0] = aa_builder_profile,
		cur = aa_builder_profile[AntiAimConditions.states[current_movement_state][1]]
	}
	aa_state.state = current_movement_state
end

local function select_defensive_snap_profile()
	active_aa_settings.snap = nil

	if not ui.is_active(gui.antiaim.def.snap.on) then
		return
	end

	if LocalPawn.exploit.active == ScriptData.exploit.OS and not gui.antiaim.def.snap.os.value then
		return
	end

	local snap_builder_profile
	local profile_index = 0
	local current_snap_condition = ScriptData.snaps.default

	if profile_index == 0 then
		snap_builder_profile = Anti_Aim.snap.custom
	else
		snap_builder_profile = Anti_Aim.snap[profile_index]
	end

	if snap_builder_profile.airc.on ~= "Default" and LocalPawn.jumping and LocalPawn.crouching then
		current_snap_condition = ScriptData.snaps.airc
	elseif snap_builder_profile.air.on ~= "Default" and LocalPawn.jumping then
		current_snap_condition = ScriptData.snaps.air
	elseif snap_builder_profile.sneak.on ~= "Default" and LocalPawn.on_ground and LocalPawn.crouching and LocalPawn.velocity > 5 then
		current_snap_condition = ScriptData.snaps.sneak
	elseif snap_builder_profile.crouch.on ~= "Default" and LocalPawn.on_ground and LocalPawn.crouching then
		current_snap_condition = ScriptData.snaps.crouch
	elseif snap_builder_profile.peek.on ~= "Default" and LocalPawn.on_ground and LocalPawn.peeking then
		current_snap_condition = ScriptData.snaps.peek
	elseif snap_builder_profile.walk.on ~= "Default" and LocalPawn.on_ground and not LocalPawn.crouching and LocalPawn.walking then
		current_snap_condition = ScriptData.snaps.walk
	elseif snap_builder_profile.run.on ~= "Default" and LocalPawn.on_ground and not LocalPawn.crouching and LocalPawn.velocity > 5 then
		current_snap_condition = ScriptData.snaps.run
	elseif snap_builder_profile.stand.on ~= "Default" and LocalPawn.on_ground and not LocalPawn.crouching and LocalPawn.velocity <= 5 then
		current_snap_condition = ScriptData.snaps.stand
	end

	local selected_snap_settings = snap_builder_profile[AntiAimConditions.snaps[current_snap_condition][1]]

	if selected_snap_settings.on == "Off" then
		return
	end

	current_snap_condition = selected_snap_settings.on == "Custom" and current_snap_condition or ScriptData.snaps.default

	local final_snap_settings = snap_builder_profile[AntiAimConditions.snaps[current_snap_condition][1]]

	if final_snap_settings and final_snap_settings.on ~= "Off" then
		active_aa_settings.snap = final_snap_settings
	end
end

local last_shot_event_tick = 0
local last_hurt_event_tick = 0

eventManager.player_hurt:set(function(event_data)
	if client.userid_to_entindex(event_data.userid) == LocalPawn.self then
		last_hurt_event_tick = globals.tickcount()
	end
end)
eventManager.bullet_impact:set(function(event_data)
	if not LocalPawn.valid or last_shot_event_tick == globals.tickcount() then
		return
	end

	local attacker_index = client.userid_to_entindex(event_data.userid)

	if not attacker_index or not entity.is_enemy(attacker_index) or entity.is_dormant(attacker_index) then
		return
	end

	local impact_position = vector(event_data.x, event_data.y, event_data.z)
	local attacker_origin = vector(entity.get_origin(attacker_index))

	attacker_origin.z = attacker_origin.z + 64

	local teammate_distances = {}

	for i = 1, #teammates_list do
		local player_entity = teammates_list[i]
		local teammate_hitbox_pos = vector(entity.hitbox_position(player_entity, 0))
		local closest_point_on_ray = math.closest_ray_point(teammate_hitbox_pos, attacker_origin, impact_position)

		teammate_distances[player_entity == LocalPawn.self and 0 or #teammate_distances + 1] = teammate_hitbox_pos:dist(closest_point_on_ray)
	end

	if teammate_distances[0] and (#teammate_distances == 0 or teammate_distances[0] < math.min(unpack(teammate_distances))) and teammate_distances[0] < 80 then
		client.delay_call(totime(1), function()
			eventManager.enemy_shot:fire({
				damaged = last_shot_event_tick == last_hurt_event_tick,
				dist = teammate_distances[0],
				attacker = attacker_index,
				userid = event_data.userid
			})
		end)

		last_shot_event_tick = globals.tickcount()
	end
end)

local function update_aa_base_state()
	aa_state.resort = gui.antiaim.general.resort and gui.antiaim.general.resort.value
	aa_state.send_packet = cmd.chokedcommands == 0
	aa_state.state = get_player_movement_state()

	select_aa_profile()
	select_defensive_snap_profile()
end

local aa_logic_modules = {
	angles = {
		manual_buttons = {
			{
				"left",
				yaw = -90,
				item = gui.antiaim.general.manual.left
			},
			{
				"right",
				yaw = 90,
				item = gui.antiaim.general.manual.right
			},
			{
				"reset",
				item = gui.antiaim.general.manual.reset
			}
		},
		manual = function(self)
			if not gui.antiaim.general.manual.on.value then
				return
			end

			for i, button_config in ipairs(self.manual_buttons) do
				local is_active, press_type = button_config.item:get()

				if button_config.active == nil then
					button_config.active = is_active
				end

				if button_config.active == is_active then
					-- block empty
				else
					button_config.active = is_active

					if button_config.yaw == nil then
						self.manual_current = nil
					end

					if press_type == 1 then
						self.manual_current = is_active and i or nil
					elseif press_type == 2 then
						self.manual_current = self.manual_current ~= i and i or nil
					end
				end
			end

			local selected_yaw = self.manual_current ~= nil and self.manual_buttons[self.manual_current].yaw or nil

			return type(selected_yaw) == "number" and selected_yaw or nil
		end,
		work = function(self)
			local max_pitch = 88.94

			aa_state.camera_ang = {
				client.camera_angles()
			}

			local target_yaw = aa_state.camera_ang[2]
			local threat_origin = nil

			if LocalPawn.threat then
				threat_origin = vector(entity.get_origin(LocalPawn.threat))

				aa_state.threat_ang = {
					math.angle_to(LocalPawn.origin, threat_origin)
				}
				aa_state.threat_dist = math.sqrt3((LocalPawn.origin - threat_origin):unpack())
				target_yaw = aa_state.threat_ang[2]
			else
				aa_state.threat_ang, aa_state.threat_dist = nil
			end

			local final_base_yaw = target_yaw - 180
			local manual_yaw_override = self:manual()
			local is_edge_yaw_active = gui.antiaim.general.edge:get()
			local is_freestanding_active = not is_edge_yaw_active and not manual_yaw_override and ui.is_active(gui.antiaim.general.fs.on)

			safe_override(reference.aa.angles.freestand, is_freestanding_active)
			safe_override(reference.aa.angles.edge, is_edge_yaw_active)

			if manual_yaw_override then
				final_base_yaw = aa_state.camera_ang[2] - manual_yaw_override

				if gui.antiaim.general.manual.static.value then
					local static_desync_amount = 120

					frame_flags.no_modifier, frame_flags.force_desync = true, manual_yaw_override > 0 and -static_desync_amount or static_desync_amount
				end
			end

			if is_edge_yaw_active then
				frame_flags.force_implicit = true
			elseif is_freestanding_active then
				frame_flags.force_implicit = true

				if gui.antiaim.general.fs.static.value then
					frame_flags.no_modifier, frame_flags.force_desync = true, 120
				end
			end

			aa_state.manual_yaw, aa_state.edge_yaw, aa_state.freestanding = manual_yaw_override, is_edge_yaw_active, is_freestanding_active
			final_angles.yaw, final_angles.pitch = final_base_yaw, max_pitch
		end
	},
	modifier = {
		skitter_sequence = {
			-1,
			1,
			0,
			-1,
			1,
			0,
			-1,
			0,
			1,
			-1,
			0,
			1
		},
		Jitter = function(modifier_settings)
			return aa_state.switch and modifier_settings.deg or -modifier_settings.deg
		end,
		["Sway Jitter"] = function(modifier_settings, self)
			local deg = modifier_settings.deg or 0

			local desync_settings = active_aa_settings.cur.des
			local left_limit = 60
			local right_limit = 60
			if desync_settings and desync_settings.on then
				left_limit = desync_settings.l or 60
				right_limit = desync_settings.r or 60
			end

			if not self._sway_state then
				self._sway_state = {
					dir = 1,
					progress = 0
				}
			end

			local limit_ticks = 2
			local delay_on = false
			if active_aa_settings.cur.delay and type(active_aa_settings.cur.delay) == "table" then
				delay_on = active_aa_settings.cur.delay.on
			end

			if delay_on and target_delay_ticks > 1 then
				limit_ticks = target_delay_ticks
			end

			if aa_state.send_packet then
				self._sway_state.progress = self._sway_state.progress + (1 / limit_ticks)
				if self._sway_state.progress >= 1.0 then
					self._sway_state.progress = 0
					self._sway_state.dir = -self._sway_state.dir
				end
			end

			local yaw_val, desync_val
			local progress = math.min(1, math.max(0, self._sway_state.progress))

			if self._sway_state.dir == 1 then
				yaw_val = math.lerp(-deg, deg, progress)
				desync_val = math.lerp(-left_limit, right_limit, progress)
			else
				yaw_val = math.lerp(deg, -deg, progress)
				desync_val = math.lerp(right_limit, -left_limit, progress)
			end

			if desync_settings and desync_settings.on then
				frame_flags.force_desync = desync_val
			end

			return yaw_val
		end,
		Ways = function(modifier_settings)
			local progress = aa_state.counter % modifier_settings.ways / (modifier_settings.ways - 1)

			return math.lerp(-modifier_settings.deg, modifier_settings.deg, side == -1 and 1 - progress or progress)
		end,
		["Skitter Old"] = function(modifier_settings, self)
			local cycle_progress = aa_state.counter % (modifier_settings.ways * 2 - 2)

			if cycle_progress >= modifier_settings.ways then
				cycle_progress = modifier_settings.ways + 1 - cycle_progress
			end

			local lerp_progress = cycle_progress / (modifier_settings.ways - 1)
			local yaw_modifier = math.lerp(-modifier_settings.deg, modifier_settings.deg, cycle_progress < 0 and 1 + lerp_progress or lerp_progress)

			if active_aa_settings.cur.des.on then
				local desync_modifier = math.lerp(-active_aa_settings.cur.des.r, active_aa_settings.cur.des.l, side == -1 and 1 - lerp_progress or lerp_progress)

				frame_flags.force_desync = desync_modifier
			end

			return yaw_modifier
		end,
		Skitter = function(modifier_settings, self)
			local sequence_index = math.cycle(aa_state.counter, #self.skitter_sequence)
			local direction = self.skitter_sequence[sequence_index]
			local yaw_modifier = direction * modifier_settings.deg
			local desync_settings = active_aa_settings.cur.des

			if desync_settings.on and desync_settings.j then
				frame_flags.force_desync = direction > 0 and desync_settings.l or direction < 0 and -desync_settings.r or direction == 0 and 0
			end

			return yaw_modifier
		end,
		Rotate = function(modifier_settings)
			local t = (globals.curtime() * 4) % 2
			local progress = t <= 1 and t or (2 - t)
			return math.lerp(-modifier_settings.deg, modifier_settings.deg, progress)
		end,
		Random = function(modifier_settings)
			return client.random_int(-modifier_settings.deg, modifier_settings.deg)
		end,
		work = function(self)
			final_angles.mod = 0

			local modifier_settings = active_aa_settings.cur.mod

			if modifier_settings.type ~= "Off" then
				final_angles.mod = self[modifier_settings.type](modifier_settings, self)
			end

			if not frame_flags.no_offset then
				final_angles.mod = final_angles.mod + active_aa_settings.cur.off
			end

			if ab_state.active then
				local des_set = active_aa_settings.cur.des
				local is_right = false
				if frame_flags.fs_desync_side then
					is_right = frame_flags.fs_desync_side == 1
				elseif des_set.j then
					is_right = aa_state.switch
				else
					is_right = gui.antiaim.general.invert:get()
				end

				local shift = is_right and ab_state.yaw_shift_right or ab_state.yaw_shift_left
				if shift ~= 0 then
					final_angles.mod = final_angles.mod + shift
				end
			end
		end
	},
	desync = {
		work = function(self)
			final_angles.des = nil

			local desync_settings = active_aa_settings.cur.des

			if not desync_settings.on then
				return
			end

			local left_limit = desync_settings.l
			local right_limit = desync_settings.r

			if desync_settings.rand then
				local rand_mode = desync_settings.rand_mode or "default"
				local current_side = frame_flags.fs_desync_side and (frame_flags.fs_desync_side == 1 and "fs_r" or "fs_l") or (desync_settings.j and (aa_state.switch and "j_r" or "j_l") or (aa_state.switch and "r" or "l"))

				if self.last_desync_side ~= current_side or self.fluctuate_left == nil or self.fluctuate_right == nil then
					self.last_desync_side = current_side
					local min_left = desync_settings.l_fluctuate or 20
					local min_right = desync_settings.r_fluctuate or 20

					local next_left = client.random_int(math.min(math.floor(min_left), left_limit), left_limit)
					local next_right = client.random_int(math.min(math.floor(min_right), right_limit), right_limit)

					if rand_mode == "default" then
						local step = desync_settings.rand_step or 0
						if step == 0 then
							step = client.random_int(1, 15)
						elseif step == 16 then
							step = math.floor(math.sin(globals.tickcount() * 0.1) * 7.0 + 8.0)
						end

						if step > 0 and self.fluctuate_left and self.fluctuate_right then
							local attempts = 0
							while math.abs(next_left - self.fluctuate_left) < step and attempts < 10 do
								next_left = client.random_int(math.min(math.floor(min_left), left_limit), left_limit)
								attempts = attempts + 1
							end
							attempts = 0
							while math.abs(next_right - self.fluctuate_right) < step and attempts < 10 do
								next_right = client.random_int(math.min(math.floor(min_right), right_limit), right_limit)
								attempts = attempts + 1
							end
						end
					end

					self.fluctuate_left = next_left
					self.fluctuate_right = next_right
				end

				if rand_mode == "default" then
					left_limit = self.fluctuate_left or left_limit
					right_limit = self.fluctuate_right or right_limit
				elseif rand_mode == "fluctuate" then
					local current_phase = math.floor(globals.tickcount() / 12) % 2 == 0
					if not current_phase then
						left_limit = self.fluctuate_left or left_limit
						right_limit = self.fluctuate_right or right_limit
					end
				end
			end

			if frame_flags.fs_desync_side then
				final_angles.des = desync_settings.on and (frame_flags.fs_desync_side == 1 and right_limit or -left_limit) or nil
			elseif desync_settings.j then
				final_angles.des = desync_settings.on and (aa_state.switch and right_limit or -left_limit) or nil
			else
				final_angles.des = desync_settings.on and (gui.antiaim.general.invert:get() and right_limit or -left_limit) or nil
			end

			if ab_state.active and final_angles.des then
				local is_right = final_angles.des > 0
				local shift = is_right and ab_state.desync_shift_right or ab_state.desync_shift_left
				if shift ~= 0 then
					final_angles.des = math.abs(shift) * 58 * (is_right and 1 or -1)
				end
			end
		end
	},
	yaw_rand = {
		work = function(self)
			local misc_settings = active_aa_settings.cur.misc

			if not misc_settings or not misc_settings.on then
				return
			end

			local offset = 0

			local sync_mode = misc_settings.sync_mode or "single"
			local independent = misc_settings.independent_cycles == true

			local run_single = independent or (not independent and sync_mode == "single")
			local run_synced = independent or (not independent and sync_mode == "synced")

			if run_single then
				local rand_mode = misc_settings.mode or "default"
				local range = misc_settings.range or 25
				local speed = misc_settings.speed or 10

				if speed == 0 then
					if not self.rand_speed or globals.tickcount() >= (self.next_speed_change or 0) then
						self.rand_speed = client.random_int(8, 30)
						self.next_speed_change = globals.tickcount() + client.random_int(4, 12)
					end
					speed = self.rand_speed
				end

				local offset_single = 0
				if rand_mode == "default" then
					local tick_interval = math.max(1, speed)
					if not self.rand_tick or globals.tickcount() >= self.rand_tick then
						self.rand_val = client.random_int(-range, range)
						self.rand_tick = globals.tickcount() + tick_interval
					end
					offset_single = self.rand_val or 0
				elseif rand_mode == "flick" then
					local base_interval = math.max(1, speed)
					if not self.flick_tick or globals.tickcount() > self.flick_tick then
						self.flick_val = client.random_int(-range, range)
						self.flick_tick = globals.tickcount() + client.random_int(base_interval, base_interval * 2)
						self.flick_duration = globals.tickcount() + 1
					end
					offset_single = (globals.tickcount() < (self.flick_duration or 0)) and self.flick_val or 0
				elseif rand_mode == "sway" then
					local base_interval = math.max(1, speed)
					if not self.sway_tick or globals.tickcount() > self.sway_tick then
						self.sway_start = self.sway_current or 0
						self.sway_target = client.random_int(-range, range)
						self.sway_start_tick = globals.tickcount()
						self.sway_duration = client.random_int(base_interval * 2, base_interval * 4)
						self.sway_hold = client.random_int(base_interval, base_interval * 3)
						self.sway_tick = self.sway_start_tick + self.sway_duration + self.sway_hold
					end

					local elapsed = globals.tickcount() - self.sway_start_tick
					if elapsed < self.sway_duration then
						local t = elapsed / self.sway_duration
						t = t * t * (3 - 2 * t)
						self.sway_current = math.lerp(self.sway_start, self.sway_target, t)
					else
						self.sway_current = self.sway_target
					end

					offset_single = self.sway_current or 0
				end

				offset = offset + offset_single
			end

			if run_synced then
				local state = self
				local mode_s, range_s, speed_s

				if not aa_state.switch then
					if not self.left_state then self.left_state = {} end
					state = self.left_state
					mode_s = misc_settings.mode_l or "default"
					range_s = misc_settings.range_l or 25
					speed_s = misc_settings.speed_l or 10
				else
					if not self.right_state then self.right_state = {} end
					state = self.right_state
					mode_s = misc_settings.mode_r or "default"
					range_s = misc_settings.range_r or 25
					speed_s = misc_settings.speed_r or 10
				end

				if speed_s == 0 then
					if not state.rand_speed or globals.tickcount() >= (state.next_speed_change or 0) then
						state.rand_speed = client.random_int(8, 30)
						state.next_speed_change = globals.tickcount() + client.random_int(4, 12)
					end
					speed_s = state.rand_speed
				end

				local offset_side = 0
				if mode_s == "default" then
					local tick_interval = math.max(1, speed_s)
					if not state.rand_tick or globals.tickcount() >= state.rand_tick then
						state.rand_val = client.random_int(-range_s, range_s)
						state.rand_tick = globals.tickcount() + tick_interval
					end
					offset_side = state.rand_val or 0
				elseif mode_s == "flick" then
					local base_interval = math.max(1, speed_s)
					if not state.flick_tick or globals.tickcount() > state.flick_tick then
						state.flick_val = client.random_int(-range_s, range_s)
						state.flick_tick = globals.tickcount() + client.random_int(base_interval, base_interval * 2)
						state.flick_duration = globals.tickcount() + 1
					end
					offset_side = (globals.tickcount() < (state.flick_duration or 0)) and state.flick_val or 0
				elseif mode_s == "sway" then
					local base_interval = math.max(1, speed_s)
					if not state.sway_tick or globals.tickcount() > state.sway_tick then
						state.sway_start = state.sway_current or 0
						state.sway_target = client.random_int(-range_s, range_s)
						state.sway_start_tick = globals.tickcount()
						state.sway_duration = client.random_int(base_interval * 2, base_interval * 4)
						state.sway_hold = client.random_int(base_interval, base_interval * 3)
						state.sway_tick = state.sway_start_tick + state.sway_duration + state.sway_hold
					end

					local elapsed = globals.tickcount() - state.sway_start_tick
					if elapsed < state.sway_duration then
						local t = elapsed / state.sway_duration
						t = t * t * (3 - 2 * t)
						state.sway_current = math.lerp(state.sway_start, state.sway_target, t)
					else
						state.sway_current = state.sway_target
					end

					offset_side = state.sway_current or 0
				end

				offset = offset + offset_side
			end

			final_angles.mod = final_angles.mod + offset
		end
	},
	defensive = {
		urgent = false,
		ticks = 0,
		prev_des = 0,
		counter = 0,
		pitch = {
			["Static"] = function(self, settings)
				return settings.ang
			end,
			["Jitter"] = function(self, settings)
				return aa_state.switch and settings.ang or settings.ang2
			end,
			["Random"] = function(self, settings)
				return client.random_int(settings.ang, settings.ang2)
			end,
			["Random Static"] = function(self, settings)
				if not self.once.srx then
					self.once.srx = client.random_int(settings.ang, settings.ang2)
				end

				return self.once.srx
			end,
			["Spin"] = function(self, settings)
				return math.lerp(settings.ang, settings.ang2, globals.curtime() * settings.speed * 0.1 % 1)
			end,
			["180v"] = function(self, settings)
				local oscillation = math.sin(globals.curtime() * (settings.speed * 0.2)) * 0.5 + 0.5
				return math.lerp(settings.ang, settings.ang2, oscillation)
			end
		},
		yaw = {
			["Static"] = function(self, settings)
				return 360 - settings.ang
			end,
			["Jitter"] = function(self, settings)
				return 180 + settings.ang * (self.once.switch and 0.5 or -0.5)
			end,
			["Random"] = function(self, settings)
				return 180 + client.random_int(settings.ang * -0.5, settings.ang * 0.5)
			end,
			["Random Jitter"] = function(self, settings)
				local direction_multiplier = math.random(0, 1) == 0 and 1 or -1
				local random_offset = math.random(settings.ang * -0.25, settings.ang * 0.25)

				return direction_multiplier * 90 + random_offset
			end,
			["Random Static"] = function(self, settings)
				if not self.once.sry then
					self.once.sry = math.random(settings.ang * -0.5, settings.ang * 0.5)
				end

				return 180 + self.once.sry
			end,
			["Spin"] = function(self, settings)
				return 180 + math.lerp(settings.ang * -0.5, settings.ang * 0.5, globals.curtime() * (settings.speed * 0.1) % 1), true
			end,
			["Spin Jitter"] = function(self, settings)
				local direction = self.once.switch and 1 or -1
				local spin_angle = math.lerp(settings.ang * -0.5, settings.ang * 0.5, globals.curtime() * (settings.speed * 0.1) % 1)

				return direction * 90 + spin_angle
			end,
			["90w"] = function(self, settings)
				local direction = self.counter % 2 == 0 and 1 or -1
				local wobble_angle = math.lerp(settings.ang * -0.5, settings.ang * 0.5, LocalPawn.exploit.lc_left / active_aa_settings.snap.time * settings.speed * 0.05 % 1)

				return direction * 90 + wobble_angle, true
			end,
			["180v"] = function(self, settings)
				local oscillation = math.sin(globals.curtime() * (settings.speed * 0.2)) * 0.5 + 0.5

				return 180 + math.lerp(settings.ang * -0.5, settings.ang * 0.5, oscillation), true
			end,
			["Opposite"] = function(self, settings)
				return 180 - final_angles.mod
			end
		},
		once = {},
		lby_tracker = {
			last_update_time = 0, 
			last_standing_time = 0, 
			was_moving = false,     
			update_interval = 1.1,  
		},
		predict_lby_update = function(self)
			local tracker = self.lby_tracker
			local curtime = globals.curtime()
			local is_moving = LocalPawn.velocity > 0.1

			if is_moving then
				tracker.was_moving = true
				tracker.last_standing_time = curtime
				return math.huge
			end

			if tracker.was_moving then
				tracker.was_moving = false
				tracker.last_standing_time = curtime
				tracker.last_update_time = curtime
			end

			local elapsed = curtime - tracker.last_update_time
			local time_to_next = tracker.update_interval - elapsed

			if time_to_next <= 0 then
				tracker.last_update_time = curtime
				return 0
			end

			return time_to_next
		end,
		get_adaptive_choke_depth = function(self)
			local lc_left = LocalPawn.exploit.lc_left or 0
			local latency = client.latency() or 0
			local latency_ticks = math.floor(latency / globals.tickinterval() + 0.5)

			local min_reserve = 2

			if latency_ticks > 3 then
				min_reserve = min_reserve + 1
			end

			if LocalPawn.exploit.defensive_active then
				min_reserve = min_reserve + 1
			end

			return min_reserve
		end,
		snap = function(self)
			local snap_settings = active_aa_settings.snap

			local min_reserve = self:get_adaptive_choke_depth()

			local can_snap_now = snap_settings ~= nil
				and LocalPawn.exploit.active
				and (LocalPawn.exploit.lc_left > ((frame_flags.force_implicit and 1 or 0) + min_reserve - 2) or LocalPawn.exploit.defensive_active)
				and not aa_state.use_aa
				and not aa_state.manual_yaw

			if self.might_cross and not aa_state.send_packet and not LocalPawn.exploit.active and not LocalPawn.exploit.defensive_active and LocalPawn.exploit.lc_left > 0 then
				frame_flags.force_send, frame_flags.no_modifier, frame_flags.no_offset = true, true, true
				self.might_cross = false
			end

			if can_snap_now then
				self.ticks = self.ticks + 1
				can_snap_now = snap_settings.time >= self.ticks
			else
				self.ticks = 0
			end

			aa_state.will_break_lc = LocalPawn.exploit.active and (LocalPawn.exploit.active == ScriptData.exploit.OS or cmd.force_defensive)

			if can_snap_now then
				local time_to_lby = self:predict_lby_update()
				local tick_interval = globals.tickinterval()
				local lby_imminent = time_to_lby <= tick_interval * 2

				if (snap_settings.x.on or snap_settings.y.on) and (not aa_state.snapping or LocalPawn.exploit.lc_left <= min_reserve or not LocalPawn.exploit.defensive_active) then
					frame_flags.force_send = true
				end

				aa_state.snapping, final_angles.snap = true, {}
				self.once.apex = self.once.apex or LocalPawn.exploit.lc_left

				if aa_state.send_packet then
					self.once.switch = not self.once.switch

					if lby_imminent then
						self.once.lby_override = true
					else
						self.once.lby_override = false
					end
				else
					self.once.switch = true
				end

				if snap_settings.x.on then
					local pitch_result = self.pitch[snap_settings.x.mode](self, snap_settings.x)

					if pitch_result then
						final_angles.snap[1] = pitch_result
						self.might_cross = true
					end
				end

				if snap_settings.y.on then
					local yaw_result, force_send_flag = self.yaw[snap_settings.y.mode](self, snap_settings.y)

					if yaw_result then
						if self.once.lby_override then
							final_angles.snap[2] = final_angles.yaw + yaw_result
							if snap_settings.sd then
								final_angles.des = yaw_result < 180 and 60 or -60
								self.prev_des = final_angles.des
							end
						elseif self.once.switch then

							final_angles.snap[2] = final_angles.yaw + yaw_result

							if snap_settings.sd then
								final_angles.des = yaw_result < 180 and 60 or -60
								self.prev_des = final_angles.des
							end
						else
							final_angles.snap[2] = final_angles.yaw
						end

						self.might_cross = true
					end

					if force_send_flag then
						frame_flags.force_send = true
					end
				end
			elseif aa_state.snapping then
				local time_to_lby = self:predict_lby_update()
				local tick_interval = globals.tickinterval()
				local lby_safe = time_to_lby > tick_interval * 3

				if not aa_state.send_packet then
					frame_flags.force_send = true
				elseif not lby_safe then
					frame_flags.force_send = true
					frame_flags.no_modifier = true
				else
					self.counter = self.counter + 1
					aa_state.snapping = false
					final_angles.snap = nil

					table.clear(self.once)

					self.might_cross = false
				end
			end
		end,
		lc = function(self)
			local lc_break_triggers = gui.antiaim.def.triggers

			return cmd.weaponselect ~= 0 and lc_break_triggers:get("Weapon change") or not LocalPawn.on_ground and lc_break_triggers:get("Jumping") or LocalPawn.crouching and LocalPawn.on_ground and lc_break_triggers:get("Crouching")
		end,
		get_tickbase_phase = function(self)
			local lc_left = LocalPawn.exploit.lc_left or 0
			local snap_time = active_aa_settings.snap and active_aa_settings.snap.time or 14
			if lc_left > snap_time * 0.7 then
				return "choke"
			elseif lc_left > 2 then
				return "send"  
			else
				return "flush"  
			end
		end,
		check_simtime_rewind = function(self)
			local sim_time = entity.get_prop(LocalPawn.self, "m_flSimulationTime")
			if not sim_time then return false end

			local tick_interval = globals.tickinterval()
			local current_sim_tick = math.floor(sim_time / tick_interval + 0.5)

			if not self.last_sim_tick then
				self.last_sim_tick = current_sim_tick
				return false
			end

			local delta = current_sim_tick - self.last_sim_tick
			self.last_sim_tick = current_sim_tick

			return delta < 0 or delta > 16
		end,
		work = function(self)
			if self:lc() then
				cmd.force_defensive = true
			end

			local phase = self:get_tickbase_phase()
			local simtime_rewound = self:check_simtime_rewind()

			if simtime_rewound and aa_state.snapping then
				frame_flags.force_send = false
				frame_flags.no_modifier = true
				frame_flags.no_offset = true
			end

			if phase == "flush" and aa_state.snapping and not LocalPawn.exploit.defensive_active then
				frame_flags.force_send = true
			end

			self:snap()
		end
	},
		head = {
			smart = function()
				local threat_weapon = entity.get_player_weapon(LocalPawn.threat)
				local threat_weapon_t = threat_weapon and csweapon(threat_weapon)

				if threat_weapon_t then
					local potential_damage = threat_weapon_t.damage * 1.25
					local estimated_damage = math.ceil(threat_weapon_t.armor_ratio * 0.5 * potential_damage)
					local local_health = entity.get_prop(LocalPawn.self, "m_iHealth")

					if local_health and estimated_damage >= local_health and local_health <= 92 then
						return
					end
				end

				local head_position_x, head_position_y, head_position_z = entity.hitbox_position(LocalPawn.self, 0)
				local threat_origin_x, threat_origin_y, threat_origin_z = entity.get_origin(LocalPawn.threat)
				
				if not head_position_z or not threat_origin_z then
					return
				end
				
				local threat_dist = aa_state.threat_dist or 0
				if threat_dist == 0 then
					return
				end
				
				local vertical_ratio = (head_position_z - (threat_origin_z + 68)) / threat_dist
				local safe_zone_min = 0
				local safe_zone_max = 0.75
				
				if LocalPawn.on_ground and not LocalPawn.crouching then
					safe_zone_min, safe_zone_max = 0.25, 0.5
				elseif LocalPawn.on_ground and LocalPawn.crouching then
					safe_zone_min, safe_zone_max = -0.05, 0.3
				elseif aa_state.state == ScriptData.states.air then
					safe_zone_min, safe_zone_max = 0.35, 0.75
				elseif aa_state.state == ScriptData.states.airc then
					local is_knife_out = LocalPawn.weapon_t and (LocalPawn.weapon_t.type == "knife" or LocalPawn.weapon_t.weapon_type_int == 0)
					local is_zeus_out = LocalPawn.weapon_t and (LocalPawn.weapon_t.type == "taser" or LocalPawn.weapon_t.name == "Zeus x27" or entity.get_prop(LocalPawn.weapon, "m_iItemDefinitionIndex") == 31)
					if is_knife_out or is_zeus_out then
						safe_zone_min, safe_zone_max = -0.05, 0.55
					else
						safe_zone_min, safe_zone_max = 0.25, 0.75
					end
				end
				
				if vertical_ratio < safe_zone_min or safe_zone_max < vertical_ratio then
					return
				end
				
				aa_state.safe_head = true
				frame_flags.no_modifier, frame_flags.no_offset, frame_flags.force_desync = true, true, 0
			end,
			basic = function()
				local _x, _y, threat_origin_z_basic = entity.get_origin(LocalPawn.threat)
				if not threat_origin_z_basic then
					return
				end
				
				local vertical_difference = LocalPawn.origin.z - threat_origin_z_basic
				local is_knife_out = LocalPawn.weapon_t and (LocalPawn.weapon_t.type == "knife" or LocalPawn.weapon_t.weapon_type_int == 0)
				local is_zeus_out = LocalPawn.weapon_t and (LocalPawn.weapon_t.type == "taser" or LocalPawn.weapon_t.name == "Zeus x27" or entity.get_prop(LocalPawn.weapon, "m_iItemDefinitionIndex") == 31)
				
				local is_crouching = LocalPawn.crouching or (LocalPawn.duck_amount and LocalPawn.duck_amount > 0.5)
				local is_above_enemy = vertical_difference > 0
				local is_allowed = is_crouching or (not LocalPawn.jumping and is_above_enemy)
				
				if is_allowed and (is_knife_out or is_zeus_out) and vertical_difference > -32 then
					aa_state.safe_head = true
					frame_flags.no_modifier, frame_flags.no_offset, frame_flags.force_desync = true, true, 0
				end
			end,
			work = function(self)
				aa_state.safe_head = false
				
				if not gui.antiaim.general.head.on.value or not LocalPawn.threat or aa_state.manual_yaw or aa_state.use_aa then
					return
				end

				local is_knife = LocalPawn.weapon_t and (LocalPawn.weapon_t.type == "knife" or LocalPawn.weapon_t.weapon_type_int == 0)
				local is_zeus = LocalPawn.weapon_t and (LocalPawn.weapon_t.type == "taser" or LocalPawn.weapon_t.name == "Zeus x27" or entity.get_prop(LocalPawn.weapon, "m_iItemDefinitionIndex") == 31)

				if is_knife or is_zeus then
					local _, _, threat_origin_z = entity.get_origin(LocalPawn.threat)
					if threat_origin_z then
						local is_crouching = LocalPawn.crouching or (LocalPawn.duck_amount and LocalPawn.duck_amount > 0.5)
						local is_above_enemy = LocalPawn.origin.z > threat_origin_z
						local is_allowed = is_crouching or (not LocalPawn.jumping and is_above_enemy)
						if not is_allowed then
							return
						end
					end
				end
				
				if gui.antiaim.general.head.smart and gui.antiaim.general.head.smart.value then
					self.smart()
				else
					self.basic()
				end
			end
		},
	stab = {
		work = function(self)
			local was_backstabbed_last_tick = aa_state.backstab

			aa_state.backstab = false

			if gui.antiaim.general.stab.value and LocalPawn.threat then
				local threat_distance = aa_state.threat_dist
				local threat_weapon = csweapon(entity.get_player_weapon(LocalPawn.threat))

				if threat_distance < 280 and threat_weapon and threat_weapon.type == "knife" then
					if not was_backstabbed_last_tick then
						cmd.no_choke = true
						frame_flags.force_send = true
					end

					final_angles.yaw = final_angles.yaw + 180
					frame_flags.no_snap = true
					aa_state.backstab = true
				end
			end
		end
	},
	fl = {
		overridden = false,
		work = function(self)
			local fakelag_refs = reference.aa.fakelag
			local fakelag_gui_settings = gui.antiaim.general.fl
			local is_fakeduck = safe_get(reference.rage.other.duck)

			if fakelag_gui_settings.on.value and not is_fakeduck then
				safe_override(fakelag_refs.enable, true)
				
				local target_limit = feature_modules.exswitch.ovr and 1 or fakelag_gui_settings.limit.value
				local fl_mode = fakelag_gui_settings.mode.value
				if fl_mode == "Random" then
					safe_override(fakelag_refs.amount, "Maximum")
					local fl_min = math.max(2, target_limit - 5)
					local fl_max = math.max(2, target_limit)
					safe_override(fakelag_refs.limit, client.random_int(fl_min, fl_max))
				else
					safe_override(fakelag_refs.amount, fl_mode)
					safe_override(fakelag_refs.limit, target_limit)
				end
				
				safe_override(fakelag_refs.variance, fakelag_gui_settings.variance.value)

				self.overridden = true
			elseif self.overridden then
				safe_override(fakelag_refs.enable)
				safe_override(fakelag_refs.amount)
				safe_override(fakelag_refs.limit)
				safe_override(fakelag_refs.variance)

				self.overridden = false
			end
		end
	},
	legs = {
		work = function(self)
			if gui.antiaim.general.legs.value == "Pseudo-walk" then
				local sent_packet_remainder = aa_state.sent % 3
				local leg_movement_mode = "Off"

				if sent_packet_remainder == 2 then
					leg_movement_mode = "Always slide"
				elseif sent_packet_remainder == 3 then
					leg_movement_mode = "Never slide"
				end

				safe_override(reference.aa.other.legs, leg_movement_mode)
			else
				safe_override(reference.aa.other.legs, gui.antiaim.general.legs.value)
			end
		end
	},
	use_aa = {
		wait = false,
		check = function()
			local team_number = entity.get_prop(LocalPawn.self, "m_iTeamNum")
			local is_defusing = entity.get_prop(LocalPawn.self, "m_bIsDefusing") == 1
			local is_grabbing_hostage = entity.get_prop(LocalPawn.self, "m_bIsGrabbingHostage") == 1

			if is_defusing or is_grabbing_hostage then
				return false
			end

			if team_number == 3 and cmd.pitch > 15 then
				local c4_entity_list = entity.get_all("CC4")

				for c4_iterator = 1, #c4_entity_list do
					local c4_origin_x, c4_origin_y, c4_origin_z = entity.get_origin(c4_entity_list[c4_iterator])

					if math.sqrt3(LocalPawn.origin.x - c4_origin_x, LocalPawn.origin.y - c4_origin_y, LocalPawn.origin.z - c4_origin_z) then
						return false
					end
				end
			end

			return true
		end,
		work = function(self)
			aa_state.use_aa = false

			if not gui.antiaim.general.use.value then
				return
			end

			if LocalPawn.using then
				aa_state.use_aa = true
				frame_flags.force_implicit = false

				if self.wait == false then
					cmd.no_choke = true
					frame_flags.force_send = true
					frame_flags.no_antiaim = true
					self.wait = true
				elseif self.wait == true then
					if self.check() then
						final_angles.pitch, final_angles.yaw = aa_state.camera_ang[1], aa_state.camera_ang[2]
					else
						frame_flags.no_antiaim = true
					end
				end
			elseif self.wait then
				cmd.no_choke = true
				frame_flags.force_send = true
				frame_flags.no_offset, frame_flags.no_modifier = true, true
				self.wait = false
			end
		end
	}
}
local aa_logic_pipeline = {
	work = function()
		aa_logic_modules.angles:work()
		aa_logic_modules.modifier:work()
		aa_logic_modules.yaw_rand:work()
		aa_logic_modules.desync:work()
		aa_logic_modules.defensive:work()
		aa_logic_modules.head:work()
		aa_logic_modules.stab:work()
		aa_logic_modules.use_aa:work()
		aa_logic_modules.fl:work()

		if frame_flags.no_snap then
			final_angles.snap = nil
		end

		if frame_flags.no_modifier then
			final_angles.mod = 0
		end

		if frame_flags.force_desync ~= nil then
			final_angles.des = frame_flags.force_desync or nil
		end

		if not frame_flags.no_offset and active_aa_settings.cur.add.on and final_angles.des and final_angles.des ~= 0 then
			final_angles.mod = final_angles.mod + (final_angles.des > 0 and active_aa_settings.cur.add.r or active_aa_settings.cur.add.l)
		end
	end
}
local aa_output_modules = {
	direct = {
		yaw = 0,
		pitch = 0,
		previous_body = 0,
		allowed = function()
			if frame_flags.no_antiaim or LocalPawn.throwing_nade or cmd.in_attack == 1 and LocalPawn.can_shoot or LocalPawn.using and not gui.antiaim.general.use.value or LocalPawn.movetype == 9 and (cmd.sidemove ~= 0 or cmd.forwardmove ~= 0) or entity.get_prop(LocalPawn.gamerules, "m_bFreezePeriod") == 1 then
				return false
			end

			return true
		end,
		micromove = function()
			if not LocalPawn.on_ground or LocalPawn.movetype == 9 then
				return
			end

			if reference.misc.ghelper and LocalPawn.weapon_t and LocalPawn.weapon_t.weapon_type_int == 9 and ui.is_active(reference.misc.ghelper) then
				return
			end

			local is_move_key_pressed = cmd.in_forward == 1 or cmd.in_back == 1 or cmd.in_moveleft == 1 or cmd.in_moveright == 1
			local micromove_speed = LocalPawn.duck_amount > 0 and LocalPawn.on_ground and 3.3 or 1.1

			if not is_move_key_pressed and LocalPawn.velocity < 20 and not cmd.quick_stop then
				cmd.sidemove = cmd.command_number % 2 == 0 and micromove_speed or -micromove_speed
			end
		end,
		jitter_move = function()
			if LocalPawn.jumping or LocalPawn.walking then
				return
			end

			local base_speed_percentage = 90
			local tick_interval_multiplier = 0.1875
			local adjusted_speed_percentage = cmd.command_number % 64 * tick_interval_multiplier + base_speed_percentage

			if adjusted_speed_percentage <= 100 then
				base_speed_percentage = adjusted_speed_percentage >= 90 and adjusted_speed_percentage or 100
			end

			local speed_limit = base_speed_percentage * 0.01 * 320

			if speed_limit <= 0 then
				return
			end

			local current_move_speed = math.sqrt3(cmd.forwardmove, cmd.sidemove)

			if current_move_speed < 10 or current_move_speed < speed_limit then
				return
			end

			cmd.forwardmove = cmd.forwardmove / current_move_speed * speed_limit
			cmd.sidemove = cmd.sidemove / current_move_speed * speed_limit
		end,
		compensate = {
			previous = 0,
			ready = false,
			feet = function(self, current_feet_yaw, previous_feet_yaw)
				local compensated_yaw = current_feet_yaw
				local is_compensated = false

				if math.abs(current_feet_yaw) - math.abs(previous_feet_yaw) > 5 then
					local max_desync_angle = entity.get_max_desync(LocalPawn.animstate)
				end

				return compensated_yaw, is_compensated
			end
		},
		work = function(self)
			self.micromove()

			if not self.allowed() then
				return
			end

			if gui.antiaim.general.jmove.value then
				self.jitter_move()
			end

			self.pitch = final_angles.snap and final_angles.snap[1] or final_angles.pitch

			if aa_state.send_packet or frame_flags.force_send or frame_flags.speeding or final_angles.snap then
				self.yaw = final_angles.snap and final_angles.snap[2] or final_angles.yaw + final_angles.mod
			end

			if not frame_flags.hybrid then
				safe_override(reference.aa.angles.enable, true)
				safe_override(aa_references.pitch_mode, "Custom")
				safe_override(aa_references.pitch, math.normalize_pitch(self.pitch))

				if aa_state.send_packet or frame_flags.force_send or frame_flags.speeding or final_angles.snap then
					safe_override(aa_references.yaw_mode, "Static")
					safe_override(aa_references.yaw, math.normalize_yaw(self.yaw))
					safe_override(aa_references.jitter_mode, "Off")
					safe_override(aa_references.body_mode, final_angles.des ~= nil and "Static" or "Off")

					if final_angles.des then
						safe_override(aa_references.body, final_angles.des)
					end
				end
			end

			cmd.pitch = math.normalize_pitch(self.pitch)
			cmd.yaw = math.normalize_yaw(self.yaw)

			if aa_state.send_packet and final_angles.des then
				local final_desync_amount = math.clamp(final_angles.des, -60, 60)
				local desync_multiplier = LocalPawn.on_ground and 2 or 1

				if frame_flags.speeding then
					desync_multiplier = 1
				end

				cmd.yaw = cmd.yaw - final_desync_amount * desync_multiplier
				cmd.allow_send_packet = false
			end
		end
	},
	implicit = {
		work = function(self)
			local final_pitch = math.normalize_pitch(final_angles.snap and final_angles.snap[1] or final_angles.pitch)
			local final_yaw = math.normalize_yaw(final_angles.snap and final_angles.snap[2] or final_angles.yaw + final_angles.mod)

			safe_override(reference.aa.angles.enable, true)
			safe_override(aa_references.pitch_mode, "Custom")
			safe_override(aa_references.pitch, final_pitch)

			if aa_state.send_packet or frame_flags.force_send or final_angles.snap then
				safe_override(aa_references.yaw_mode, "Static")
				safe_override(aa_references.yaw, final_yaw)
				safe_override(aa_references.jitter_mode, "Off")
				safe_override(aa_references.body_mode, final_angles.des ~= nil and "Static" or "Off")

				if final_angles.des then
					safe_override(aa_references.body, final_angles.des > 0 and 1 or final_angles.des < 0 and -1 or 0)
				end
			end
		end
	}
}
local fluctuate_states = {
	single_delay = { value = nil, remaining = 0 },
	left_delay = { value = nil, remaining = 0 },
	right_delay = { value = nil, remaining = 0 },

	single_freeze = { value = nil, remaining = 0 },
	left_freeze = { value = nil, remaining = 0 },
	right_freeze = { value = nil, remaining = 0 }
}
delay_counter = 0
target_delay_ticks = 1
local single_increment_counter = 0
local left_increment_counter = 0
local right_increment_counter = 0
local last_defensive_active = false
local last_delay_state = nil
local enemy_sim_history = {}

local function handle_aa_delay(delay_settings)
	local current_state = aa_state.state
	if current_state ~= last_delay_state then
		last_delay_state = current_state
		for k, v in pairs(fluctuate_states) do
			v.val1 = nil
			v.val2 = nil
			v.phase = nil
			v.remaining = 0
		end
		delay_counter = 0
		target_delay_ticks = 1
	end

	if not LocalPawn.exploit.defensive_active then
		last_defensive_active = false
	end

	local enabled = false
	if type(delay_settings) == "table" then
		enabled = delay_settings.on
	end

	if not enabled then
		local original_delay = 1
		if type(delay_settings) == "number" then
			original_delay = delay_settings
		end
		if original_delay <= delay_counter or LocalPawn.exploit.active == ScriptData.exploit.OFF then
			if aa_state.send_packet then
				aa_state.counter = aa_state.counter >= 65535 and 0 or aa_state.counter + 1
				aa_state.switch = aa_state.counter % 2 == 0
				delay_counter = 0
			end
		else
			delay_counter = delay_counter + 1
		end
		return
	end

	if not aa_state.send_packet then
		return
	end

	local trigger_defensive = false
	if LocalPawn.exploit.defensive_active and not last_defensive_active then
		trigger_defensive = true
	end

	if target_delay_ticks <= delay_counter or trigger_defensive then
		if aa_state.send_packet then
			if trigger_defensive then
				last_defensive_active = true
			end
			aa_state.counter = aa_state.counter >= 65535 and 0 or aa_state.counter + 1
			aa_state.switch = aa_state.counter % 2 == 0
			delay_counter = 0

			local type_val = string.lower(delay_settings.type or "single")
			if type_val == "single" then
				local mode = string.lower(delay_settings.single_mode or "static")
				local value = delay_settings.single_value or 0
				if mode == "fluctuate" then
					local state = fluctuate_states.single_delay
					if state.val2 == nil or state.remaining <= 0 then
						state.val2 = client.random_int(0, 16)
						state.phase = true
						state.remaining = 2
					end
					local final_val = state.phase and value or state.val2
					target_delay_ticks = final_val <= 0 and 1 or final_val
					state.phase = not state.phase
					state.remaining = state.remaining - 1
				elseif value <= 0 then
					target_delay_ticks = 1
				elseif mode == "static" then
					target_delay_ticks = value
				elseif mode == "random" then
					target_delay_ticks = client.random_int(1, value)
				elseif mode == "break" then
					target_delay_ticks = (client.random_int(1, 100) > 50) and client.random_int(1, value) or 1
				elseif mode == "increment" then
					local max_val = math.max(1, value)
					target_delay_ticks = (single_increment_counter % max_val) + 1
					single_increment_counter = (single_increment_counter + 1) % max_val
				end

				local freeze_on = delay_settings.single_freeze_on
				local freeze_chance = delay_settings.single_freeze_chance or 0
				if freeze_on and (freeze_chance == 0 or (freeze_chance > 0 and client.random_int(1, 100) <= freeze_chance)) then
					local raw_ticks = delay_settings.single_freeze_ticks or 0
					local freeze_add = 0
					if raw_ticks == 0 then
						freeze_add = client.random_int(1, 16)
					elseif raw_ticks == 17 then
						local state = fluctuate_states.single_freeze
						if state.val1 == nil or state.remaining <= 0 then
							state.val1 = client.random_int(0, 16)
							state.val2 = client.random_int(0, 16)
							state.phase = true
							state.remaining = 2
						end
						freeze_add = state.phase and state.val1 or state.val2
						state.phase = not state.phase
						state.remaining = state.remaining - 1
					else
						freeze_add = raw_ticks
					end

					if freeze_chance == 0 then
						local r1 = client.random_int(0, freeze_add)
						local r2 = client.random_int(0, freeze_add)
						local dispersion_offset = math.floor((r1 + r2) / 2 + 0.5)
						target_delay_ticks = target_delay_ticks + dispersion_offset
					else
						target_delay_ticks = target_delay_ticks + freeze_add
					end
				end
			else -- synced
				if not aa_state.switch then -- Left side
					local left_mode = string.lower(delay_settings.left_mode or "static")
					local left_value = delay_settings.left_value or 0
					if left_mode == "fluctuate" then
						local state = fluctuate_states.left_delay
						if state.val2 == nil or state.remaining <= 0 then
							state.val2 = client.random_int(0, 16)
							state.phase = true
							state.remaining = 2
						end
						local final_val = state.phase and left_value or state.val2
						target_delay_ticks = final_val <= 0 and 1 or final_val
						state.phase = not state.phase
						state.remaining = state.remaining - 1
					elseif left_value <= 0 then
						target_delay_ticks = 1
					elseif left_mode == "static" then
						target_delay_ticks = left_value
					elseif left_mode == "random" then
						target_delay_ticks = client.random_int(1, left_value)
					elseif left_mode == "break" then
						target_delay_ticks = (client.random_int(1, 100) > 50) and client.random_int(1, left_value) or 1
					elseif left_mode == "increment" then
						local max_val = math.max(1, left_value)
						target_delay_ticks = (left_increment_counter % max_val) + 1
						left_increment_counter = (left_increment_counter + 1) % max_val
					end

					local left_freeze_on = delay_settings.left_freeze_on
					local left_freeze_chance = delay_settings.left_freeze_chance or 0
					if left_freeze_on and (left_freeze_chance == 0 or (left_freeze_chance > 0 and client.random_int(1, 100) <= left_freeze_chance)) then
						local raw_ticks = delay_settings.left_freeze_ticks or 0
						local freeze_add = 0
						if raw_ticks == 0 then
							freeze_add = client.random_int(1, 16)
						elseif raw_ticks == 17 then
							local state = fluctuate_states.left_freeze
							if state.val1 == nil or state.remaining <= 0 then
								state.val1 = client.random_int(0, 16)
								state.val2 = client.random_int(0, 16)
								state.phase = true
								state.remaining = 2
							end
							freeze_add = state.phase and state.val1 or state.val2
							state.phase = not state.phase
							state.remaining = state.remaining - 1
						else
							freeze_add = raw_ticks
						end

						if left_freeze_chance == 0 then
							local r1 = client.random_int(0, freeze_add)
							local r2 = client.random_int(0, freeze_add)
							local dispersion_offset = math.floor((r1 + r2) / 2 + 0.5)
							target_delay_ticks = target_delay_ticks + dispersion_offset
						else
							target_delay_ticks = target_delay_ticks + freeze_add
						end
					end
				else -- Right side
					local right_mode = string.lower(delay_settings.right_mode or "static")
					local right_value = delay_settings.right_value or 0
					if right_mode == "fluctuate" then
						local state = fluctuate_states.right_delay
						if state.val2 == nil or state.remaining <= 0 then
							state.val2 = client.random_int(0, 16)
							state.phase = true
							state.remaining = 2
						end
						local final_val = state.phase and right_value or state.val2
						target_delay_ticks = final_val <= 0 and 1 or final_val
						state.phase = not state.phase
						state.remaining = state.remaining - 1
					elseif right_value <= 0 then
						target_delay_ticks = 1
					elseif right_mode == "static" then
						target_delay_ticks = right_value
					elseif right_mode == "random" then
						target_delay_ticks = client.random_int(1, right_value)
					elseif right_mode == "break" then
						target_delay_ticks = (client.random_int(1, 100) > 50) and client.random_int(1, right_value) or 1
					elseif right_mode == "increment" then
						local max_val = math.max(1, right_value)
						target_delay_ticks = (right_increment_counter % max_val) + 1
						right_increment_counter = (right_increment_counter + 1) % max_val
					end

					local right_freeze_on = delay_settings.right_freeze_on
					local right_freeze_chance = delay_settings.right_freeze_chance or 0
					if right_freeze_on and (right_freeze_chance == 0 or (right_freeze_chance > 0 and client.random_int(1, 100) <= right_freeze_chance)) then
						local raw_ticks = delay_settings.right_freeze_ticks or 0
						local freeze_add = 0
						if raw_ticks == 0 then
							freeze_add = client.random_int(1, 16)
						elseif raw_ticks == 17 then
							local state = fluctuate_states.right_freeze
							if state.val1 == nil or state.remaining <= 0 then
								state.val1 = client.random_int(0, 16)
								state.val2 = client.random_int(0, 16)
								state.phase = true
								state.remaining = 2
							end
							freeze_add = state.phase and state.val1 or state.val2
							state.phase = not state.phase
							state.remaining = state.remaining - 1
						else
							freeze_add = raw_ticks
						end

						if right_freeze_chance == 0 then
							local r1 = client.random_int(0, freeze_add)
							local r2 = client.random_int(0, freeze_add)
							local dispersion_offset = math.floor((r1 + r2) / 2 + 0.5)
							target_delay_ticks = target_delay_ticks + dispersion_offset
						else
							target_delay_ticks = target_delay_ticks + freeze_add
						end
					end
				end
			end
		end
	else
		delay_counter = delay_counter + 1
	end
end

local function finalize_tick()
	if aa_state.send_packet then
		aa_state.sent = aa_state.sent >= 65535 and 0 or aa_state.sent + 1
	end

	handle_aa_delay(active_aa_settings.cur.delay)
	table.clear(frame_flags)
end

local function extrapolate_position_physics(ent, origin_x, origin_y, origin_z, vel_x, vel_y, vel_z, ticks)
	local tickinterval = globals.tickinterval()
	local sv_gravity = (cvar.sv_gravity and cvar.sv_gravity:get_float() or 800) * tickinterval
	local flags = entity.get_prop(ent, "m_fFlags") or 0
	local on_ground = bit.band(flags, 1) == 1

	local cur_x, cur_y, cur_z = origin_x, origin_y, origin_z
	local prev_x, prev_y, prev_z = cur_x, cur_y, cur_z
	local vx, vy, vz = vel_x or 0, vel_y or 0, vel_z or 0

	for i = 1, ticks do
		prev_x, prev_y, prev_z = cur_x, cur_y, cur_z

		if not on_ground or vz > 0 or vz < -100 then
			vz = vz - sv_gravity
		end

		cur_x = prev_x + vx * tickinterval
		cur_y = prev_y + vy * tickinterval
		cur_z = prev_z + vz * tickinterval

		local fraction = client.trace_line(ent, prev_x, prev_y, prev_z, cur_x, cur_y, cur_z)
		if (fraction or 1) < 0.99 then
			return prev_x, prev_y, prev_z
		end
	end

	return cur_x, cur_y, cur_z
end

local last_peeking = false
local main_aa_handler = {
	work = function(user_command)
		cmd = user_command

		update_local_player_state(cmd)

		if LocalPawn.valid and not last_peeking then
			local peek_detected = false
			local eye_x, eye_y, eye_z = client.eye_position()
			local vx, vy, vz = entity.get_prop(LocalPawn.self, "m_vecVelocity")
			local ticks_to_extrapolate = reference.misc.settings.maxshift.value - reference.rage.aimbot.dt_fl[1].value + 1
			
			local lx, ly, lz = extrapolate_position_physics(LocalPawn.self, eye_x, eye_y, eye_z, vx or 0, vy or 0, vz or 0, ticks_to_extrapolate)

			for i = 1, #enemies_list do
				local player = enemies_list[i]
				if bit.band(entity.get_esp_data(player).flags or 0, bit.lshift(1, 11)) == 0 then
					local evx, evy, evz = entity.get_prop(player, "m_vecVelocity")
					local sim_time = entity.get_prop(player, "m_flSimulationTime") or 0
					local tickinterval = globals.tickinterval()
					local choked_ticks = 0

					if enemy_sim_history[player] and sim_time > enemy_sim_history[player] then
						local delta = math.floor(0.5 + (sim_time - enemy_sim_history[player]) / tickinterval)
						if delta > 1 and delta <= 64 then
							choked_ticks = delta - 1
						end
					end
					enemy_sim_history[player] = sim_time

					local enemy_extrap_ticks = 12
					local hitboxes = { 0, 2, 3 }
					for j = 1, 3 do
						local hbx, hby, hbz = entity.hitbox_position(player, hitboxes[j])
						if hbx then
							local ehbx, ehby, ehbz = extrapolate_position_physics(player, hbx, hby, hbz, evx or 0, evy or 0, evz or 0, enemy_extrap_ticks)

							local _, dmg_current = client.trace_bullet(LocalPawn.self, eye_x, eye_y, eye_z, hbx, hby, hbz)
							if (dmg_current or 0) > 0 then
								peek_detected = true
								break
							end

							local _, dmg_extrap = client.trace_bullet(LocalPawn.self, lx, ly, lz, ehbx, ehby, ehbz)
							if (dmg_extrap or 0) > 0 then
								peek_detected = true
								break
							end

							local ohx, ohy, ohz = entity.hitbox_position(LocalPawn.self, 0)
							if ohx then
								local _, dmg_enemy = client.trace_bullet(player, hbx, hby, hbz, ohx, ohy, ohz)
								if (dmg_enemy or 0) > 0 then
									peek_detected = true
									break
								end

								local _, dmg_enemy_ext = client.trace_bullet(player, ehbx, ehby, ehbz, ohx, ohy, ohz)
								if (dmg_enemy_ext or 0) > 0 then
									peek_detected = true
									break
								end
							end
						end
					end
					if peek_detected then break end
				end
			end
			if peek_detected then
				trigger_anti_bruteforce("On peek")
				last_peeking = true
			end
		end
		if not ab_state.active then
			last_peeking = false
		end

		update_aa_base_state()

		frame_flags.force_implicit = gui.antiaim.general.mode.value == "gamesense"
		frame_flags.force_implicit = frame_flags.force_implicit or not ui.is_active(reference.rage.aimbot.enable)

		aa_logic_pipeline:work()

		if frame_flags.force_implicit then
			aa_output_modules.implicit:work()
		else
			aa_output_modules.direct:work()
		end

		ab_state.last_real_yaw = cmd.yaw

		if LocalPawn.valid then
			local head_x, head_y, head_z = entity.hitbox_position(LocalPawn.self, 0)
			if head_x then
				ab_state.last_head_pos = { x = head_x, y = head_y, z = head_z }
			end
		end

		if cmd.allow_send_packet ~= false then
			aa_state.debug_real_yaw = cmd.yaw
		else
			aa_state.debug_fake_yaw = cmd.yaw
		end

		finalize_tick()
	end
}

AntiAim = {
	data = aa_state,
	ctx = final_angles,
	restore = function()
		safe_override(reference.aa.angles.enable)

		for reference_key, reference_value in next, aa_references do
			safe_override(reference_value)
		end
	end,
	run = function(self)
		gui.antiaim.on:set_callback(function(checkbox_element)
			eventManager.setup_command(checkbox_element.value, main_aa_handler.work)
			safe_override(reference.aa.angles.freestand, iif(checkbox_element.value, false, nil))
			safe_override(reference.aa.angles.freestand.hotkey, checkbox_element.value and {
				"Always on",
				0
			} or nil)
			safe_override(reference.aa.angles.fs_body, iif(checkbox_element.value, false, nil))

			if not checkbox_element.value then
				AntiAim.restore()
			end
		end, true)
	end
}

AntiAim:run()

local misc_features = {}

misc_features.clantag = {
	last = 0,
	enabled = false,
	list = {
		"            ",
		"  ?         ",
		"  ?%        ",
		"  ?%5       ",
		"  ?%5+      ",
		"  ?%5+#     ",
		"  ?%5+#2    ",
		"  ?%5+#2!   ",
		"  ?%5+#2!@  ",
		"  ?%5t#2!@  ",
		"  ?%5t#2i@  ",
		"  p%5t#2i@  ",
		"  p%5t#ri@  ",
		"  pa5t#ri@  ",
		"  pa5teri@  ",
		"  pasteri@  ",
		"  pasteria  ",
		"  pasteria  ",
		"  pasteria  ",
		"  pasteria  ",
		"  pasteria  ",
		"  pasteria  ",
		"  pasteria  ",
		"  paste2ia  ",
		"  ?aste2ia  ",
		"  ?aste2!a  ",
		"  ?a5te2!a  ",
		"  ?a5t#2!a  ",
		"  ?%5t#2!a  ",
		"  ?%5+#2!a  ",
		"  ?%5+#2!@  ",
		"   %5+#2!@  ",
		"    5+#2!@  ",
		"     +#2!@  ",
		"      #2!@  ",
		"       2!@  ",
		"        !@  ",
		"         @  ",
		"            "
	},
	work = function()
		if misc_features.clantag.enabled and not gui.misc.clantag.value then
			misc_features.clantag.enabled = false

			eventManager.net_update_end:unset(misc_features.clantag.work)
			client.set_clan_tag()
		end

		local v_283_0 = math.round(globals.curtime() * 3) % #misc_features.clantag.list + 1

		if v_283_0 == misc_features.clantag.last then
			return
		end

		misc_features.clantag.last = v_283_0

		client.set_clan_tag(misc_features.clantag.list[v_283_0])
	end,
	run = function(run_self)
		gui.misc.clantag:set_callback(function(f_285_self)
			reference.misc.clantag:set_enabled(not f_285_self.value)

			if f_285_self.value then
				run_self.enabled = true

				eventManager.net_update_end:set(run_self.work)
				safe_override(reference.misc.clantag, false)
			else
				safe_override(reference.misc.clantag)
				client.set_clan_tag()
			end
		end, true)
		defer(function()
			reference.misc.clantag:set_enabled(true)
			safe_override(reference.misc.clantag)
			client.set_clan_tag()
		end)
	end
}
misc_features.ladder = {
	work = function(work_self)
		if LocalPawn.movetype ~= 9 or work_self.forwardmove == 0 then
			misc_features.ladder.start = false

			return
		end

		if misc_features.ladder.start == false then
			misc_features.ladder.start = true
		else
			local v_work_0, v_work_1 = client.camera_angles()
			local v_work_2 = work_self.forwardmove < 0 or v_work_0 > 45

			work_self.in_moveleft, work_self.in_moveright = v_work_2 and 1 or 0, not v_work_2 and 1 or 0
			work_self.in_forward, work_self.in_back = v_work_2 and 1 or 0, not v_work_2 and 1 or 0
			work_self.in_speed = 0
			work_self.in_duck = 0

			if v_work_2 then
				work_self.forwardmove = 450
				work_self.sidemove = -450
			else
				work_self.forwardmove = -450
				work_self.sidemove = 450
			end

			work_self.pitch, work_self.yaw = 89, math.normalize_yaw(work_self.move_yaw + 90)
		end
	end,
	run = function(run_self)
		gui.misc.ladder:set_callback(function(f_289_self)
			eventManager.setup_command(f_289_self.value, run_self.work)
		end, true)
	end
}
misc_features.breaker = {
	work = function()
		if not LocalPawn.valid then
			return
		end

		local v_290_0 = entity.get_animstate(LocalPawn.self)

		if not v_290_0 then
			return
		end

		local v_290_1 = gui.misc.breaker

		if v_290_1.pitch.value and not LocalPawn.jumping and v_290_0.hit_in_ground_animation then
			entity.set_prop(LocalPawn.self, "m_flPoseParameter", 0.5, 12)
		end

		if LocalPawn.jumping then
			if v_290_1.air.value == "Static" then
				safe_override(reference.aa.other.legs, "Always slide")
				entity.set_prop(LocalPawn.self, "m_flPoseParameter", 1, 6)
			elseif v_290_1.air.value == "Jitter" then
				safe_override(reference.aa.other.legs, "Always slide")

				if globals.tickcount() % 4 > 1 then
					entity.set_prop(LocalPawn.self, "m_flPoseParameter", 1, 6)
				end
			elseif v_290_1.air.value == "Moonwalk" then
				safe_override(reference.aa.other.legs, "Never slide")
				local animlayer = entity.get_animlayer(LocalPawn.self, 6)
				if animlayer then
					animlayer.weight = 1
				end
				entity.set_prop(LocalPawn.self, "m_flPoseParameter", 0.5, 7)
			else
				safe_override(reference.aa.other.legs)
			end
		else
			if v_290_1.ground.value == "Static" then
				safe_override(reference.aa.other.legs, "Always slide")
				entity.set_prop(LocalPawn.self, "m_flPoseParameter", 0, 0)
			elseif v_290_1.ground.value == "Jitter" then
				safe_override(reference.aa.other.legs, "Always slide")

				if globals.tickcount() % 4 > 1 then
					entity.set_prop(LocalPawn.self, "m_flPoseParameter", 0, 0)
				end
			elseif v_290_1.ground.value == "Moonwalk" then
				safe_override(reference.aa.other.legs, "Never slide")
				entity.set_prop(LocalPawn.self, "m_flPoseParameter", 0.5, 7)
			else
				safe_override(reference.aa.other.legs)
			end
		end
	end,
	run = function(run_self)
		gui.misc.breaker.on:set_callback(function(f_292_self)
			eventManager.pre_render(f_292_self.value, run_self.work)

			if not f_292_self.value then
				safe_override(reference.aa.other.legs)
			end
		end, true)
	end
}
misc_features.filter = {
	callback = function(callback_self)
		client.delay_call(0, function()
			cvar.con_filter_enable:set_int(callback_self.value and 1 or 0)
			cvar.con_filter_text:set_string(callback_self.value and "pasteria" or "")
		end)
	end,
	run = function(run_self)
		gui.misc.filter:set_callback(run_self.callback, true)
		eventManager.shutdown:set(function()
			cvar.con_filter_enable:set_int(0)
			cvar.con_filter_text:set_string("")
		end)
	end
}

for i, j in next, misc_features do
	j:run()
end

local unused_local
local shot_records = {}
local non_aim_weapons = {
	"knife",
	"c4",
	"decoy",
	"flashbang",
	"hegrenade",
	"incgrenade",
	"molotov",
	"inferno",
	"smokegrenade"
}
local log_colors = {
	mismatch = {
		"\aD59A4D",
		"\aD59A4D\x01",
		"\a",
		ColorUtils.hex("D59A4D")
	},
	hit = {
		"\aA3D350",
		"\aA3D350\x01",
		"\x06",
		ColorUtils.hex("A3D350")
	},
	miss = {
		"\aA67CCF",
		"\aA67CCF\x01",
		"\x03",
		ColorUtils.hex("A67CCF")
	},
	harm = {
		"\ad35050",
		"\ad35050\x01",
		"\a",
		ColorUtils.hex("d35050")
	},
	brute = {
		"\aBFBFBF",
		"\aBFBFBF\x01",
		"\x01",
		ColorUtils.hex("BFBFBF")
	},
	evaded = {
		"\aB0C6FF",
		"\aB0C6FF\x01",
		"\x01",
		ColorUtils.hex("AB0C6F")
	},
	ab = {
		"\aD59A4D",
		"\aD59A4D\x01",
		"\x01",
		ColorUtils.hex("D59A4D")
	}
}
eventLogger = {
	list = {}
}

generate_quadrant_offsets = function(quad, max_weight, current_state)
	local yaw_mult = 10
	if current_state == "air" or current_state == "airc" then
		yaw_mult = 20
	end

	local yaw, desync
	if quad == "q1" then
		yaw = client.random_float(0, max_weight) * yaw_mult
		desync = client.random_float(0.75, 1.00)
	elseif quad == "q2" then
		yaw = client.random_float(0, max_weight) * yaw_mult
		desync = -client.random_float(0.35, 0.60)
	elseif quad == "q3" then
		yaw = client.random_float(-max_weight, 0) * yaw_mult
		desync = client.random_float(0.75, 1.00)
	else -- "q4"
		yaw = client.random_float(-max_weight, 0) * yaw_mult
		desync = -client.random_float(0.35, 0.60)
	end
	return yaw, desync
end

function trigger_anti_bruteforce(reason, attacker)
	if not gui.antiaim.ab or gui.antiaim.ab.on:get() ~= 1 then
		return
	end

	if not gui.antiaim.ab.triggers:get(reason) then
		return
	end

	if LocalPawn.valid then
		local head_x, head_y, head_z = entity.hitbox_position(LocalPawn.self, 0)
		if head_x then
			ab_state.last_head_pos = { x = head_x, y = head_y, z = head_z }
		end
	end

	if not attacker then
		attacker = LocalPawn.threat
	end

	local power = gui.antiaim.ab.power:get()
	local timer_val = gui.antiaim.ab.timer:get()
	local split_active = gui.antiaim.ab.split:get()

	-- Get current AA movement state key name from AntiAimConditions
	local current_state = (aa_state and aa_state.state and AntiAimConditions.states[aa_state.state]) and AntiAimConditions.states[aa_state.state][1] or "default"
	ab_state.state = current_state

	-- Calculate ab weights
	local max_weight = power == 0 and client.random_float(0.20, 0.50) or power / 100
	local best_quad = choose_best_quadrant(attacker, current_state, reason, max_weight)

	if split_active then
		ab_state.yaw_shift_left, ab_state.desync_shift_left = generate_quadrant_offsets(best_quad, max_weight, current_state)
		ab_state.yaw_shift_right, ab_state.desync_shift_right = generate_quadrant_offsets(best_quad, max_weight, current_state)
	else
		local common_yaw, common_desync = generate_quadrant_offsets(best_quad, max_weight, current_state)
		ab_state.yaw_shift_left = common_yaw
		ab_state.yaw_shift_right = common_yaw
		ab_state.desync_shift_left = common_desync
		ab_state.desync_shift_right = common_desync
	end
	ab_state.active = true

	if timer_val > 0 then
		ab_state.timer_end = globals.realtime() + timer_val * 0.1
	else
		ab_state.timer_end = nil -- On trigger (until next trigger)
	end

	-- Always push screen and console event logs if Anti-bruteforce is On
	local log_text_screen, log_text_console
	local time_suffix_screen = timer_val > 0 and string.format(" \aCDCDCD\x01(%s, %s, %.1fs)", best_quad, current_state, timer_val * 0.1) or string.format(" \aCDCDCD\x01(%s, %s, static)", best_quad, current_state)
	local time_suffix_console = timer_val > 0 and string.format(", %s, %s, %.1fs", best_quad, current_state, timer_val * 0.1) or string.format(", %s, %s", best_quad, current_state)

	if split_active then
		log_text_screen = string.format(
			"\aB3B3B3\x01•\aE6E6E6\x02 ab \aE6E6E6\x01->\aE6E6E6\x02 L: \aE6E6E6\x01%+.1f°\aE6E6E6\x02/\aE6E6E6\x01%+.0f%%\aE6E6E6\x02 | R: \aE6E6E6\x01%+.1f°\aE6E6E6\x02/\aE6E6E6\x01%+.0f%%\aE6E6E6\x02%s",
			ab_state.yaw_shift_left,
			ab_state.desync_shift_left * 100,
			ab_state.yaw_shift_right,
			ab_state.desync_shift_right * 100,
			time_suffix_screen
		)
		log_text_console = string.format("[ab] L: %+.1f°/%+.0f%% | R: %+.1f°/%+.0f%% (%s%s)", 
			ab_state.yaw_shift_left,
			ab_state.desync_shift_left * 100,
			ab_state.yaw_shift_right,
			ab_state.desync_shift_right * 100,
			reason,
			time_suffix_console
		)
	else
		log_text_screen = string.format(
			"\aB3B3B3\x01•\aE6E6E6\x02 ab \aE6E6E6\x01->\aE6E6E6\x02 \aE6E6E6\x01%+.1f°\aE6E6E6\x02/\aE6E6E6\x01%+.0f%%\aE6E6E6\x02%s",
			ab_state.yaw_shift_left,
			ab_state.desync_shift_left * 100,
			time_suffix_screen
		)
		log_text_console = string.format("[ab] %+.1f°/%+.0f%% (%s%s)", 
			ab_state.yaw_shift_left,
			ab_state.desync_shift_left * 100,
			reason,
			time_suffix_console
		)
	end
	eventLogger.push("ab", log_text_console, log_text_screen)
end

eventLogger.events = {
	evade = function(evade_self)
		StatisticUpd(1)
		if evade_self.damaged then
			return
		end

		-- Record that we successfully evaded (safe quadrant)
		if ab_state.active then
			local attacker = evade_self.attacker
			local name = entity.get_player_name(attacker) or tostring(attacker)
			local q_left = get_quadrant(ab_state.yaw_shift_left, ab_state.desync_shift_left)
			local q_right = get_quadrant(ab_state.yaw_shift_right, ab_state.desync_shift_right)
			local current_state = ab_state.state or "default"
			
			update_quadrant_scores(name, current_state, q_left, q_right, 1)
			update_quadrant_scores("_global_shared", current_state, q_left, q_right, 1)
		end

		-- Trigger anti-bruteforce if "Evade" trigger is enabled
		trigger_anti_bruteforce("Evade", evade_self.attacker)

		-- Block standard evade log if anti-bruteforce is On
		if gui.antiaim.ab and gui.antiaim.ab.on and gui.antiaim.ab.on:get() == 1 then
			return
		end

		if not gui.misc.logs.events:get("Anti-aim info") then
			return
		end

		eventLogger.invent("evaded", {{true,	"evaded "}, {false,"Evaded "}, {{entity.get_player_name(evade_self.attacker)}, "'s shot"}})
	end,
	receive = function(receive_event, receive_local_player, receive_attacker)
		local v_receive_0 = receive_local_player == receive_attacker or receive_attacker == 0
		local v_receive_1 = receive_event.health == 0
		local v_receive_2 = receive_event.weapon
		local v_receive_3 = receive_event.dmg_health
		local v_receive_4 = ScriptData.hitgroups[receive_event.hitgroup or 0] or "generic"
		local v_receive_5 = v_receive_1 and "Killed by" or "Harmed by"

		receive_attacker = receive_attacker ~= 0 and entity.get_player_name(receive_attacker) or "world"

		local v_receive_6 = {
			v_receive_0 and {
				true,
				{
					"you"
				},
				v_receive_1 and " killed " or " harmed "
			} or {
				true,
				string.lower(v_receive_5),
				" "
			},
			v_receive_0 and {
				false,
				{
					"You"
				},
				v_receive_1 and " killed " or " harmed "
			} or {
				false,
				v_receive_5,
				" "
			},
			{
				v_receive_0 and {
					"yourself"
				} or {
					receive_attacker
				}
			},
			not v_receive_0 and v_receive_4 ~= "generic" and { -- legs
				" in ",
				{
					v_receive_4
				}
			} or nil,
			not v_receive_1 and {
				" for ",
				{
					v_receive_3,
					" hp"
				}
			} or nil
		}

		eventLogger.invent("harm", v_receive_6)
	end,
	harm = function(harm_event, harm_local_player, harm_attacker)
		if not table.find(non_aim_weapons, harm_event.weapon) and harm_event.weapon ~= "knife" then
			return
		end

		local v_harm_0 = harm_event.health == 0
		local harm_label_a  = "a " .. harm_event.weapon

		if harm_event.weapon == "hegrenade" then
			harm_label_a  = "an HE grenade"
		end

		local v_harm_2 = entity.get_player_name(harm_local_player)
		local v_harm_3 = v_harm_0 and "Killed" or "Harmed"

		if v_harm_0 and harm_event.weapon == "hegrenade" then
			v_harm_3 = "Exploded"
		elseif v_harm_0 and harm_event.weapon == "knife" then
			v_harm_3 = "Stabbed"
		elseif harm_event.weapon == "inferno" then
			v_harm_3 = "Burnt"
		end

		local v_harm_4 = {
			{
				true,
				string.lower(v_harm_3),
				" "
			},
			{
				false,
				v_harm_3,
				" "
			},
			{
				{
					v_harm_2
				}
			},
			not v_harm_0 and {
				" for ",
				{
					harm_event.dmg_health,
					" hp"
				}
			} or nil,
			v_harm_0 and v_harm_3 == "Burnt" and {
				" to ",
				{
					"death"
				}
			} or nil,
			(v_harm_3 == "Killed" or v_harm_3 == "Harmed") and {
				true,
				" with ",
				{
					harm_label_a 
				}
			} or nil
		}

		eventLogger.invent("hit", v_harm_4)
	end,
	damage = function(damage_self)
		local v_damage_0 = client.userid_to_entindex(damage_self.userid)
		local v_damage_1 = damage_self.attacker ~= 0 and client.userid_to_entindex(damage_self.attacker) or 0

		if v_damage_0 == LocalPawn.self then
			-- Record that we got resolved/hit (unsafe quadrant)
			if ab_state.active and v_damage_1 ~= 0 then
				local name = entity.get_player_name(v_damage_1) or tostring(v_damage_1)
				local q_left = get_quadrant(ab_state.yaw_shift_left, ab_state.desync_shift_left)
				local q_right = get_quadrant(ab_state.yaw_shift_right, ab_state.desync_shift_right)
				local current_state = ab_state.state or "default"
				
				local hitg = damage_self.hitgroup
				local penalty = 2
				if hitg == 1 or (hitg >= 4 and hitg <= 7) then -- head or limbs
					penalty = 4
				end
				
				update_quadrant_scores(name, current_state, q_left, q_right, -penalty)
				update_quadrant_scores("_global_shared", current_state, q_left, q_right, -penalty)
			end
			if damage_self.health > 0 then
				trigger_anti_bruteforce("On damage", v_damage_1)
			end
			if gui.misc.logs.events:get("Getting harmed") then
				eventLogger.events.receive(damage_self, v_damage_0, v_damage_1)
			end
		elseif v_damage_1 == LocalPawn.self and v_damage_0 ~= LocalPawn.self and gui.misc.logs.events:get("Harming enemies") then
			eventLogger.events.harm(damage_self, v_damage_0, v_damage_1)
		end
	end,
	miss = function(miss_self)
		StatisticUpd(4)

		if not gui.misc.logs.events:get("Ragebot shots") then
			return
		end

		local v_miss_0 = shot_records[miss_self.id] or {}
		local miss_text_label = "Missed"
		local v_miss_2 = entity.get_player_name(miss_self.target)
		local v_miss_3 = miss_self.reason

		if v_miss_3 == "prediction error" and v_miss_0.difference and v_miss_0.difference > 2 then
			v_miss_3 = "unpredicted occasion"
		end

		local v_miss_4 = ScriptData.hitgroups[miss_self.hitgroup]
		local v_miss_5 = {
			{
				false,
				miss_text_label,
				" "
			},
			{
				true,
				string.lower(miss_text_label),
				" "
			},
			{
				{
					v_miss_2
				}
			},
			v_miss_4 and {
				"'s ",
				{
					v_miss_4
				}
			},
			v_miss_3 ~= "?" and {
				" due to ",
				{
					v_miss_3
				}
			} or nil
		}
		local v_miss_6 = {
			v_miss_0.damage and {
				"dmg: ",
				{
					v_miss_0.damage
				}
			},
			{
				"hc: ",
				{
					math.round(miss_self.hit_chance),
					"%%"
				},
				reference.rage.aimbot.hit_chance.value - miss_self.hit_chance > 3 and "⮟" or ""
			} or nil,
			v_miss_0.difference and v_miss_0.difference ~= 0 and {
				"Δ: ",
				{
					v_miss_0.difference,
					"t"
				},
				v_miss_0.difference < 0 and "⮟" or ""
			} or nil,
			(v_miss_0.interpolated or v_miss_0.extrapolated) and {
				{
					v_miss_0.interpolated and "IN" or "",
					v_miss_0.extrapolated and "EP" or ""
				}
			} or nil
		}

		eventLogger.invent("miss", v_miss_5, v_miss_6)

		shot_records[miss_self.id] = nil
	end,
	hit = function(hit_self)
		if not entity.is_alive(hit_self.target) then
			hit_label_hit = "Killed"
			StatisticUpd(2)
		end

		if not gui.misc.logs.events:get("Ragebot shots") then
			return
		end

		local v_hit_0 = shot_records[hit_self.id] or {}
		local hit_label_hit = "Hit"

		if not entity.is_alive(hit_self.target) then
			hit_label_hit = "Killed"
		end

		local v_hit_2 = entity.get_player_name(hit_self.target)
		local v_hit_3 = ScriptData.hitgroups[hit_self.hitgroup]
		local v_hit_4 = ScriptData.hitgroups[v_hit_0.hitgroup or 0]
		local v_hit_5 = hit_label_hit == "Hit" and hit_self.hitgroup ~= v_hit_0.hitgroup
		local v_hit_6 = hit_label_hit == "Hit" and (v_hit_0.damage or 0) - (hit_self.damage or 0) > 10
		local v_hit_7

		if v_hit_6 and v_hit_5 and v_hit_4 then
			v_hit_7 = {
				v_hit_4,
				"-",
				v_hit_0.damage
			}
		elseif v_hit_6 then
			v_hit_7 = {
				v_hit_0.damage,
				" hp"
			}
		end

		local v_hit_8 = {
			{
				true,
				string.lower(hit_label_hit),
				" ",
				{
					v_hit_2
				}
			},
			{
				false,
				hit_label_hit,
				" ",
				{
					v_hit_2
				}
			},
			v_hit_3 and v_hit_3 ~= "generic" and {
				hit_label_hit == "Hit" and "'s " or " in ",
				{
					v_hit_3
				},
				v_hit_5 and "\aD59A4D!\r" or ""
			} or nil,
			hit_label_hit == "Hit" and {
				" for ",
				{
					hit_self.damage,
					" hp"
				},
				v_hit_6 and "\aD59A4D!\r" or ""
			} or nil
		}
		local v_hit_9 = {
			v_hit_7 and {
				"exp: ",
				v_hit_7
			},
			v_hit_0.difference ~= 0 and {
				"Δ: ",
				{
					v_hit_0.difference,
					"t"
				}
			} or nil,
			reference.rage.aimbot.hit_chance.value - hit_self.hit_chance > 5 and {
				"hc: ",
				{
					math.floor(hit_self.hit_chance),
					"%%"
				},
				"⮟"
			} or nil
		}

		eventLogger.invent("hit", v_hit_8, v_hit_9)

		shot_records[hit_self.id] = nil
	end,
	aim = function(aim_self)
		StatisticUpd(3)
		trigger_anti_bruteforce("Local shot")

		if not gui.misc.logs.events:get("Ragebot shots") then
			return
		end

		aim_self.difference = globals.tickcount() - aim_self.tick
		shot_records[aim_self.id] = aim_self
	end
}

function eventLogger.invent(eventLogger_invent_alpha, eventLogger_invent_x, eventLogger_invent_y)
	local v_eventLogger_invent_0 = {
		console = {},
		screen = {},
		chat = {}
	}

	if eventLogger_invent_alpha then
		local v_eventLogger_invent_1 = 0
		local v_eventLogger_invent_2 = 0
		local v_eventLogger_invent_3 = log_colors[eventLogger_invent_alpha]

		v_eventLogger_invent_0.console[v_eventLogger_invent_1 + 1], v_eventLogger_invent_0.console[v_eventLogger_invent_1 + 2] = v_eventLogger_invent_3 and v_eventLogger_invent_3[1] or "", " •\r "
		v_eventLogger_invent_0.screen[v_eventLogger_invent_2 + 1], v_eventLogger_invent_0.screen[v_eventLogger_invent_2 + 2] = v_eventLogger_invent_3 and v_eventLogger_invent_3[2] or "", "•\aE6E6E6\x02 "
	end

	for i = 1, table.maxn(eventLogger_invent_x) do
		local v_eventLogger_invent_4 = eventLogger_invent_x[i]

		if not v_eventLogger_invent_4 then
			-- block empty
		elseif type(v_eventLogger_invent_4) == "table" then
			local v_eventLogger_invent_5 = eventLogger_invent_x[i][1] == true and 1 or eventLogger_invent_x[i][1] == false and 2 or 0

			for j, key in ipairs(v_eventLogger_invent_4) do
				local v_eventLogger_invent_6 = type(key)

				if v_eventLogger_invent_6 ~= "boolean" or j ~= 1 then
					if v_eventLogger_invent_5 ~= 2 then
						if v_eventLogger_invent_6 == "table" then
							table.move(key, 1, #key, #v_eventLogger_invent_0.console + 1, v_eventLogger_invent_0.console)
							table.move(key, 1, #key, #v_eventLogger_invent_0.chat + 1, v_eventLogger_invent_0.chat)
						else
							local v_eventLogger_invent_7 = #v_eventLogger_invent_0.console
							local v_eventLogger_invent_8 = #v_eventLogger_invent_0.chat

							v_eventLogger_invent_0.console[v_eventLogger_invent_7 + 1], v_eventLogger_invent_0.console[v_eventLogger_invent_7 + 2], v_eventLogger_invent_0.console[v_eventLogger_invent_7 + 3] = "\a909090", v_eventLogger_invent_6 == "string" and key or tostring(key), "\r"
							v_eventLogger_invent_0.chat[v_eventLogger_invent_8 + 1], v_eventLogger_invent_0.chat[v_eventLogger_invent_8 + 2], v_eventLogger_invent_0.chat[v_eventLogger_invent_8 + 3] = "\b", v_eventLogger_invent_6 == "string" and string.gsub(key, "\a%x%x%x%x%x%x", "") or tostring(key), "\x01"
						end
					end

					if v_eventLogger_invent_5 ~= 1 then
						if v_eventLogger_invent_6 == "table" then
							local v_eventLogger_invent_9 = #v_eventLogger_invent_0.screen

							for val = 1, #key, 3 do
								v_eventLogger_invent_0.screen[v_eventLogger_invent_9 + val], v_eventLogger_invent_0.screen[v_eventLogger_invent_9 + val + 1], v_eventLogger_invent_0.screen[v_eventLogger_invent_9 + val + 2] = "\aE6E6E6\x01", key[val], "\aE6E6E6\x02"
							end
						else
							local v_eventLogger_invent_10 = #v_eventLogger_invent_0.screen

							v_eventLogger_invent_0.screen[v_eventLogger_invent_10 + 1], v_eventLogger_invent_0.screen[v_eventLogger_invent_10 + 2] = v_eventLogger_invent_6 == "string" and string.gsub(key, "\a%x%x%x%x%x%x", function(f_314_self)
								return f_314_self .. "\x01"
							end) or tostring(key), "\aE6E6E6\x02"
						end
					end
				end
			end
		else
			local v_eventLogger_invent_11 = #v_eventLogger_invent_0.console

			v_eventLogger_invent_0.console[v_eventLogger_invent_11 + 1], v_eventLogger_invent_0.console[v_eventLogger_invent_11 + 2], v_eventLogger_invent_0.console[v_eventLogger_invent_11 + 3] = "\a808080", tostring(v_eventLogger_invent_4), "\r"
			v_eventLogger_invent_0.screen[#v_eventLogger_invent_0.screen + 1] = type(v_eventLogger_invent_4) == "string" and string.gsub(v_eventLogger_invent_4, "\a%x%x%x%x%x%x", function(f_315_self)
				return f_315_self .. "\x02"
			end) or tostring(v_eventLogger_invent_4)
		end
	end

	eventLogger_invent_y = type(eventLogger_invent_y) == "table" and table.filter(eventLogger_invent_y) or nil

	if eventLogger_invent_y and #eventLogger_invent_y > 0 then
		v_eventLogger_invent_0.console[#v_eventLogger_invent_0.console + 1] = " \v~\r "

		for iter_313_4 = 1, #eventLogger_invent_y do
			if type(eventLogger_invent_y[iter_313_4]) == "table" then
				for iter_313_5, iter_313_6 in ipairs(eventLogger_invent_y[iter_313_4]) do
					local v_eventLogger_invent_12 = type(iter_313_6)

					if v_eventLogger_invent_12 == "table" then
						v_eventLogger_invent_0.console[#v_eventLogger_invent_0.console + 1] = "\aAAAAAA"

						table.move(iter_313_6, 1, #iter_313_6, #v_eventLogger_invent_0.console + 1, v_eventLogger_invent_0.console)
					else
						local v_eventLogger_invent_13 = #v_eventLogger_invent_0.console

						v_eventLogger_invent_0.console[v_eventLogger_invent_13 + 1], v_eventLogger_invent_0.console[v_eventLogger_invent_13 + 2] = "\a707070", v_eventLogger_invent_12 == "string" and iter_313_6 or tostring(iter_313_6)
					end

					v_eventLogger_invent_0.console[#v_eventLogger_invent_0.console + 1] = "\r"
				end
			else
				local v_eventLogger_invent_14 = #v_eventLogger_invent_0.console

				v_eventLogger_invent_0.console[v_eventLogger_invent_14 + 1], v_eventLogger_invent_0.console[v_eventLogger_invent_14 + 2], v_eventLogger_invent_0.console[v_eventLogger_invent_14 + 3] = "\a707070", tostring(eventLogger_invent_x[iter_313_4]), "\r"
			end

			if iter_313_4 < #eventLogger_invent_y then
				v_eventLogger_invent_0.console[#v_eventLogger_invent_0.console + 1] = "\a707070, \r"
			end
		end
	end

	eventLogger.push(eventLogger_invent_alpha, table.concat(v_eventLogger_invent_0.console), table.concat(v_eventLogger_invent_0.screen), table.concat(v_eventLogger_invent_0.chat))
end

function eventLogger.push(eventType, consoleMessage, screenMessage)
	if consoleMessage and gui.misc.logs.output:get("Console") then
		logToConsole(consoleMessage)
	end

	if screenMessage and gui.misc.logs.output:get("Screen") then
		table.insert(eventLogger.list, 1, {
			event = eventType,
			text = screenMessage,
			time = globals.realtime(),
			progress = {
				0
			}
		})
	end
end

function eventLogger.clear_stack()
	shot_records = {}
	ab_state.active = false
	ab_state.yaw_shift_left = 0
	ab_state.yaw_shift_right = 0
	ab_state.desync_shift_left = 0
	ab_state.desync_shift_right = 0
	ab_state.timer_end = nil
end

function eventLogger.run(eventLogger_run_self)
	eventManager.enemy_shot(1, eventLogger_run_self.events.evade)
	eventManager.aim_fire(1, eventLogger_run_self.events.aim)
	eventManager.aim_hit(1, eventLogger_run_self.events.hit)
	eventManager.aim_miss(1, eventLogger_run_self.events.miss)
	gui.misc.logs.on:set_callback(function(f_319_self)
		-- eventManager.aim_fire(f_319_self.value, eventLogger_run_self.events.aim)
		-- eventManager.aim_hit(f_319_self.value, eventLogger_run_self.events.hit)
		-- eventManager.aim_miss(f_319_self.value, eventLogger_run_self.events.miss)
		eventManager.player_hurt(f_319_self.value, eventLogger_run_self.events.damage)
		-- eventManager.enemy_shot(f_319_self.value, eventLogger_run_self.events.evade)
		eventManager.local_spawned(f_319_self.value, eventLogger_run_self.clear_stack)

		local v_319_0 = iif(f_319_self.value, false, nil)

		safe_override(reference.rage.other.log_misses, v_319_0)
		safe_override(reference.misc.log_damage, v_319_0)
	end, true)
	reference.rage.other.log_misses:depend(true, {
		gui.misc.logs.on,
		false
	})
	reference.misc.log_damage:depend(true, {
		gui.misc.logs.on,
		false
	})
end

eventLogger:run()

local visual_features = {}

visual_features.aspect = {
	active = false,
	value = scaled_screen_width / scaled_screen_height,
	init = scaled_screen_width / scaled_screen_height,
	activate = function()
		visual_features.aspect.active = true
	end,
	work = function()
		local v_aspect_0 = visual_features.aspect
		local v_aspect_1 = gui.visuals.aspect

		if not v_aspect_0.active then
			return
		end

		if v_aspect_1.on.value then
			local v_aspect_2 = v_aspect_1.ratio.value * 0.01

			v_aspect_0.value = animation_module.lerp(v_aspect_0.value, v_aspect_2, 8, 0.001)
			v_aspect_0.active = v_aspect_2 ~= v_aspect_0.value

			cvar.r_aspectratio:set_float(v_aspect_0.value)
		else
			v_aspect_0.value = animation_module.lerp(v_aspect_0.value, v_aspect_0.init)

			cvar.r_aspectratio:set_float(v_aspect_0.value)

			if v_aspect_0.value == v_aspect_0.init then
				eventManager.paint_ui:unset(v_aspect_0.work)
				cvar.r_aspectratio:set_float(0)

				v_aspect_0.active = false
			end
		end
	end,
	run = function(run_self)
		local v_run_0 = gui.visuals.aspect

		v_run_0.on:set_callback(function(f_323_self)
			run_self.active = true

			if f_323_self.value then
				eventManager.paint_ui:set(run_self.work)
			end
		end, true)
		v_run_0.ratio:set_callback(run_self.activate, true)
		defer(function()
			cvar.r_aspectratio:set_float(0)
		end)
	end
}
visual_features.marker = {
	duration = 2,
	list = {},
	marker = function(marker_alpha, marker_x, marker_y)
		local v_marker_0, v_marker_1 = renderer.world_to_screen(marker_alpha.x, marker_alpha.y, marker_alpha.z)

		if v_marker_0 and v_marker_1 then
			local v_marker_2, v_marker_3 = v_marker_0 / g_dpi_scale, v_marker_1 / g_dpi_scale

			if marker_y then
				local v_marker_4 = 32 * marker_x

				render_module.circle(v_marker_2, v_marker_3, palette.accent:alphen(1 - marker_x, true), v_marker_4)
			end

			render_module.texture(gfx_assets.mini_bfly, v_marker_2 - 5, v_marker_3 - 5, 9, 9, palette.accent)
		end
	end,
	work = function()
		local v_marker_0 = visual_features.marker

		for i, j in ipairs(v_marker_0.list) do
			local v_marker_1 = j.time > globals.realtime()
			local v_marker_2 = animation_module.condition(j.progress, v_marker_1, {
				3,
				-4
			}, {
				{
					1,
					4
				},
				{
					3,
					4
				}
			})

			render_module.push_alpha(v_marker_2)
			v_marker_0.marker(j, v_marker_2, v_marker_1)
			render_module.pop_alpha()

			if not v_marker_1 and v_marker_2 == 0 then
				table.remove(v_marker_0.list, i)
			end
		end
	end,
	append = {
		temp = {},
		function(f_327_self)
			visual_features.marker.append.temp[f_327_self.id] = {
				x = f_327_self.x,
				y = f_327_self.y,
				z = f_327_self.z
			}
		end,
		function(marker_self)
			local v_marker_0 = visual_features.marker
			local v_marker_1 = v_marker_0.append.temp[marker_self.id]

			table.insert(v_marker_0.list, 1, {
				x = v_marker_1.x,
				y = v_marker_1.y,
				z = v_marker_1.z,
				time = globals.realtime() + v_marker_0.duration,
				progress = {
					0
				}
			})

			v_marker_0.append.temp[marker_self.id] = nil
		end,
		function(f_329_self)
			visual_features.marker.append.temp[f_329_self.id] = nil
		end
	},
	run = function(run_self)
		local v_run_0 = gui.visuals.marker

		v_run_0:set_event("aim_fire", run_self.append[1])
		v_run_0:set_event("aim_hit", run_self.append[2])
		v_run_0:set_event("aim_miss", run_self.append[3])
		v_run_0:set_event("paint", run_self.work)
	end
}

for key, val in next, visual_features do
	val:run()
end

feature_modules = {}

feature_modules.exswitch = {
	ovr = false,
	latest = false,
	dirty_until = 0,
	weapon_tabs = {
		"Global",
		"Auto",
		"Autosniper",
		"Auto sniper",
		"Auto snipers",
		"Scout",
		"SSG 08",
		"SSG-08",
		"AWP",
		"R8 Revolver",
		"Desert Eagle",
		"Pistol",
		"Heavy pistol",
		"Heavy pistols",
		"SMG",
		"Rifle",
		"Rifles",
		"Shotgun",
		"Shotguns",
		"Machine gun",
		"Machine guns",
		"Zeus",
		"Knife"
	},
	with_all_weapon_tabs = function(self, callback)
		if not reference.rage.weapon or type(reference.rage.weapon.set) ~= "function" then
			callback()
			return
		end

		local ok, original_tab = pcall(function()
			if type(reference.rage.weapon.get) == "function" then
				return reference.rage.weapon:get()
			end

			return reference.rage.weapon.value
		end)

		callback(original_tab)

		for i = 1, #self.weapon_tabs do
			local tab_name = self.weapon_tabs[i]
			if pcall(function() reference.rage.weapon:set(tab_name) end) then
				callback(tab_name)
			end
		end

		if ok and original_tab ~= nil then
			pcall(function() reference.rage.weapon:set(original_tab) end)
		end
	end,
	apply_dt_override = function(self, value)
		self:with_all_weapon_tabs(function()
			safe_override(reference.rage.aimbot.double_tap[1], value)
		end)

		self.dirty_until = globals.tickcount() + 128
	end,
	restore_current = function(self)
		safe_override(reference.rage.aimbot.double_tap[1])
	end,
	force_dt = function(self)
		safe_override(reference.rage.aimbot.double_tap[1], true)

		if self.ovr or self.dirty_until <= globals.tickcount() then
			self:apply_dt_override(true)
		else
			self.dirty_until = globals.tickcount() + 128
		end

		safe_override(reference.aa.other.onshot.hotkey)
		self.ovr = false
	end,
	restore = function(self)
		self:apply_dt_override()
		safe_override(reference.aa.other.onshot.hotkey)
		self.ovr = false
	end,
	work = function(cmd)
		local var_341_0 = feature_modules.exswitch
		local var_341_1 = gui.rage.exswitch
		local var_341_2 = safe_get(reference.rage.aimbot.double_tap[1].hotkey)
		local var_341_3 = safe_get(reference.aa.other.onshot.hotkey)
		local var_341_4 = reference.rage.other.peek.value and safe_get(reference.rage.other.peek.hotkey)
		local var_341_5 = (not LocalPawn.walking and not (LocalPawn.velocity < 5) or not not var_341_4) and not LocalPawn.crouching
		local var_341_6 = false
		local var_341_7 = LocalPawn.weapon_t
		if var_341_7 then
			local var_341_8 = entity.get_prop(LocalPawn.weapon, "m_iItemDefinitionIndex")
			local var_341_9
			var_341_6, var_341_9 = var_341_7.is_full_auto, var_341_8 == 1
			if var_341_7.weapon_type_int == 1 and not var_341_9 and not var_341_1.allow:get("Pistols") or var_341_9 and not var_341_1.allow:get("Desert Eagle") then
				var_341_6 = true
			end
		end
		if LocalPawn.on_ground and var_341_2 and not var_341_6 and not var_341_5 and cmd.weaponselect == 0 then
			var_341_0:apply_dt_override(false)
			safe_override(reference.aa.other.onshot.hotkey, {"Always on", 0})
			var_341_0.ovr = true
		elseif var_341_2 then
			var_341_0:force_dt()
		elseif var_341_0.ovr then
			var_341_0:restore()
		elseif var_341_0.dirty_until > globals.tickcount() then
			var_341_0:restore_current()
		end
	end,
	run = function(run_self)
		gui.rage.exswitch.on:set_event("setup_command", run_self.work)
		gui.rage.exswitch.on:set_callback(function(arg_343_0)
			if not arg_343_0.value then
				run_self:restore()
			end
		end)
		eventManager.shutdown:set(function()
			run_self:restore()
		end)
	end
}
feature_modules.recharger = {
	last = false,
	state = false,
	work = function(work_self)
		local v_work_0 = feature_modules.recharger
		local work_is_active = reference.rage.aimbot.double_tap[1].value and safe_get(reference.rage.aimbot.double_tap[1].hotkey) or reference.aa.other.onshot.value and safe_get(reference.aa.other.onshot.hotkey)

		if work_is_active ~= v_work_0.last then
			v_work_0.last = work_is_active

			if v_work_0.last then
				v_work_0.state = false
			end
		end

		if reference.rage.aimbot.enable.value == false then
			safe_override(reference.rage.aimbot.enable.hotkey)

			v_work_0.state = nil
		end

		if v_work_0.state == false and work_self.weaponselect == 0 then
			safe_override(reference.rage.aimbot.enable.hotkey, {
				"On Hotkey",
				0
			})

			v_work_0.state = true
		elseif v_work_0.state == true or work_self.weaponselect ~= 0 then
			safe_override(reference.rage.aimbot.enable.hotkey)
			safe_set(reference.rage.aimbot.enable.hotkey, "Always On", 0)

			v_work_0.state = nil
		end
	end,
	run = function(run_self)
		gui.rage.recharge:set_event("setup_command", run_self.work)
		gui.rage.recharge:set_callback(function(f_347_self)
			if f_347_self.value then
				-- block empty
			elseif run_self.state ~= nil then
				safe_override(reference.rage.aimbot.enable.hotkey)
				safe_set(reference.rage.aimbot.enable.hotkey, "Always On", 0)

				run_self.state = nil
			end
		end)
	end
}
feature_modules.peekfix = {
	work = function(work_self)
		if LocalPawn.exploit.active ~= ScriptData.exploit.DT then
			return
		end

		if LocalPawn.peeking then
			work_self.force_defensive = true
		end
	end,
	run = function(run_self)
		gui.rage.peekfix:set_callback(function(f_350_self)
			eventManager.setup_command(f_350_self.value, run_self.work)
		end, true)
	end
}

feature_modules.aimbot_helper = {
	helper_miss_counter = 0,
	playerlist_reset = hui.reference("Players", "Players", "Reset all"),
	ps_checkbox = nil,
	ps_slider = nil,
	check_trigger = function(self, triggers, hp, miss_count, hp_threshold, miss_threshold, height_diff)
		for _, trigger in ipairs(triggers) do
			if (trigger == "Enemy HP < X" and hp < hp_threshold) or
			   (trigger == "X Missed Shots" and miss_count > miss_threshold) or
			   (trigger == "Lethal" and hp <= 30) or
			   (trigger == "Height advantage" and height_diff > 70) or
			   (trigger == "Enemy higher than you" and height_diff < -70) then
				return true
			end
		end
		return false
	end,
	work = function(self)
		if not gui.rage.aimbot_helper.on.value then
			return
		end
		local me = entity.get_local_player()
		if not me or not entity.is_alive(me) then
			safe_set(self.playerlist_reset, true)
			self.helper_miss_counter = 0
			return
		end
		local gun = entity.get_player_weapon(me)
		if not gun then return end
		local weapon = entity.get_classname(gun)
		local prefix = (weapon == "CWeaponSSG08" and "ssg_") or
		               (weapon == "CWeaponAWP" and "awp_") or
		               ((weapon == "CWeaponG3SG1" or weapon == "CWeaponSCAR20") and "auto_")
		if not prefix then return end

		local select_el = gui.rage.aimbot_helper[prefix .. "select"]
		local force_safe_el = gui.rage.aimbot_helper[prefix .. "force_safe"]
		local force_safe_hp_el = gui.rage.aimbot_helper[prefix .. "force_safe_hp"]
		local force_safe_miss_el = gui.rage.aimbot_helper[prefix .. "force_safe_miss"]
		local prefer_body_el = gui.rage.aimbot_helper[prefix .. "prefer_body"]
		local prefer_body_hp_el = gui.rage.aimbot_helper[prefix .. "prefer_body_hp"]
		local prefer_body_miss_el = gui.rage.aimbot_helper[prefix .. "prefer_body_miss"]
		local force_body_el = gui.rage.aimbot_helper[prefix .. "force_body"]
		local force_body_hp_el = gui.rage.aimbot_helper[prefix .. "force_body_hp"]
		local force_body_miss_el = gui.rage.aimbot_helper[prefix .. "force_body_miss"]
		local ping_spike_value_el = gui.rage.aimbot_helper[prefix .. "ping_spike_value"]

		local my_pos = vector(entity.get_origin(me))
		local players = entity.get_players(true)
		for _, target in ipairs(players) do
			if not target or not entity.is_alive(target) or entity.is_dormant(target) then
				safe_set(self.playerlist_reset, true)
				self.helper_miss_counter = 0
				return
			end
			local hp = entity.get_prop(target, "m_iHealth") or 100
			local enemy_pos = vector(entity.get_origin(target))
			local height_diff = math.ceil(my_pos.z - enemy_pos.z)
			if select_el:get("Force safe point") and
			   self:check_trigger(force_safe_el:get(), hp, self.helper_miss_counter,
								 force_safe_hp_el.value, force_safe_miss_el.value, height_diff) then
				plist.set(target, "Override safe point", "On")
			else
				plist.set(target, "Override safe point", "-")
			end
			local prefer_body = select_el:get("Prefer body aim") and
								self:check_trigger(prefer_body_el:get(), hp, self.helper_miss_counter,
												  prefer_body_hp_el.value, prefer_body_miss_el.value, height_diff)
			local force_body = select_el:get("Force body aim") and
							   self:check_trigger(force_body_el:get(), hp, self.helper_miss_counter,
												 force_body_hp_el.value, force_body_miss_el.value, height_diff)
			if force_body then
				plist.set(target, "Override prefer body aim", "Force")
			elseif prefer_body then
				plist.set(target, "Override prefer body aim", "On")
			else
				plist.set(target, "Override prefer body aim", "-")
			end
			if select_el:get("Ping spike") then
				safe_override(self.ps_checkbox, true)
				safe_override(self.ps_slider, ping_spike_value_el.value)
			else
				safe_override(self.ps_checkbox)
				safe_override(self.ps_slider)
			end
		end
	end,
	run = function(self)
		self.ps_checkbox, self.ps_slider = hui.reference("MISC", "Miscellaneous", "Ping spike")
		gui.rage.aimbot_helper.on:set_event("setup_command", function()
			client.update_player_list()
			self:work()
		end)
		eventManager.aim_miss:set(function(e)
			if e.reason ~= "prediction error" then
				self.helper_miss_counter = self.helper_miss_counter + 1
			end
		end)
		eventManager.round_prestart:set(function()
			self.helper_miss_counter = 0
		end)
	end
}

for iter_282_4, iter_282_5 in pairs(feature_modules) do
	if iter_282_5.run then
		iter_282_5:run()
	end
end

function render_module.logo(render_module_logo_self, a_render_module_logo_1)
	render_module.texture(gfx_assets.logo_l, render_module_logo_self, a_render_module_logo_1, _AZAZI and 35 or 26, 15, palette.accent)
	render_module.texture(gfx_assets.logo_r, render_module_logo_self + (_AZAZI and 35 or 26), a_render_module_logo_1, _AZAZI and 35 or 24, 15, palette.text)
end

function render_module.edge_v(render_module_edge_v_self, a_render_module_edge_v_1, a_render_module_edge_v_2, a_render_module_edge_v_3)
	a_render_module_edge_v_3 = a_render_module_edge_v_3 or palette.accent

	render_module.texture(gfx_assets.corner_v, render_module_edge_v_self, a_render_module_edge_v_1 + 4, 6, -4, a_render_module_edge_v_3, "f")
	render_module.rectangle(render_module_edge_v_self, a_render_module_edge_v_1 + 4, 2, a_render_module_edge_v_2 - 8, a_render_module_edge_v_3)
	render_module.texture(gfx_assets.corner_v, render_module_edge_v_self, a_render_module_edge_v_1 + a_render_module_edge_v_2 - 4, 6, 4, a_render_module_edge_v_3, "f")
end

function render_module.edge_h(render_module_edge_h_self, a_render_module_edge_h_1, a_render_module_edge_h_2, a_render_module_edge_h_3)
	a_render_module_edge_h_3 = a_render_module_edge_h_3 or palette.accent

	render_module.texture(gfx_assets.corner_h, render_module_edge_h_self, a_render_module_edge_h_1, 4, 6, a_render_module_edge_h_3, "f")
	render_module.rectangle(render_module_edge_h_self + 4, a_render_module_edge_h_1, a_render_module_edge_h_2 - 8, 2, a_render_module_edge_h_3)
	render_module.texture(gfx_assets.corner_h, render_module_edge_h_self + a_render_module_edge_h_2, a_render_module_edge_h_1, -4, 6, a_render_module_edge_h_3, "f")
end

function render_module.capsule(render_module_capsule_self, render_module_capsule_x, render_module_capsule_y, render_module_capsule_w, render_module_capsule_h)
	render_module_capsule_self, render_module_capsule_x, render_module_capsule_y, render_module_capsule_w = render_module_capsule_self * g_dpi_scale, render_module_capsule_x * g_dpi_scale, render_module_capsule_y * g_dpi_scale, render_module_capsule_w * g_dpi_scale

	local v_render_module_capsule_0 = render_module_capsule_h.r
	local v_render_module_capsule_1 = render_module_capsule_h.g
	local v_render_module_capsule_2 = render_module_capsule_h.b
	local v_render_module_capsule_3 = render_module_capsule_h.a * render_module.get_alpha()
	local v_render_module_capsule_4 = render_module_capsule_w * 0.5

	renderer.circle(render_module_capsule_self + v_render_module_capsule_4, render_module_capsule_x + v_render_module_capsule_4, v_render_module_capsule_0, v_render_module_capsule_1, v_render_module_capsule_2, v_render_module_capsule_3, v_render_module_capsule_4, 180, 0.5)
	renderer.rectangle(render_module_capsule_self + v_render_module_capsule_4, render_module_capsule_x, render_module_capsule_y - render_module_capsule_w, render_module_capsule_w, v_render_module_capsule_0, v_render_module_capsule_1, v_render_module_capsule_2, v_render_module_capsule_3)
	renderer.circle(render_module_capsule_self + render_module_capsule_y - v_render_module_capsule_4, render_module_capsule_x + v_render_module_capsule_4, v_render_module_capsule_0, v_render_module_capsule_1, v_render_module_capsule_2, v_render_module_capsule_3, v_render_module_capsule_4, 0, 0.5)
end

function render_module.rounded_side_v(render_module_rounded_side_v_self, a_render_module_rounded_side_v_1, a_render_module_rounded_side_v_2, a_render_module_rounded_side_v_3, a_render_module_rounded_side_v_4, a_render_module_rounded_side_v_5)
	render_module_rounded_side_v_self, a_render_module_rounded_side_v_1, a_render_module_rounded_side_v_2, a_render_module_rounded_side_v_3, a_render_module_rounded_side_v_5 = render_module_rounded_side_v_self * g_dpi_scale, a_render_module_rounded_side_v_1 * g_dpi_scale, a_render_module_rounded_side_v_2 * g_dpi_scale, a_render_module_rounded_side_v_3 * g_dpi_scale, (a_render_module_rounded_side_v_5 or 0) * g_dpi_scale

	local v_render_module_rounded_side_v_0 = a_render_module_rounded_side_v_4.r
	local v_render_module_rounded_side_v_1 = a_render_module_rounded_side_v_4.g
	local v_render_module_rounded_side_v_2 = a_render_module_rounded_side_v_4.b
	local v_render_module_rounded_side_v_3 = a_render_module_rounded_side_v_4.a * render_module.get_alpha()

	renderer.circle(render_module_rounded_side_v_self + a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_1 + a_render_module_rounded_side_v_5, v_render_module_rounded_side_v_0, v_render_module_rounded_side_v_1, v_render_module_rounded_side_v_2, v_render_module_rounded_side_v_3, a_render_module_rounded_side_v_5, 180, 0.25)
	renderer.rectangle(render_module_rounded_side_v_self + a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_1, a_render_module_rounded_side_v_2 - a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_5, v_render_module_rounded_side_v_0, v_render_module_rounded_side_v_1, v_render_module_rounded_side_v_2, v_render_module_rounded_side_v_3)
	renderer.rectangle(render_module_rounded_side_v_self, a_render_module_rounded_side_v_1 + a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_2, a_render_module_rounded_side_v_3 - a_render_module_rounded_side_v_5 - a_render_module_rounded_side_v_5, v_render_module_rounded_side_v_0, v_render_module_rounded_side_v_1, v_render_module_rounded_side_v_2, v_render_module_rounded_side_v_3)
	renderer.circle(render_module_rounded_side_v_self + a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_1 + a_render_module_rounded_side_v_3 - a_render_module_rounded_side_v_5, v_render_module_rounded_side_v_0, v_render_module_rounded_side_v_1, v_render_module_rounded_side_v_2, v_render_module_rounded_side_v_3, a_render_module_rounded_side_v_5, 270, 0.25)
	renderer.rectangle(render_module_rounded_side_v_self + a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_1 + a_render_module_rounded_side_v_3 - a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_2 - a_render_module_rounded_side_v_5, a_render_module_rounded_side_v_5, v_render_module_rounded_side_v_0, v_render_module_rounded_side_v_1, v_render_module_rounded_side_v_2, v_render_module_rounded_side_v_3)
end

function render_module.rounded_side_h(render_module_rounded_side_h_self, a_render_module_rounded_side_h_1, a_render_module_rounded_side_h_2, a_render_module_rounded_side_h_3, a_render_module_rounded_side_h_4, a_render_module_rounded_side_h_5)
	render_module_rounded_side_h_self, a_render_module_rounded_side_h_1, a_render_module_rounded_side_h_2, a_render_module_rounded_side_h_3, a_render_module_rounded_side_h_5 = render_module_rounded_side_h_self * g_dpi_scale, a_render_module_rounded_side_h_1 * g_dpi_scale, a_render_module_rounded_side_h_2 * g_dpi_scale, a_render_module_rounded_side_h_3 * g_dpi_scale, (a_render_module_rounded_side_h_5 or 0) * g_dpi_scale

	local v_render_module_rounded_side_h_0 = a_render_module_rounded_side_h_4.r
	local v_render_module_rounded_side_h_1 = a_render_module_rounded_side_h_4.g
	local v_render_module_rounded_side_h_2 = a_render_module_rounded_side_h_4.b
	local v_render_module_rounded_side_h_3 = a_render_module_rounded_side_h_4.a * render_module.get_alpha()

	renderer.circle(render_module_rounded_side_h_self + a_render_module_rounded_side_h_5, a_render_module_rounded_side_h_1 + a_render_module_rounded_side_h_5, v_render_module_rounded_side_h_0, v_render_module_rounded_side_h_1, v_render_module_rounded_side_h_2, v_render_module_rounded_side_h_3, a_render_module_rounded_side_h_5, 180, 0.25)
	renderer.rectangle(render_module_rounded_side_h_self + a_render_module_rounded_side_h_5, a_render_module_rounded_side_h_1, a_render_module_rounded_side_h_2 - a_render_module_rounded_side_h_5 - a_render_module_rounded_side_h_5, a_render_module_rounded_side_h_5, v_render_module_rounded_side_h_0, v_render_module_rounded_side_h_1, v_render_module_rounded_side_h_2, v_render_module_rounded_side_h_3)
	renderer.circle(render_module_rounded_side_h_self + a_render_module_rounded_side_h_2 - a_render_module_rounded_side_h_5, a_render_module_rounded_side_h_1 + a_render_module_rounded_side_h_5, v_render_module_rounded_side_h_0, v_render_module_rounded_side_h_1, v_render_module_rounded_side_h_2, v_render_module_rounded_side_h_3, a_render_module_rounded_side_h_5, 90, 0.25)
	renderer.rectangle(render_module_rounded_side_h_self, a_render_module_rounded_side_h_1 + a_render_module_rounded_side_h_5, a_render_module_rounded_side_h_2, a_render_module_rounded_side_h_3 - a_render_module_rounded_side_h_5, v_render_module_rounded_side_h_0, v_render_module_rounded_side_h_1, v_render_module_rounded_side_h_2, v_render_module_rounded_side_h_3)
end

local v_282_crosshair_widget = WidgetFactory.new("crosshair", scaled_screen_center.x - 24, scaled_screen_center.y + 32, 48, 16, {
	border = {
		real_screen_center.x,
		real_screen_center.y - 100,
		real_screen_center.x,
		real_screen_center.y + 100
	},
	rulers = {
		{
			true,
			real_screen_center.x,
			real_screen_center.y - 100,
			200
		}
	}
})

v_282_crosshair_widget.data, v_282_crosshair_widget.items = {
	scope = {
		reserved = false,
		side = 0,
		target = 0
	}
}, {}

function v_282_crosshair_widget.enumerate(crosshair_enumerate_self)
	local v_crosshair_enumerate_0 = scaled_screen_center.x
	local v_crosshair_enumerate_1 = crosshair_enumerate_self.y
	local v_crosshair_enumerate_2 = animation_module.condition("crosshair::yposition", crosshair_enumerate_self.y > scaled_screen_center.y, 3) * 2 - 1
	local v_crosshair_enumerate_3 = v_282_crosshair_widget.data.scope.side
	local v_crosshair_enumerate_4 = v_crosshair_enumerate_3 * 0.5 + 0.5

	for i, j in ipairs(crosshair_enumerate_self.items) do
		j[0] = j[0] or {
			0
		}

		render_module.push_alpha(j[1])

		local v_crosshair_enumerate_5, v_crosshair_enumerate_6, v_crosshair_enumerate_7 = j[2](j, v_crosshair_enumerate_0 + j.x, v_crosshair_enumerate_1)

		render_module.pop_alpha()

		j[1] = animation_module.condition(j[0], v_crosshair_enumerate_5, -8)
		j.x = v_crosshair_enumerate_6 * -v_crosshair_enumerate_4 - v_crosshair_enumerate_3 * 16
		v_crosshair_enumerate_1 = v_crosshair_enumerate_1 + v_crosshair_enumerate_7 * j[1] * v_crosshair_enumerate_2
	end

	return math.abs(v_crosshair_enumerate_1 - crosshair_enumerate_self.y)
end

v_282_crosshair_widget.items = {
	{
		0,
		function(f_358_alpha, f_358_x, f_358_y)
			if f_358_alpha[1] > 0 then
				local v_358_0 = animation_module.condition(f_358_alpha.bfly, gui.visuals.crosshair.logo.value, -8)

				if v_358_0 > 0 then
					render_module.texture(gfx_assets.butterfly_s, f_358_x - 3, f_358_y - 10, 32, 32, palette.accent:alphen(255 * v_358_0), "f")
				end

				render_module.logo(f_358_x, f_358_y)
			end

			return gui.visuals.crosshair.style.value == "Classic", _AZAZI and 66 or 48, 15
		end,
		desync = 0,
		x = 0,
		bfly = {
			0
		}
	},
	{
		0,
		function(f_359_alpha, f_359_x, f_359_y)
			local v_359_0 = gui.visuals.crosshair.logo.value
			local v_359_text_label = "pasteria" .. (not v_359_0 and config.level > 2 and palette.hexs .. string.format("%02x", render_module.get_alpha() * 255) .. string.upper(config.build) or "")
			local v_359_2, v_359_3 = render_module.measure_text("-", v_359_text_label)

			if gui.visuals.crosshair.logo.value then
				v_359_2 = v_359_2 + 7
			end

			if f_359_alpha[1] > 0 then
				render_module.text(f_359_x, f_359_y, palette.text, "-", nil, v_359_text_label)

				if gui.visuals.crosshair.logo.value then
					render_module.texture(gfx_assets.mini_bfly, f_359_x + v_359_2 - 6, f_359_y + 1, 9, 9, palette.accent)
				end
			end

			return gui.visuals.crosshair.style.value == "Mini", v_359_2, v_359_3 + 3
		end,
		x = 0,
		desync = 0
	},
	{
		0,
		function(f_360_alpha, f_360_x, f_360_y)
			local v_360_is_active = reference.rage.aimbot.double_tap[1].value and reference.rage.aimbot.double_tap[1].hotkey:get()

			if f_360_alpha[1] > 0 then
				local v_360_1 = LocalPawn.exploit.lc_left > 0 and 14 or aafunc.get_tickbase_shifting()
				local v_360_2 = aafunc.get_double_tap() or LocalPawn.exploit.lc_left > 0
				local v_360_is_active = animation_module.condition(f_360_alpha.fd, not reference.rage.other.duck:get(), -8)
				local v_360_4 = palette.hexs .. string.format("%02x", render_module.get_alpha() * 255) .. string.insert("llllll", string.format("\aFFFFFF%02x", (v_360_2 and 96 or 64) * render_module.get_alpha()), math.min(v_360_1 * 0.5, 6))
				local v_360_label_dt  = "DT " .. v_360_4

				render_module.text(f_360_x, f_360_y, palette.text:alphen(math.lerp(96, 255, v_360_is_active)), "-", nil, v_360_label_dt )
			end

			return v_360_is_active, render_module.measure_text("-", "DT llllll")
		end,
		x = 0,
		fd = {
			0
		}
	},
	{
		0,
		function(f_361_alpha, f_361_x, f_361_y)
			local v_361_is_active = not gui.visuals.damage.value and reference.rage.aimbot.damage_ovr[1].value and reference.rage.aimbot.damage_ovr[1].hotkey:get()
			local v_361_label_dmg = "DMG"

			if f_361_alpha[1] > 0 then
				render_module.text(f_361_x, f_361_y, palette.text, "-", nil, v_361_label_dmg)
			end

			return v_361_is_active, render_module.measure_text("-", v_361_label_dmg)
		end,
		x = 0
	},
	{
		0,
		function(f_362_alpha, f_362_x, f_362_y)
			local v_362_is_active = reference.rage.other.peek.value and reference.rage.other.peek.hotkey:get()
			local v_362_1 = aafunc.get_double_tap()
			local v_362_label_pa = "PA" .. (v_362_1 and "+" or "")

			if f_362_alpha[1] > 0 then
				local v_362_3 = animation_module.condition(f_362_alpha.ideal, v_362_1, -8)

				render_module.text(f_362_x, f_362_y, palette.text:lerp(palette.accent, v_362_3), "-", nil, v_362_label_pa)
			end

			return v_362_is_active, render_module.measure_text("-", v_362_label_pa)
		end,
		x = 0,
		ideal = {
			0
		}
	},
	{
		0,
		function(f_364_alpha, f_364_x, f_364_y)
			local v_364_hotkey_active = reference.aa.other.onshot.value and reference.aa.other.onshot:get_hotkey()
			local v_364_label_os = "OS"

			if f_364_alpha[1] > 0 then
				local v_364_hotkey_active = reference.rage.aimbot.double_tap[1].value and reference.rage.aimbot.double_tap[1]:get_hotkey()
				local v_364_3 = animation_module.condition(f_364_alpha.a1, not v_364_hotkey_active, 8)

				render_module.text(f_364_x, f_364_y, palette.text:alphen(math.lerp(96, 255, v_364_3)), "-", nil, v_364_label_os)
			end

			return v_364_hotkey_active, render_module.measure_text("-", v_364_label_os)
		end,
		x = 0,
		a1 = {
			0
		}
	},
	{
		0,
		function(f_365_alpha, f_365_x, f_365_y)
			local v_365_is_active = reference.rage.aimbot.force_baim:get()
			local v_365_label_ba = "BA"

			if f_365_alpha[1] > 0 then
				render_module.text(f_365_x, f_365_y, palette.text, "-", nil, v_365_label_ba)
			end

			return v_365_is_active, render_module.measure_text("-", v_365_label_ba)
		end,
		x = 0
	},
	{
		0,
		function(f_366_alpha, f_366_x, f_366_y)
			local v_366_is_active = reference.rage.aimbot.force_sp:get()
			local v_366_label_sp = "SP"

			if f_366_alpha[1] > 0 then
				render_module.text(f_366_x, f_366_y, palette.text, "-", nil, v_366_label_sp)
			end

			return v_366_is_active, render_module.measure_text("-", v_366_label_sp)
		end,
		x = 0
	},
	{
		0,
		function(f_367_alpha, f_367_x, f_367_y)
			local v_367_hotkey_active = reference.aa.angles.freestand.value and reference.aa.angles.freestand:get_hotkey()
			local v_367_label_fs = "FS"

			if f_367_alpha[1] > 0 then
				render_module.text(f_367_x, f_367_y, palette.text, "-", nil, v_367_label_fs)
			end

			return v_367_hotkey_active, render_module.measure_text("-", v_367_label_fs)
		end,
		x = 0
	},
	{
		0,
		function(f_368_alpha, f_368_x, f_368_y)
			local v_368_hotkey_active, v_368_hotkey_mode = reference.misc.ping_spike.hotkey:get()
			local v_368_is_active = reference.misc.ping_spike.value and v_368_hotkey_active and v_368_hotkey_mode ~= 0
			local v_368_label_ps = "PS"

			if f_368_alpha[1] > 0 then
				render_module.text(f_368_x, f_368_y, palette.text, "-", nil, v_368_label_ps)
			end

			return v_368_is_active, render_module.measure_text("-", v_368_label_ps)
		end,
		x = 0
	},
	{
		0,
		function(f_369_alpha, f_369_x, f_369_y)
			local v_369_is_active = reference.rage.other.duck:get()
			local v_369_label_fd = "FD"

			if f_369_alpha[1] > 0 then
				local v_369_duck_amount = LocalPawn.valid and entity.get_prop(LocalPawn.self, "m_flDuckAmount") or 0

				render_module.text(f_369_x, f_369_y, palette.text:lerp(palette.accent, v_369_duck_amount), "-", nil, v_369_label_fd)
			end

			return v_369_is_active, render_module.measure_text("-", v_369_label_fd)
		end,
		x = 0
	}
}

function v_282_crosshair_widget.update(crosshair_update_self)
	if LocalPawn.valid and entity.get_prop(LocalPawn.self, "m_bIsScoped") == 1 then
		if not crosshair_update_self.data.scope.reserved and LocalPawn.side ~= 0 then
			crosshair_update_self.data.scope.target, crosshair_update_self.data.scope.reserved = -LocalPawn.side, true
		end
	else
		crosshair_update_self.data.scope.target, crosshair_update_self.data.scope.reserved = 0, false
	end

	crosshair_update_self.data.scope.side = animation_module.lerp(v_282_crosshair_widget.data.scope.side, v_282_crosshair_widget.data.scope.target, 12)

	return animation_module.condition(v_282_crosshair_widget.progress, gui.visuals.crosshair.on.value and LocalPawn.valid and not LocalPawn.in_score)
end

function v_282_crosshair_widget.paint(crosshair_paint_self, crosshair_paint_x, crosshair_paint_y, crosshair_paint_w, crosshair_paint_h)
	v_282_crosshair_widget:enumerate()
end

local widgets = {
	watermark = WidgetFactory.new("watermark", scaled_screen_width - 24, 24, 160, 24, {
		rulers = {
			{
				true,
				real_screen_center.x,
				0,
				real_screen_height
			},
			{
				false,
				0,
				real_screen_height - 32,
				real_screen_width
			},
			{
				false,
				0,
				32,
				real_screen_width
			}
		},
		on_release = function(on_release_self, a_on_release_1)
			local v_on_release_0 = scaled_screen_width / 3
			local v_on_release_1 = on_release_self.x + on_release_self.w * 0.5
			local v_on_release_2 = math.floor(v_on_release_1 / v_on_release_0)

			if v_on_release_2 == on_release_self.align then
				return
			end

			on_release_self.align = v_on_release_2

			if on_release_self.align == 1 then
				on_release_self:set_position(v_on_release_1)

				on_release_self.x = on_release_self.x - on_release_self.w * 0.5
			elseif on_release_self.align == 2 then
				on_release_self:set_position(on_release_self.x + on_release_self.w)

				on_release_self.x = on_release_self.x - on_release_self.w
			end

			a_on_release_1.config.a:set(v_on_release_2)
		end,
		on_held = function(a_on_held_0, a_on_held_1)
			a_on_held_0.align = 0

			a_on_held_1.config.a:set(0)
		end
	})
}

widgets.watermark.align, widgets.watermark.logop, widgets.watermark.logo = 2, {
	0
}, 0
widgets.watermark.__drag.config.a = hui.slider("MISC", "Settings", "watermark:align", 0, 2, widgets.watermark.align)

widgets.watermark.__drag.config.a:set_visible(false)
widgets.watermark.__drag.config.a:set_callback(function(f_374_self)
	widgets.watermark.align = f_374_self.value
end, true)

widgets.watermark.items = {
	{
		0,
		function(f_375_alpha, f_375_x, f_375_y)
			local v_375_is_active = gui.visuals.water.name:get()
			local v_375_1 = string.format(config.build == "stable" and "%s" or "%s %s%02x— %s", v_375_is_active ~= "" and v_375_is_active or config.user, palette.hexs, render_module.get_alpha() * f_375_alpha[1] * 255, config.build)
			local v_375_2, v_375_3 = render_module.measure_text("", v_375_1)

			if f_375_alpha[1] > 0 then
				render_module.blur(f_375_x, f_375_y + 1, v_375_2 + 16, 22, 1, 8)
				render_module.rectangle(f_375_x, f_375_y + 1, v_375_2 + 16, 22, palette.panel.l1, 4)
				render_module.text(f_375_x + 8, f_375_y + 6, palette.text, nil, nil, v_375_1)
			end

			return true, v_375_2 + 16
		end,
		{}
	},
	{
		0,
		function(f_376_alpha, f_376_x, f_376_y)
			local v_376_0, v_376_1 = client.system_time()
			local v_376_2 = string.format("%02d:%02d", v_376_0, v_376_1)
			local v_376_3, v_376_4 = render_module.measure_text("", v_376_2)

			if f_376_alpha[1] > 0 then
				render_module.blur(f_376_x, f_376_y + 1, v_376_3 + 16, 22, 1, 8)
				render_module.rectangle(f_376_x, f_376_y + 1, v_376_3 + 16, 22, palette.panel.l1, 4)
				render_module.text(f_376_x + 8, f_376_y + 6, palette.text, nil, nil, v_376_2)
			end

			return true, v_376_3 + 16
		end,
		{}
	},
	{
		0,
		function(f_377_alpha, f_377_x, f_377_y)
			local v_377_0 = client.latency() * 1000
			local v_377_1 = string.format("%dms", v_377_0)
			local v_377_2, v_377_3 = render_module.measure_text("", v_377_1)

			if f_377_alpha[1] > 0 then
				render_module.blur(f_377_x, f_377_y + 1, v_377_2 + 16, 22, 1, 8)
				render_module.rectangle(f_377_x, f_377_y + 1, v_377_2 + 16, 22, palette.panel.l1, 4)
				render_module.text(f_377_x + 8, f_377_y + 6, palette.text, nil, nil, v_377_1)
			end

			return v_377_0 > 5, v_377_2 + 16
		end,
		{}
	}
}

function widgets.watermark.enumerate(watermark_enumerate_self)
	local v_watermark_enumerate_0 = watermark_enumerate_self.logo * 68

	for i, j in ipairs(watermark_enumerate_self.items) do
		render_module.push_alpha(j[1])

		local v_watermark_enumerate_1, v_watermark_enumerate_2 = j[2](j, watermark_enumerate_self.x + v_watermark_enumerate_0, watermark_enumerate_self.y)

		render_module.pop_alpha()

		j[1] = animation_module.condition(j[3], v_watermark_enumerate_1)
		v_watermark_enumerate_0 = v_watermark_enumerate_0 + (v_watermark_enumerate_2 + 2) * j[1]
	end

	watermark_enumerate_self.w = animation_module.lerp(watermark_enumerate_self.w, v_watermark_enumerate_0, nil, 0.5)
end

function widgets.watermark.update(watermark_update_self)
	local v_watermark_update_0, v_watermark_update_1 = watermark_update_self:get_position()

	if watermark_update_self.align == 2 then
		watermark_update_self.x = v_watermark_update_0 - watermark_update_self.w * watermark_update_self.alpha
	elseif watermark_update_self.align == 1 then
		watermark_update_self.x = v_watermark_update_0 - watermark_update_self.w * 0.5
	end

	return animation_module.condition(watermark_update_self.progress, gui.visuals.water.on.value, 3)
end

function widgets.watermark.paint(watermark_paint_self, watermark_paint_x, watermark_paint_y, watermark_paint_w, watermark_paint_h)
	watermark_paint_self.logo = animation_module.condition(watermark_paint_self.logop, not gui.visuals.water.hide.value)

	if watermark_paint_self.logo > 0 then
		local v_watermark_paint_0 = 64

		render_module.push_alpha(watermark_paint_self.logo)
		render_module.blur(watermark_paint_x, watermark_paint_y, v_watermark_paint_0, watermark_paint_h, 1, 8)
		render_module.rounded_side_v(watermark_paint_x, watermark_paint_y, v_watermark_paint_0, watermark_paint_h, palette.panel.g1, 4)
		render_module.rectangle(watermark_paint_x + v_watermark_paint_0, watermark_paint_y, 2, watermark_paint_h, palette.panel.g1)
		render_module.logo(watermark_paint_x + 8, watermark_paint_y + 5)
		render_module.edge_v(watermark_paint_x + v_watermark_paint_0, watermark_paint_y, 24)
		render_module.pop_alpha()
	end

	watermark_paint_self:enumerate()
end

widgets.damage = WidgetFactory.new("damage", scaled_screen_center.x + 4, scaled_screen_center.y + 4, 6, 4, {
	border = {
		real_screen_center.x - 40,
		real_screen_center.y - 40,
		real_screen_center.x + 40,
		real_screen_center.y + 40,
		true
	}
})
widgets.damage.dmg = reference.rage.aimbot.damage.value
widgets.damage.ovr_alpha = 0
widgets.damage.ovr_alpha_p = {
	0
}

function widgets.damage.update(damage_update_self)
	if not gui.visuals.damage.value then
		return animation_module.condition(damage_update_self.progress, false, -4)
	end

	local damage_update_hotkey_active = reference.rage.aimbot.damage_ovr[1].value and reference.rage.aimbot.damage_ovr[1]:get_hotkey()
	local v_damage_update_1 = damage_update_hotkey_active and reference.rage.aimbot.damage_ovr[2].value or reference.rage.aimbot.damage.value

	damage_update_self.dmg = animation_module.lerp(damage_update_self.dmg, v_damage_update_1, 16)
	damage_update_self.ovr_alpha = animation_module.condition(widgets.damage.ovr_alpha_p, damage_update_hotkey_active, -8)

	local damage_update_weapon_data = LocalPawn.weapon_t
	local damage_update_weapon_type = damage_update_weapon_data and damage_update_weapon_data.weapon_type_int ~= 9 and damage_update_weapon_data.weapon_type_int ~= 0

	return animation_module.condition(damage_update_self.progress, LocalPawn.valid and (damage_update_weapon_type or hui.menu_open) and not LocalPawn.in_score and LocalPawn.in_game, -8)
end

function widgets.damage.paint(damage_paint_self, damage_paint_x, damage_paint_y, damage_paint_w, damage_paint_h)
	local v_damage_paint_0 = math.round(damage_paint_self.dmg)

	v_damage_paint_0 = v_damage_paint_0 == 0 and "A" or v_damage_paint_0 > 100 and "+" .. v_damage_paint_0 - 100 or tostring(v_damage_paint_0)
	damage_paint_self.w, damage_paint_self.h = render_module.measure_text("-", v_damage_paint_0)
	damage_paint_self.h, damage_paint_self.w = damage_paint_self.h - 3, damage_paint_self.w + 1

	render_module.text(damage_paint_x - 1, damage_paint_y - 2, palette.text:alphen(math.lerp(96, 255, damage_paint_self.ovr_alpha)), "-", nil, v_damage_paint_0)
end

widgets.arrows = WidgetFactory.new("arrows", scaled_screen_center.x - 32, scaled_screen_center.y - 5, 10, 10, {
	border = {
		real_screen_center.x - 120,
		real_screen_center.y + 1,
		real_screen_center.x - 10,
		real_screen_center.y + 1
	},
	rulers = {
		{
			false,
			real_screen_center.x - 120,
			real_screen_center.y,
			110
		}
	}
})
widgets.arrows.leftp, widgets.arrows.rightp = {
	0
}, {
	0
}

function widgets.arrows.update(arrows_update_self)
	return animation_module.condition(arrows_update_self.progress, gui.visuals.arrows.value and LocalPawn.in_game and LocalPawn.valid)
end

function widgets.arrows.paint(arrows_paint_self, arrows_paint_x, arrows_paint_y, arrows_paint_w, arrows_paint_h)
	local v_arrows_paint_0 = hui.menu_open and palette.white:alphen(128) or palette.null
	local v_arrows_paint_1 = animation_module.condition(widgets.arrows.leftp, AntiAim.data.manual_yaw == -90, 6)

	render_module.texture(gfx_assets.manual, arrows_paint_x, arrows_paint_y, 10, 10, v_arrows_paint_0:lerp(palette.accent, v_arrows_paint_1), "f")

	local v_arrows_paint_2 = animation_module.condition(widgets.arrows.rightp, AntiAim.data.manual_yaw == 90, 6)

	render_module.texture(gfx_assets.manual, scaled_screen_width - arrows_paint_x + 1, arrows_paint_y, -10, 10, v_arrows_paint_0:lerp(palette.accent, v_arrows_paint_2), "f")
end

widgets.slowdown = WidgetFactory.new("slowdown", scaled_screen_center.x - 60, scaled_screen_center.y - 160, 120, 32, {
	rulers = {
		{
			true,
			real_screen_center.x,
			0,
			real_screen_height
		}
	}
})
widgets.slowdown.speed = 0.5

function widgets.slowdown.update(slowdown_update_self)
	if not gui.visuals.slowdown.value or not LocalPawn.valid then
		return animation_module.condition(slowdown_update_self.progress, false, -4)
	end

	slowdown_update_self.speed = entity.get_prop(LocalPawn.self, "m_flVelocityModifier")

	return animation_module.condition(slowdown_update_self.progress, hui.menu_open or LocalPawn.valid and slowdown_update_self.speed < 1, -8)
end

function widgets.slowdown.paint(slowdown_paint_self, slowdown_paint_x, slowdown_paint_y, slowdown_paint_w, slowdown_paint_h)
	local v_slowdown_paint_0 = ColorUtils.rgb(240, 60, 60):lerp(palette.text, slowdown_paint_self.speed)

	render_module.blur(slowdown_paint_x + 36, slowdown_paint_y + 1, slowdown_paint_w - 36, slowdown_paint_h - 2)
	render_module.rectangle(slowdown_paint_x + 36, slowdown_paint_y + 1, slowdown_paint_w - 36, slowdown_paint_h - 2, palette.panel.l1, 4)
	render_module.blur(slowdown_paint_x, slowdown_paint_y, 32, slowdown_paint_h, 1, 8)
	render_module.rounded_side_v(slowdown_paint_x, slowdown_paint_y, 32, slowdown_paint_h, palette.panel.g1, 4)
	render_module.rectangle(slowdown_paint_x + 32, slowdown_paint_y, 2, slowdown_paint_h, palette.panel.g1)
	render_module.texture(gfx_assets.warning, slowdown_paint_x + 8, slowdown_paint_y + 8, 16, 16, v_slowdown_paint_0)
	render_module.edge_v(slowdown_paint_x + 32, slowdown_paint_y, slowdown_paint_h)
	render_module.text(slowdown_paint_x + 44, slowdown_paint_y + 6, palette.text:alphen((1 - slowdown_paint_self.speed) * 196 + 64), nil, nil, "slowed")
	render_module.text(slowdown_paint_x + slowdown_paint_w - 8, slowdown_paint_y + 6, v_slowdown_paint_0, "r", nil, string.format("%d%%", slowdown_paint_self.speed * 100))
	render_module.rectangle(slowdown_paint_x + 44, slowdown_paint_y + 21, 67, 2, palette.white:alphen(32))
	render_module.rectangle(slowdown_paint_x + 44, slowdown_paint_y + 21, slowdown_paint_self.speed * 67, 2, palette.accent:alphen(slowdown_paint_self.speed * 196 + 58))
end

widgets.logs = WidgetFactory.new("logs", scaled_screen_center.x - 150, scaled_screen_center.y + 160, 300, 32, {
	rulers = {
		{
			true,
			real_screen_center.x,
			0,
			real_screen_height
		}
	}
})
widgets.logs.align_p, widgets.logs.preview_p = {
	0
}, {
	0
}
widgets.logs.preview, widgets.logs.dummy = false, {
	{
		text = "\aA3D350\x01•\aE6E6E6\x02 Killed\aE6E6E6\x02 \aE6E6E6\x02\aE6E6E6\x01Nironi\aE6E6E6\x02 in \aE6E6E6\x02\aE6E6E6\x01head\aE6E6E6\x02\aE6E6E6\x02",
		event = "hit",
		time = math.huge,
		progress = {
			0
		}
	},
	{
		text = "\aA67CCF\x01•\aE6E6E6\x02 Missed\aE6E6E6\x02 \aE6E6E6\x01Sgji kev\aE6E6E6\x02's\aE6E6E6\x01 head\aE6E6E6\x02 due to \aE6E6E6\x01unpredicted occasion",
		event = "miss",
		time = math.huge,
		progress = {
			0
		}
	},
	{
		text = "\aB3B3B3\x01•\aE6E6E6\x02 ab \aE6E6E6\x01->\aE6E6E6\x02 L: \aE6E6E6\x01+1.5°\aE6E6E6\x02/\aE6E6E6\x01-15%\aE6E6E6\x02 | R: \aE6E6E6\x01-2.0°\aE6E6E6\x02/\aE6E6E6\x01+30%\aE6E6E6\x02 \aCDCDCD\x01(1.0s)",
		event = "ab",
		time = math.huge,
		progress = {
			0
		}
	},
	{
		text = "\ad35050\x01•\aE6E6E6\x02 Harmed by\aE6E6E6\x02 \aE6E6E6\x01nezapomnyat\aE6E6E6\x02 in \aE6E6E6\x01head\aE6E6E6\x02 for \aE6E6E6\x0172",
		event = "harm",
		time = math.huge,
		progress = {
			0
		}
	}
}

function widgets.logs.update(logs_update_self)
	return animation_module.condition(logs_update_self.progress, gui.misc.logs.on.value and gui.misc.logs.output:get("Screen") and LocalPawn.in_game)
end

function widgets.logs.part(logs_part_self, a_logs_part_1, a_logs_part_2, a_logs_part_3, a_logs_part_4, a_logs_part_5)
	local v_logs_part_0 = string.gsub(a_logs_part_1.text, "[\x01\x02]", {
		["\x01"] = string.format("%02x", a_logs_part_3 * render_module.get_alpha() * 255),
		["\x02"] = string.format("%02x", a_logs_part_3 * render_module.get_alpha() * 128)
	})
	local v_logs_part_1, v_logs_part_2 = render_module.measure_text("", v_logs_part_0)
	
	if not a_logs_part_1.w then
		a_logs_part_1.w = v_logs_part_1
	else
		a_logs_part_1.w = animation_module.lerp(a_logs_part_1.w, v_logs_part_1, 30, 0.5)
	end
	v_logs_part_1 = a_logs_part_1.w

	local v_logs_part_3 = math.lerp(logs_part_self.x + logs_part_self.w * 0.5 - v_logs_part_1 * 0.5 - 18, logs_part_self.x, logs_part_self.align)
	local v_logs_part_4 = a_logs_part_2

	if not a_logs_part_4 then
		v_logs_part_3 = v_logs_part_3 + (1 - a_logs_part_3) * (v_logs_part_1 * 0.5) * (a_logs_part_5 % 2 == 0 and -1 or 1)
	end

	render_module.blur(v_logs_part_3, v_logs_part_4, 24, 24)
	render_module.rounded_side_v(v_logs_part_3, v_logs_part_4, 24, 24, palette.panel.g1, 4)
	render_module.rectangle(v_logs_part_3 + 24, v_logs_part_4, 2, 24, palette.panel.g1)
	render_module.edge_v(v_logs_part_3 + 24, v_logs_part_4, 24)
	render_module.blur(v_logs_part_3 + 28, v_logs_part_4 + 1, v_logs_part_1 + 14, 22)
	render_module.rectangle(v_logs_part_3 + 28, v_logs_part_4 + 1, v_logs_part_1 + 14, 22, palette.panel.l1, 4)
	render_module.texture(gfx_assets.mini_bfly, v_logs_part_3 + 8, v_logs_part_4 + 8, 9, 9, palette.accent)
	render_module.text(v_logs_part_3 + 35, v_logs_part_4 + 5, palette.text:alphen(128), nil, nil, v_logs_part_0)
end

function widgets.logs.paint(logs_paint_self, logs_paint_x, logs_paint_y, logs_paint_w, logs_paint_h)
	if not gui.misc.logs.on.value then
		return
	end

	local v_logs_paint_0

	logs_paint_self.align = animation_module.condition(widgets.logs.align_p, logs_paint_self.x < scaled_screen_width / 3)
	logs_paint_self.preview = animation_module.condition(widgets.logs.preview_p, hui.menu_open and gui.misc.logs.output:get("Screen") and #eventLogger.list == 0)
	logs_paint_y = logs_paint_y + 4

	local v_logs_paint_1 = logs_paint_self.preview > 0 and logs_paint_self.dummy or eventLogger.list

	if logs_paint_self.preview > 0 and logs_paint_self.dummy and logs_paint_self.dummy[3] then
		if gui.antiaim.ab and gui.antiaim.ab.split and gui.antiaim.ab.split:get() then
			logs_paint_self.dummy[3].text = "\aB3B3B3\x01•\aE6E6E6\x02 ab \aE6E6E6\x01->\aE6E6E6\x02 L: \aE6E6E6\x01+1.5°\aE6E6E6\x02/\aE6E6E6\x01-15%\aE6E6E6\x02 | R: \aE6E6E6\x01-2.0°\aE6E6E6\x02/\aE6E6E6\x01+30%\aE6E6E6\x02 \aCDCDCD\x01(1.0s)"
		else
			logs_paint_self.dummy[3].text = "\aB3B3B3\x01•\aE6E6E6\x02 ab \aE6E6E6\x01->\aE6E6E6\x02 \aE6E6E6\x01+1.5°\aE6E6E6\x02/\aE6E6E6\x01-15%\aE6E6E6\x02 \aCDCDCD\x01(1.0s)"
		end
	end

	for i = 1, #v_logs_paint_1 do
		local v_logs_paint_2 = v_logs_paint_1[i]
		local v_logs_paint_3 = globals.realtime() - v_logs_paint_2.time < 4 and i < 10
		local v_logs_paint_4 = animation_module.condition(v_logs_paint_2.progress, iif(logs_paint_self.preview > 0, logs_paint_self.preview == 1, v_logs_paint_3))

		if v_logs_paint_4 == 0 then
			v_logs_paint_0 = i
		end

		render_module.push_alpha(v_logs_paint_4)
		logs_paint_self:part(v_logs_paint_2, logs_paint_y, v_logs_paint_4, v_logs_paint_3, i)
		render_module.pop_alpha()

		logs_paint_y = logs_paint_y + 28 * (v_logs_paint_3 and v_logs_paint_4 or 1)
	end

	if v_logs_paint_0 then
		table.remove(eventLogger.list, v_logs_paint_0)
	end
end

widgets.keylist = WidgetFactory.new("keylist", scaled_screen_center.x - 400, scaled_screen_center.y, 120, 22, true)
widgets.keylist.binds = {
	{
		name = "Minimum damage",
		ref = reference.rage.aimbot.damage_ovr[1],
		state = function()
			return reference.rage.aimbot.damage_ovr[2].value
		end
	},
	{
		name = "Double tap",
		ref = reference.rage.aimbot.double_tap[1]
	},
	{
		name = "Hide shots",
		ref = reference.aa.other.onshot
	},
	{
		name = "Quick peek",
		ref = reference.rage.other.peek
	},
	{
		name = "Defensive snap",
		ref = gui.antiaim.def.snap.on
	},
	{
		name = "Manual yaw",
		ref = function()
			return AntiAim.data.manual_yaw
		end,
		state = function()
			return AntiAim.data.manual_yaw == -90 and "left" or AntiAim.data.manual_yaw == 90 and "right" or "~"
		end
	},
	{
		name = "Edge yaw",
		ref = reference.aa.angles.edge
	},
	{
		name = "Freestanding",
		ref = reference.aa.angles.freestand
	}
}

widgets.keylist:enlist(function()
	local v_393_0 = {}

	for i = 1, #widgets.keylist.binds do
		local v_393_1 = widgets.keylist.binds[i]
		local v_393_2 = false
		local v_393_label_on = "on"

		if type(v_393_1.ref) == "function" then
			v_393_2 = v_393_1.ref()
		elseif v_393_1.ref ~= nil then
			v_393_2 = v_393_1.ref.value

			if v_393_1.ref.hotkey then
				local v_393_hotkey_active, v_393_hotkey_mode = v_393_1.ref.hotkey:get()

				v_393_2 = v_393_2 and v_393_hotkey_active and v_393_hotkey_mode ~= 0
			end
		end

		if v_393_1.state then
			if type(v_393_1.state) == "function" then
				v_393_label_on = v_393_1.state()
			else
				v_393_label_on = v_393_1.state
			end
		end

		v_393_0[i] = {
			name = v_393_1.name,
			active = v_393_2,
			state = v_393_label_on
		}
	end

	return v_393_0
end, function(f_394_self, a_394_1, a_394_2, a_394_3)
	local v_394_0 = f_394_self.x + 4
	local v_394_1 = f_394_self.y + a_394_2 + (f_394_self.h + 6) * a_394_3
	local v_394_2 = f_394_self.w - 8
	local v_394_3 = 20

	render_module.blur(v_394_0, v_394_1, v_394_2, v_394_3)
	render_module.rectangle(v_394_0, v_394_1, v_394_2, v_394_3, palette.panel.l1, 4)
	render_module.text(v_394_0 + 6, v_394_1 + 3, palette.text, nil, nil, a_394_1.name)
	render_module.text(v_394_0 + v_394_2 - 6, v_394_1 + 3, palette.accent, "r", nil, a_394_1.state)

	return render_module.measure_text(nil, a_394_1.name .. a_394_1.state) + 32, v_394_3 + 2
end)

function widgets.keylist.update(keylist_update_self)
	return animation_module.condition(keylist_update_self.progress, gui.visuals.keylist.value and (hui.menu_open or keylist_update_self.__list.active > 0))
end

function widgets.keylist.paint(keylist_paint_self, keylist_paint_x, keylist_paint_y, keylist_paint_w, keylist_paint_h)
	render_module.blur(keylist_paint_x, keylist_paint_y, keylist_paint_w, keylist_paint_h)
	render_module.rounded_side_h(keylist_paint_x, keylist_paint_y, keylist_paint_w, keylist_paint_h, palette.panel.g1, 4)
	render_module.edge_h(keylist_paint_x, keylist_paint_y + keylist_paint_h, keylist_paint_w)
	render_module.text(keylist_paint_x + keylist_paint_w * 0.5, keylist_paint_y + 11, palette.text, "c", nil, "Hotkeys")
end

widgets.speclist = WidgetFactory.new("speclist", scaled_screen_center.x - 400, scaled_screen_center.y, 120, 22, true)

widgets.speclist:enlist(function()
	local v_397_0 = {}

	if LocalPawn.valid then
		local v_397_1
		local v_397_2 = entity.get_prop(LocalPawn.self, "m_hObserverTarget")
		local v_397_3 = entity.get_prop(LocalPawn.self, "m_iObserverMode")

		if v_397_2 and (v_397_3 == 4 or v_397_3 == 5) then
			v_397_1 = v_397_2
		else
			v_397_1 = LocalPawn.self
		end

		for i = 1, 64 do
			if entity.get_classname(i) == "CCSPlayer" and i ~= LocalPawn.self then
				local v_397_4 = entity.get_prop(i, "m_hObserverTarget")
				local v_397_5 = entity.get_prop(i, "m_iObserverMode")

				v_397_0[#v_397_0 + 1] = {
					name = i,
					nick = string.limit(entity.get_player_name(i), 20, "..."),
					active = v_397_4 and v_397_4 == v_397_1 and (v_397_5 == 4 or v_397_5 == 5)
				}
			end
		end
	end

	return v_397_0
end, function(f_398_self, a_398_1, a_398_2, a_398_3)
	local v_398_0 = f_398_self.x + 4
	local v_398_1 = f_398_self.y + a_398_2 + (f_398_self.h + 6) * a_398_3
	local v_398_2 = f_398_self.w - 8
	local v_398_3 = 20

	render_module.blur(v_398_0, v_398_1, v_398_2, v_398_3)
	render_module.rectangle(v_398_0, v_398_1, v_398_2, v_398_3, palette.panel.l1, 4)
	render_module.text(v_398_0 + 6, v_398_1 + 3, palette.text, nil, nil, a_398_1.nick)

	return render_module.measure_text(nil, a_398_1.nick) + 32, v_398_3 + 2
end)

function widgets.speclist.update(speclist_update_self)
	return animation_module.condition(speclist_update_self.progress, gui.visuals.speclist.value and (hui.menu_open or speclist_update_self.__list.active > 0))
end

function widgets.speclist.paint(speclist_paint_self, speclist_paint_x, speclist_paint_y, speclist_paint_w, speclist_paint_h)
	render_module.blur(speclist_paint_x, speclist_paint_y, speclist_paint_w, speclist_paint_h)
	render_module.rounded_side_h(speclist_paint_x, speclist_paint_y, speclist_paint_w, speclist_paint_h, palette.panel.g1, 4)
	render_module.edge_h(speclist_paint_x, speclist_paint_y + speclist_paint_h, speclist_paint_w)
	render_module.text(speclist_paint_x + speclist_paint_w * 0.5, speclist_paint_y + 11, palette.text, "c", nil, string.format("Spectators (%d)", speclist_paint_self.__list.active))
end

widgets.debugger = WidgetFactory.new("debugger", scaled_screen_center.x - 50, scaled_screen_center.y + 100, 100, 90, true)

function widgets.debugger.update(debugger_update_self)
	return animation_module.condition(debugger_update_self.progress, gui.visuals.debugger.value and (hui.menu_open or LocalPawn.in_game and LocalPawn.valid))
end

local function get_angle_pos(cx, cy, radius, yaw, camera_yaw)
	local angle_rad = math.rad(yaw - camera_yaw - 90)
	return cx + radius * math.cos(angle_rad), cy + radius * math.sin(angle_rad)
end

function widgets.debugger.paint(debugger_paint_self, debugger_paint_x, debugger_paint_y, debugger_paint_w, debugger_paint_h)
	local cx = debugger_paint_x + debugger_paint_w * 0.5
	local cy = debugger_paint_y + debugger_paint_h * 0.5 - 5
	local r = 25

	local camera_yaw = 0
	local real_yaw = 180
	local desync_val = -60

	if LocalPawn.in_game and LocalPawn.valid then
		local _, cam_yaw = client.camera_angles()
		if cam_yaw then
			if LocalPawn.threat and aa_state.threat_ang and aa_state.threat_ang[2] then
				camera_yaw = aa_state.threat_ang[2]
			else
				camera_yaw = cam_yaw
			end
			real_yaw = aa_state.debug_real_yaw or 0
			if aa_state.freestanding then
				real_yaw = real_yaw + 180
			end
			desync_val = final_angles.des or 0
		end
	end

	local fake_yaw = real_yaw - desync_val

	-- Draw glassmorphic background
	render_module.blur(debugger_paint_x, debugger_paint_y, debugger_paint_w, debugger_paint_h)
	render_module.rounded_side_h(debugger_paint_x, debugger_paint_y, debugger_paint_w, debugger_paint_h, palette.panel.g1, 4)

	-- Draw circle background
	render_module.circle(cx, cy, ColorUtils.rgb(5, 6, 8, 96), r)
	render_module.circle_outline(cx, cy, ColorUtils.rgb(255, 255, 255, 20), r + 2, 0, 1, 1)

	-- Calculate positions for Real and Fake indicators
	local rx, ry = get_angle_pos(cx, cy, r, real_yaw, camera_yaw)
	local fx, fy = get_angle_pos(cx, cy, r, fake_yaw, camera_yaw)

	-- Draw Real line and indicator
	render_module.line(cx, cy, rx, ry, ColorUtils(235, 75, 75))
	render_module.circle(rx, ry, ColorUtils(235, 75, 75), 3)
	render_module.circle_outline(rx, ry, palette.white, 3, 0, 1, 1)

	-- Draw Fake line and indicator
	render_module.line(cx, cy, fx, fy, palette.accent)
	render_module.circle(fx, fy, palette.accent, 3)
	render_module.circle_outline(fx, fy, palette.white, 3, 0, 1, 1)

	-- Draw small center dot
	render_module.circle(cx, cy, palette.white:alphen(220), 1.5)

	-- Draw text info
	local desync_abs = math.floor(math.abs(desync_val) + 0.5)
	local side_suffix = ""
	if desync_abs > 1 then
		side_suffix = desync_val > 0 and " [R]" or " [L]"
	end
	render_module.text(cx, cy + r + 12, palette.text, "c", nil, string.format("desync: %d°%s", desync_abs, side_suffix))
end

local function on_paint()
	if gui.visuals.water.on.value or widgets.watermark.alpha > 0 then
		widgets.watermark()
	end

	if gui.visuals.damage.value or widgets.damage.alpha > 0 then
		widgets.damage()
	end

	if gui.visuals.arrows.value or widgets.arrows.alpha > 0 then
		widgets.arrows()
	end

	if gui.visuals.slowdown.value or widgets.slowdown.alpha > 0 then
		widgets.slowdown()
	end

	if gui.misc.logs.on.value and gui.misc.logs.output:get("Screen") or widgets.logs.alpha > 0 then
		widgets.logs()
	end

	if gui.visuals.speclist.value or widgets.speclist.alpha > 0 then
		widgets.speclist()
	end

	if gui.visuals.keylist.value or widgets.keylist.alpha > 0 then
		widgets.keylist()
	end

	if gui.visuals.crosshair.on.value or v_282_crosshair_widget.alpha > 0 then
		v_282_crosshair_widget()
	end

	if gui.visuals.debugger.value or widgets.debugger.alpha > 0 then
		widgets.debugger()
	end
end

eventManager.paint_ui:set(on_paint)

if not config.isdebug then
	local splash_screen = {
		completing = false,
		state = true,
		progress = {
			{
				0
			},
			{
				0
			},
			{
				0
			}
		}
	}

	function splash_screen.render()
		local v_402_0 = animation_module.condition(splash_screen.progress[1], splash_screen.state, 2)
		local v_402_1 = animation_module.condition(splash_screen.progress[2], v_402_0 == 1, 2)

		render_module.rectangle(0, 0, scaled_screen_width, scaled_screen_height, palette.back:alphen(v_402_0 * 180))

		local v_402_2 = 400

		render_module.texture(gfx_assets.butterfly, scaled_screen_center.x - v_402_2 * 0.5, scaled_screen_center.y - v_402_2 * 0.5, v_402_2, v_402_2, palette.accent:alphen(v_402_1 * 255))

		if not splash_screen.completing then
			client.delay_call(3, function()
				if splash_screen then
					splash_screen.state = false
				end
			end)

			splash_screen.completing = true
		end
	end

	client.delay_call(1, function()
		eventManager.paint_ui:set(splash_screen.render)
	end)
	client.delay_call(6, function()
		eventManager.paint_ui:unset(splash_screen.render)

		splash_screen = nil
	end)
end

config_manager_state.system = hui.setup(gui)

local startup_config = storage.last_loaded_config or "Default"
if startup_config ~= "Default" and not databaseManager.configs[startup_config] then
	startup_config = "Default"
end
config_api.load(startup_config)
update_config_list_ui()
