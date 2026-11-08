-- Account registration endpoint for the jitsi-web /register page.
-- POST /user-api/register with JSON {"username": "...", "password": "..."}
-- creates a local account on this virtual host. Loaded only when
-- ENABLE_REGISTRATION is true; refuses when accounts live in Openfire.
module:depends("http");

local json = require "prosody.util.json";
local nodeprep = require "prosody.util.encodings".stringprep.nodeprep;
local usermanager = require "prosody.core.usermanager";

local host = module.host;
local auth_type = (os.getenv("AUTH_TYPE") or "internal"):lower();
local reserved = {};
for name in ("admin,administrator,root,system,guest,"
	.. (os.getenv("OPENFIRE_AUTH_EXCLUDE") or "focus,jvb,jibri,recorder")
	.. ",jigasi,transcriber"):gmatch("[^,%s]+") do
	reserved[name:lower()] = true;
end

local max_per_hour = module:get_option_number("user_api_max_per_hour", 5);
local attempts = {};

local function reply(response, code, body)
	response.status_code = code;
	response.headers.content_type = "application/json";
	return json.encode(body);
end

local function rate_limited(ip)
	local now = os.time();
	local entry = attempts[ip];
	if not entry or now - entry.start > 3600 then
		entry = { start = now, count = 0 };
		attempts[ip] = entry;
	end
	entry.count = entry.count + 1;
	return entry.count > max_per_hour;
end

local function register(event)
	local request, response = event.request, event.response;
	if auth_type ~= "internal" then
		return reply(response, 403, { error = "Registration is handled by the XMPP server" });
	end
	if rate_limited(request.ip or "unknown") then
		return reply(response, 429, { error = "Too many attempts, try again later" });
	end
	local data = request.body and json.decode(request.body);
	if type(data) ~= "table" or type(data.username) ~= "string" or type(data.password) ~= "string" then
		return reply(response, 400, { error = "username and password are required" });
	end
	local username = nodeprep(data.username:lower());
	if not username or not username:match("^[a-z0-9][a-z0-9._-]*$") or #username > 64 then
		return reply(response, 400, { error = "Invalid username" });
	end
	if reserved[username] then
		return reply(response, 403, { error = "This username is not allowed" });
	end
	if #data.password < 8 or #data.password > 256 then
		return reply(response, 400, { error = "Password must be 8 to 256 characters" });
	end
	if usermanager.user_exists(username, host) then
		return reply(response, 409, { error = "Username already taken" });
	end
	local ok, err = usermanager.create_user(username, data.password, host);
	if not ok then
		module:log("warn", "Registration of %s failed: %s", username, tostring(err));
		return reply(response, 500, { error = "Registration failed" });
	end
	module:log("info", "Registered account %s@%s", username, host);
	return reply(response, 201, { status = "created" });
end

module:provides("http", {
	default_path = "/user-api";
	route = { ["POST /register"] = register };
});
