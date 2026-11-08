-- Modified copy of Prosody's mod_auth_internal_hashed (MIT/X11, see Prosody's COPYING).
-- Selected with AUTH_TYPE=openfire (authentication = "openfire_hybrid"); it
-- accepts local accounts and also accounts that exist in Openfire. Local credentials are tried first; on failure the password is
-- verified against Openfire (direct-TLS c2s, SASL PLAIN, certificate and
-- hostname verified). A local record is created on the first success.
-- Settings come from the environment: OPENFIRE_AUTH_ENABLED, OPENFIRE_AUTH_HOST,
-- OPENFIRE_AUTH_PORT, OPENFIRE_AUTH_DOMAIN, OPENFIRE_AUTH_EXCLUDE.
-- Only SASL PLAIN is offered, because an external check cannot do SCRAM.
--
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- Copyright (C) 2010 Jeff Mitchell
--
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local max = math.max;

local scram_hashers = require "prosody.util.sasl.scram".hashers;
local generate_uuid = require "prosody.util.uuid".generate;
local new_sasl = require "prosody.util.sasl".new;
local hex = require"prosody.util.hex";
local to_hex, from_hex = hex.encode, hex.decode;
local saslprep = require "prosody.util.encodings".stringprep.saslprep;
local secure_equals = require "prosody.util.hashes".equals;

local log = module._log;
local host = module.host;

local accounts = module:open_store("accounts");

local hash_name = module:get_option_enum("password_hash", "SHA-1", "SHA-256");
local get_auth_db = assert(scram_hashers[hash_name], "SCRAM-"..hash_name.." not supported by SASL library");
local scram_name = "scram_"..hash_name:gsub("%-","_"):lower();

-- Default; can be set per-user
local default_iteration_count = module:get_option_integer("default_iteration_count", 10000, 4096);


-- define auth provider
local provider = {};

local function local_test_password(username, password)
	log("debug", "test password for user '%s'", username);
	local credentials = accounts:get(username) or {};
	if credentials.disabled then
		return nil, "Account disabled.";
	end
	password = saslprep(password);
	if not password then
		return nil, "Password fails SASLprep.";
	end

	if credentials.password ~= nil and string.len(credentials.password) ~= 0 then
		if not secure_equals(saslprep(credentials.password), password) then
			return nil, "Auth failed. Provided password is incorrect.";
		end

		if provider.set_password(username, credentials.password) == nil then
			return nil, "Auth failed. Could not set hashed password from plaintext.";
		else
			return true;
		end
	end

	if credentials.iteration_count == nil or credentials.salt == nil or string.len(credentials.salt) == 0 then
		return nil, "Auth failed. Stored salt and iteration count information is not complete.";
	end

	local valid, stored_key, server_key = get_auth_db(password, credentials.salt, credentials.iteration_count);

	local stored_key_hex = to_hex(stored_key);
	local server_key_hex = to_hex(server_key);

	if valid and secure_equals(stored_key_hex, credentials.stored_key) and secure_equals(server_key_hex, credentials.server_key) then
		return true;
	else
		return nil, "Auth failed. Invalid username, password, or password hash information.";
	end
end

local socket = require "socket";
local ssl = require "ssl";
local b64 = require "prosody.util.encodings".base64;
local x509 = require "prosody.util.x509";

local of_enabled = (os.getenv("OPENFIRE_AUTH_ENABLED") or "0"):lower();
of_enabled = of_enabled == "1" or of_enabled == "true" or of_enabled == "yes";
local of_host = os.getenv("OPENFIRE_AUTH_HOST") or "172.17.0.1";
local of_port = tonumber(os.getenv("OPENFIRE_AUTH_PORT") or "5223");
local of_domain = os.getenv("OPENFIRE_AUTH_DOMAIN") or "";
if of_domain == "" then of_enabled = false; end
local of_excluded = {};
for name in (os.getenv("OPENFIRE_AUTH_EXCLUDE") or "focus,jvb,jibri,recorder"):gmatch("[^,%s]+") do
	of_excluded[name:lower()] = true;
end

local function xml_escape(text)
	return (text:gsub("[&<>'\"]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["'"] = "&apos;", ['"'] = "&quot;" }));
end

local function read_until(sock, needles, limit)
	local buf = "";
	while #buf < limit do
		for _, needle in ipairs(needles) do
			if buf:find(needle, 1, true) then return buf, needle; end
		end
		local ch = sock:receive(1);
		if not ch then return buf, nil; end
		buf = buf .. ch;
	end
	return buf, nil;
end

local function openfire_check(username, password)
	local tcp = socket.tcp();
	tcp:settimeout(5);
	local connected, cerr = tcp:connect(of_host, of_port);
	if not connected then
		log("warn", "Openfire auth: cannot connect to %s:%d: %s", of_host, of_port, tostring(cerr));
		return nil;
	end
	local sock = ssl.wrap(tcp, {
		mode = "client", protocol = "any",
		options = { "all", "no_sslv2", "no_sslv3", "no_tlsv1", "no_tlsv1_1" },
		verify = { "peer" }, verifyext = { "lsec_continue", "lsec_ignore_purpose" },
		cafile = "/etc/ssl/certs/ca-certificates.crt",
	});
	sock:sni(of_domain);
	sock:settimeout(5);
	local hs_ok, hs_err = sock:dohandshake();
	if not hs_ok then
		log("warn", "Openfire auth: TLS handshake failed: %s", tostring(hs_err));
		sock:close();
		return nil;
	end
	local cert = sock:getpeercertificate();
	if not cert or not x509.verify_identity(of_domain, "xmpp-client", cert) then
		log("warn", "Openfire auth: certificate does not match %s", of_domain);
		sock:close();
		return nil;
	end
	sock:send("<?xml version='1.0'?><stream:stream to='" .. xml_escape(of_domain)
		.. "' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>");
	if not read_until(sock, { "</stream:features>" }, 16384) then
		sock:close();
		return nil;
	end
	local token = b64.encode("\0" .. username .. "\0" .. password);
	sock:send("<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>" .. token .. "</auth>");
	local _, found = read_until(sock, { "<success", "<failure" }, 4096);
	sock:send("</stream:stream>");
	sock:close();
	return found == "<success";
end

function provider.test_password(username, password)
	local ok, err = local_test_password(username, password);
	if ok then return ok; end
	if not of_enabled or of_excluded[username:lower()] then return ok, err; end
	local credentials = accounts:get(username);
	if credentials and credentials.disabled then return ok, err; end
	if openfire_check(username, password) then
		if not credentials then
			provider.create_user(username, generate_uuid());
			log("info", "Created local record for Openfire user '%s'", username);
		end
		log("debug", "Openfire accepted user '%s'", username);
		return true;
	end
	return ok, err;
end

function provider.set_password(username, password)
	log("debug", "set_password for username '%s'", username);
	local account = accounts:get(username);
	if account then
		account.salt = generate_uuid();
		account.iteration_count = max(account.iteration_count or 0, default_iteration_count);
		local valid, stored_key, server_key = get_auth_db(password, account.salt, account.iteration_count);
		if not valid then
			return valid, stored_key;
		end
		local stored_key_hex = to_hex(stored_key);
		local server_key_hex = to_hex(server_key);

		account.stored_key = stored_key_hex
		account.server_key = server_key_hex

		account.password = nil;
		account.updated = os.time();
		return accounts:set(username, account);
	end
	return nil, "Account not available.";
end

function provider.get_account_info(username)
	local account = accounts:get(username);
	if not account then return nil, "Account not available"; end
	return {
		created = account.created;
		password_updated = account.updated;
		enabled = not account.disabled;
	};
end

function provider.user_exists(username)
	local account = accounts:get(username);
	if not account then
		log("debug", "account not found for username '%s'", username);
		return nil, "Auth failed. Invalid username";
	end
	return true;
end

function provider.is_enabled(username) -- luacheck: ignore 212
	local info, err = provider.get_account_info(username);
	if not info then return nil, err; end
	return info.enabled;
end

function provider.enable(username)
	-- TODO map store?
	local account = accounts:get(username);
	account.disabled = nil;
	account.updated = os.time();
	return accounts:set(username, account);
end

function provider.disable(username, meta)
	local account = accounts:get(username);
	account.disabled = true;
	account.disabled_meta = meta;
	account.updated = os.time();
	return accounts:set(username, account);
end

function provider.users()
	return accounts:users();
end

function provider.create_user(username, password)
	local now = os.time();
	if password == nil then
		return accounts:set(username, { created = now; updated = now; disabled = true });
	end
	local salt = generate_uuid();
	local valid, stored_key, server_key = get_auth_db(password, salt, default_iteration_count);
	if not valid then
		return valid, stored_key;
	end
	local stored_key_hex = to_hex(stored_key);
	local server_key_hex = to_hex(server_key);
	return accounts:set(username, {
		stored_key = stored_key_hex, server_key = server_key_hex,
		salt = salt, iteration_count = default_iteration_count,
		created = now, updated = now;
	});
end

function provider.delete_user(username)
	return accounts:set(username, nil);
end

function provider.get_sasl_handler()
	local testpass_authentication_profile = {
		plain_test = function(_, username, password)
			return provider.test_password(username, password), provider.is_enabled(username);
		end,
	};
	return new_sasl(host, testpass_authentication_profile);
end

module:provides("auth", provider);

