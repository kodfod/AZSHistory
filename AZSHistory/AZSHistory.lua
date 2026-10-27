local ADDON = "AZSHistory";
local TITLE_FONT = "Fonts\\MORPHEUS.TTF";
local BODY_FONT = "Fonts\\FRIZQT__.TTF";
local WHITE = "Interface\\Buttons\\WHITE8X8";
local ICONS = "Interface\\Icons\\";
local QUESTION = "INV_Misc_QuestionMark";
local MAX_RUNS = 200;

local JEWEL_SLOTS = { 2, 11, 12, 13, 14 };
local GEAR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 };

local PANEL = { 0.055, 0.045, 0.035 };
local RIM = { 0.55, 0.43, 0.22 };
local RIM_LIT = { 0.85, 0.68, 0.34 };
local GOLD = { 0.96, 0.79, 0.38 };
local LABEL = { 0.86, 0.8, 0.7 };
local VALUE = { 1, 0.86, 0.55 };
local TEXT = { 0.93, 0.9, 0.84 };
local MUTED = { 0.58, 0.54, 0.48 };
local LOSS = { 0.87, 0.2, 0.14 };
local WIN = { 1, 0.8, 0.24 };
local BLUE = { 0.45, 0.72, 1 };
local BLUE_RIM = { 0.27, 0.45, 0.8 };
local GREEN = { 0.3, 0.92, 0.42 };

local CLASSES = {
	warrior = { "INV_Sword_27", 0.78, 0.61, 0.43 }, paladin = { "Spell_Holy_HolyBolt", 0.96, 0.55, 0.73 },
	hunter = { "INV_Weapon_Bow_07", 0.67, 0.83, 0.45 }, rogue = { "INV_ThrowingKnife_04", 1, 0.96, 0.41 },
	priest = { "INV_Staff_30", 1, 1, 1 }, shaman = { "Spell_Nature_BloodLust", 0, 0.44, 0.87 },
	mage = { "INV_Staff_13", 0.41, 0.8, 0.94 }, warlock = { "Spell_Nature_FaerieFire", 0.58, 0.51, 0.79 },
	druid = { "Ability_Druid_Maul", 1, 0.49, 0.04 },
};

local QUALITY = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
};
local QUALITY_BY_HEX = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 };
local RARITY = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary" };

local RESULT = {
	victory = { "Victory!", WIN, "Victory" },
	defeat = { "You died", LOSS, "Died" },
	left = { "You left the run", LOSS, "Left" },
	quit = { "The run stopped before its end", MUTED, "Stopped" },
};

local db;
local cur;
local lastEndedAt;
local pendingSig, pendingAt;
local Refresh;

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Run History:|r " .. msg);
end

local function Clock(t)
	t = math.floor(t or 0);
	local h = math.floor(t / 3600);
	local m = math.floor(math.mod(t, 3600) / 60);
	local s = math.mod(t, 60);
	if ( h > 0 ) then return string.format("%d:%02d:%02d", h, m, s); end
	return string.format("%02d:%02d", m, s);
end

local function Comma(n)
	local s = string.format("%.0f", n or 0);
	local neg = "";
	if ( string.sub(s, 1, 1) == "-" ) then neg = "-"; s = string.sub(s, 2); end
	local out = "";
	while ( string.len(s) > 3 ) do
		out = "," .. string.sub(s, -3) .. out;
		s = string.sub(s, 1, -4);
	end
	return neg .. s .. out;
end

local function Short(n)
	n = n or 0;
	if ( n >= 1e9 ) then return string.format("%.2fB", n / 1e9); end
	if ( n >= 1e6 ) then return string.format("%.2fM", n / 1e6); end
	if ( n >= 1e5 ) then return string.format("%.0fk", n / 1e3); end
	if ( n >= 1e3 ) then return string.format("%.1fk", n / 1e3); end
	return string.format("%.0f", n);
end

local function Pct(v)
	return string.format("%+.0f%%", (v or 0) * 100);
end

local function TzOffset()
	if ( db and db.settings.tz ) then return db.settings.tz * 3600; end
	return 0;
end

local function DateText(ts, fmt)
	if ( not ts ) then return ""; end
	local ok, s = pcall(date, fmt or "%b %d, %H:%M", ts + TzOffset());
	if ( ok and s ) then return s; end
	return "";
end

local function DayText(ts)
	if ( not ts ) then return ""; end
	local off = TzOffset();
	local day = math.floor((ts + off) / 86400);
	local today = math.floor((time() + off) / 86400);
	if ( day == today ) then return "Today"; end
	if ( day == today - 1 ) then return "Yesterday"; end
	return DateText(ts, "%b %d");
end

local function LinkName(link)
	if ( not link ) then return nil; end
	local _, _, name = string.find(link, "|h%[(.-)%]|h");
	return name or link;
end

local function BaseJewel(name)
	if ( not name ) then return nil; end
	local s = string.gsub(name, "%s*:.*$", "");
	s = string.gsub(s, "%s+[IVX]+%+?$", "");
	return s;
end

local function LinkQuality(link)
	if ( not link ) then return 1; end
	local _, _, hex = string.find(link, "|c%x%x(%x%x%x%x%x%x)");
	return (hex and QUALITY_BY_HEX[string.lower(hex)]) or 1;
end

local function LinkItem(link)
	if ( not link ) then return nil; end
	local _, _, item = string.find(link, "(item:[%d:%-]+)");
	return item;
end

local function ShortIcon(path)
	if ( not path or path == "" ) then return nil; end
	local s = string.gsub(path, "^[Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee]\\[Ii][Cc][Oo][Nn][Ss]\\", "");
	return s;
end

local function IconPath(icon)
	if ( not icon or icon == "" ) then return ICONS .. QUESTION; end
	if ( string.find(icon, "\\", 1, 1) ) then return icon; end
	return ICONS .. icon;
end

local function ItemIcon(link)
	local item = LinkItem(link);
	if ( not item or not GetItemInfo ) then return nil; end
	local ok, _, _, _, _, _, _, _, _, tex = pcall(GetItemInfo, item);
	if ( ok and tex ) then return ShortIcon(tex); end
	return nil;
end

local function Pretty(key)
	local s = string.gsub(tostring(key), "_", " ");
	s = string.gsub(s, "(%a)(%w*)", function(a, b) return string.upper(a) .. b; end);
	return s;
end

local function SpellName(key)
	return (AZSHistory_SpellNames and AZSHistory_SpellNames[key]) or (db and db.names[key]) or Pretty(key);
end

local Tr, SetLang, DetectLang, LangKey, LangMatch, LangHas, TalentText, Native;

do
	local LANG = { cache = {} };

	local function LangBuild()
		if ( LANG.rev or not AZSHistory_Lang ) then return; end
		LANG.rev, LANG.byKey, LANG.tpl, LANG.pat = {}, {}, {}, {};
		local rows = AZSHistory_Lang.rows;
		local n = table.getn(AZSHistory_Lang.codes);
		for i = 1, table.getn(rows) do
			local row = rows[i];
			if ( row[1] ) then LANG.byKey[row[1]] = row; end
			for c = 2, n + 1 do
				if ( LANG.rev[row[c]] == nil ) then LANG.rev[row[c]] = row; end
			end
			if ( string.find(row[2], "{%a+}") or string.find(row[2], "%%[sd]") ) then table.insert(LANG.tpl, row); end
		end
	end

	local function LangCompile(s)
		local pat, names, frag, pos, count = "^", {}, "", 1, 0;
		while ( true ) do
			local a, b, name = string.find(s, "{(%a+)}", pos);
			local a2, b2 = string.find(s, "%%[sd]", pos);
			if ( a2 and (not a or a2 < a) ) then
				count = count + 1;
				a, b, name = a2, b2, "#" .. count;
			end
			local lit = string.sub(s, pos, (a or 0) - 1);
			if ( not a ) then lit = string.sub(s, pos); end
			if ( string.len(lit) > string.len(frag) ) then frag = lit; end
			pat = pat .. string.gsub(lit, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1");
			if ( not a ) then break; end
			pat = pat .. "(.-)";
			table.insert(names, name);
			pos = b + 1;
		end
		if ( string.len(frag) < 3 ) then return nil; end
		return { pat = pat .. "$", names = names, frag = frag };
	end

	local function LangFill(s, caps)
		local count = 0;
		s = string.gsub(s, "{(%a+)}", function(n) return caps[n] or ("{" .. n .. "}"); end);
		s = string.gsub(s, "%%[sd]", function() count = count + 1; return caps["#" .. count] or ""; end);
		return s;
	end

	local function LangTemplate(text, depth)
		local n = table.getn(AZSHistory_Lang.codes);
		for i = 1, table.getn(LANG.tpl) do
			local row = LANG.tpl[i];
			LANG.pat[row] = LANG.pat[row] or {};
			for c = 2, n + 1 do
				local p = LANG.pat[row][c];
				if ( p == nil ) then
					p = LangCompile(row[c]) or false;
					LANG.pat[row][c] = p;
				end
				if ( p and string.find(text, p.frag, 1, 1) ) then
					local found = { string.find(text, p.pat) };
					if ( found[1] ) then
						local caps, known = {}, true;
						for k = 1, table.getn(p.names) do
							local cap = found[k + 2];
							local t = Tr(cap, depth + 1);
							if ( t == cap and not LANG.rev[cap] and string.find(cap, "[^%d%s%.,%%%+%-]") ) then known = false; end
							caps[p.names[k]] = t;
						end
						if ( known ) then return LangFill(row[LANG.li + 1], caps); end
					end
				end
			end
		end
		return nil;
	end

	local function LangLine(text, depth)
		local row = LANG.rev[text];
		if ( row ) then return row[LANG.li + 1]; end
		local _, _, base, num = string.find(text, "^(.+) ([IVX]+)$");
		if ( base and LANG.rev[base] ) then return LANG.rev[base][LANG.li + 1] .. " " .. num; end
		local _, _, said = string.find(text, "^(.-)!$");
		if ( said and LANG.rev[said] ) then return LANG.rev[said][LANG.li + 1] .. "!"; end
		local _, _, open, inner = string.find(text, "^(|c%x%x%x%x%x%x%x%x)(.-)|r$");
		if ( open ) then return open .. Tr(inner, depth + 1) .. "|r"; end
		if ( depth < 3 ) then return LangTemplate(text, depth); end
		return nil;
	end

	Tr = function(text, depth)
		if ( type(text) ~= "string" or text == "" or not LANG.li or not AZSHistory_Lang ) then return text; end
		depth = depth or 0;
		if ( depth == 0 and LANG.cache[text] ) then return LANG.cache[text]; end
		LangBuild();
		local out = LangLine(text, depth);
		if ( not out and string.find(text, "\n", 1, 1) ) then
			local parts, changed = {}, false;
			for seg in string.gfind(text .. "\n", "(.-)\n") do
				local t = seg ~= "" and LangLine(seg, depth) or nil;
				if ( t ) then changed = true; end
				table.insert(parts, t or seg);
			end
			if ( changed ) then out = table.concat(parts, "\n"); end
		end
		out = out or text;
		if ( depth == 0 ) then LANG.cache[text] = out; end
		return out;
	end

	function SetLang(code)
		if ( not AZSHistory_Lang ) then return; end
		local codes = AZSHistory_Lang.codes;
		for i = 1, table.getn(codes) do
			if ( codes[i] == code and LANG.li ~= i ) then
				LANG.li = i;
				LANG.cache = {};
			end
		end
	end

	function DetectLang()
		local z = AZS_ZONE;
		if ( not z or not AZSHistory_Lang or not db ) then return; end
		LangBuild();
		local checks = {};
		local function Check(row, value)
			if ( row and value and value ~= "" ) then table.insert(checks, { row, value }); end
		end
		if ( z.zone ) then
			Check(LANG.byKey["zone." .. z.zone .. ".name"], z.zname);
			Check(LANG.byKey["zone." .. z.zone .. ".subtitle"], z.zsub);
		end
		if ( z.class ) then Check(LANG.byKey["class." .. z.class .. ".name"], z.cname); end
		if ( z.race ) then Check(LANG.rev[z.race], z.rname); end
		if ( table.getn(checks) == 0 ) then return; end
		local codes = AZSHistory_Lang.codes;
		local best, most = nil, 0;
		for c = 1, table.getn(codes) do
			local score = 0;
			for i = 1, table.getn(checks) do
				if ( checks[i][1][c + 1] == checks[i][2] ) then score = score + 1; end
			end
			if ( score > most or (score == most and score > 0 and c == LANG.li) ) then best, most = c, score; end
		end
		if ( best ) then
			db.lang = codes[best];
			SetLang(db.lang);
		end
	end

	function LangKey(key)
		LangBuild();
		local row = LANG.byKey and LANG.byKey[key];
		return row and LANG.li and row[LANG.li + 1] or nil;
	end

	function LangMatch(text, template)
		LangBuild();
		local row = LANG.rev and LANG.rev[template];
		if ( not row ) then return nil; end
		local n = table.getn(AZSHistory_Lang.codes);
		LANG.pat[row] = LANG.pat[row] or {};
		for c = 2, n + 1 do
			local p = LANG.pat[row][c];
			if ( p == nil ) then
				p = LangCompile(row[c]) or false;
				LANG.pat[row][c] = p;
			end
			if ( p ) then
				local found = { string.find(text, p.pat) };
				if ( found[1] ) then
					local caps = {};
					for k = 1, table.getn(p.names) do caps[p.names[k]] = found[k + 2]; end
					return caps;
				end
			end
		end
		return nil;
	end

	function LangHas(text, template)
		LangBuild();
		local row = LANG.rev and LANG.rev[template];
		if ( not row ) then return string.find(text, template, 1, 1) ~= nil; end
		for c = 2, table.getn(AZSHistory_Lang.codes) + 1 do
			if ( string.find(text, row[c], 1, 1) ) then return true; end
		end
		return false;
	end

	function TalentText(info)
		if ( not info or not info[2] ) then return nil; end
		local en = string.gsub(info[2], "^X", "{v}");
		en = string.gsub(en, "([ %(])X([%% t])", "%1{v}%2");
		local t = Tr(en);
		if ( t == en ) then t = info[2]; else t = string.gsub(t, "{v}", "X"); end
		if ( string.find(info[2], "^%a+%.%s") ) then
			local _, e = string.find(t, "^[^%.]-%.%s+");
			if ( e ) then t = string.sub(t, e + 1); end
		end
		return t;
	end

	function Native(name)
		if ( not name ) then return name; end
		LangBuild();
		local row = LANG.rev and LANG.rev[name];
		return row and row[2] or name;
	end
end

local function SpellIcon(name)
	if ( not name ) then return nil; end
	local icons = AZSHistory_Icons or {};
	return icons[name] or (db and db.icons[name]) or icons[Native(name)];
end

local function LearnSpellbook()
	if ( not GetNumSpellTabs ) then return; end
	pcall(function()
		for tab = 1, GetNumSpellTabs() do
			local _, _, first, count = GetSpellTabInfo(tab);
			first = first or 0;
			for i = first + 1, first + (count or 0) do
				local name = GetSpellName(i, "spell");
				local tex = ShortIcon(GetSpellTexture(i, "spell"));
				if ( name and tex ) then db.icons[name] = tex; end
			end
		end
	end);
end

local function OwnTalent(class, name)
	local own = AZSHistory_Talents and AZSHistory_Talents[class or ""] or {};
	if ( not name ) then return nil; end
	return own[name] or own[Native(name)];
end

local function Copy(t)
	if ( type(t) ~= "table" ) then return t; end
	local out = {};
	for k, v in pairs(t) do out[k] = Copy(v); end
	return out;
end

local function Now()
	local t = AZS_GetRunTime and AZS_GetRunTime();
	return t or (AZS_RUN and AZS_RUN.t) or 0;
end

local function AddPick(kind, name, extra)
	extra = extra or {};
	extra.t = Now();
	extra.k = kind;
	extra.n = name;
	table.insert(cur.picks, extra);
end

local function AddEvent(kind, name, text)
	if ( not cur ) then return; end
	table.insert(cur.events, { t = Now(), k = kind, n = name, x = text });
end

local function NewRun()
	local z = AZS_ZONE or {};
	cur = {
		v = 1, id = time(), started = time(),
		hero = z.hero, class = z.class, cname = z.cname, race = z.race, rname = z.rname, gender = z.gender,
		zone = z.zone, zname = z.zname, zsub = z.zsub, diff = z.diff, mods = z.mods, len = z.len,
		spells = {}, picks = {}, events = {}, loot = {}, levels = {}, unlocked = {}, achievements = {},
		ss = {}, jn = {}, jw = {}, snap = {},
	};
	local ph = AZS_GetPhase and AZS_GetPhase();
	if ( Now() > 5 and (ph == "playing" or ph == "choosing" or ph == "paused") ) then cur.from = Now(); end
	db.current = cur;
	pendingSig = nil;
end

local function Snapshot()
	local r = AZS_RUN;
	if ( not cur or not r or not r.t ) then return; end
	local s = cur.snap;
	s.t = r.t; s.lvl = r.lvl; s.kills = r.kills; s.elites = r.ek; s.guardians = r.gk; s.bosses = r.bk;
	s.dmg = r.dealt; s.taken = r.taken; s.gold = r.ge; s.chests = r.ck;
	if ( r.won == 1 ) then cur.won = 1; end
	if ( r.endl == 1 ) then cur.endl = 1; end
	local lvl = tonumber(r.lvl);
	if ( lvl and not cur.levels[lvl] and lvl > 1 ) then
		cur.levels[lvl] = Now();
	end
end

local spellWait = 0;

local function ScanSpells()
	if ( not cur ) then return; end
	local list = AZS_SPELLS or {};
	if ( table.getn(list) == 0 ) then return; end
	local first = not cur.seenSpells;
	cur.seenSpells = 1;
	for i = 1, table.getn(list) do
		local s = list[i];
		local key = tostring(s.key);
		local rank = tonumber(s.rank) or 1;
		local had = cur.ss[key];
		local name = SpellName(key);
		if ( not had ) then
			cur.ss[key] = rank;
			table.insert(cur.spells, { key = key, spell = s.spell, at = Now(), start = first and 1 or nil });
			if ( not first ) then
				AddPick("spell", name, { r = rank, i = SpellIcon(name), key = key });
				spellWait = 0;
			end
		elseif ( rank > had ) then
			cur.ss[key] = rank;
			AddPick("rank", name, { r = rank, i = SpellIcon(name), key = key });
			spellWait = 0;
		end
	end
end

local spellNames;

local function IsJewel(name)
	local base = BaseJewel(name);
	return (AZSHistory_Jewels and AZSHistory_Jewels[base]) or (cur and cur.jn and cur.jn[base]);
end

local function NoteTalent(name, icon, wait)
	if ( not name or name == "" or IsJewel(name) ) then return; end
	if ( not spellNames ) then
		spellNames = {};
		for _, n in pairs(AZSHistory_SpellNames or {}) do spellNames[n] = 1; end
	end
	if ( spellNames[Native(name)] and not OwnTalent(cur.class, name) ) then return; end
	cur.talents = cur.talents or {};
	local t = cur.talents[name];
	if ( not t ) then
		t = { at = Now() };
		cur.talents[name] = t;
	end
	if ( icon and icon ~= "" and not t.i ) then t.i = ShortIcon(icon); end
	if ( wait and wait > 0 ) then t.w = wait; end
end

local function ScanTalents(lines)
	if ( not cur ) then return; end
	for i = 1, table.getn(lines or {}) do
		local name = tostring(lines[i].name);
		if ( lines[i].proc == 1 or OwnTalent(cur.class, name) ) then NoteTalent(name); end
	end
end

local function ScanTimers()
	if ( not cur ) then return; end
	local list = AZS_TIMERS or {};
	for i = 1, table.getn(list) do
		NoteTalent(tostring(list[i].name), list[i].icon, tonumber(list[i].wait));
	end
end

local function ScanJewels(force)
	if ( not cur ) then return; end
	local links, sig = {}, "";
	for i = 1, table.getn(JEWEL_SLOTS) do
		links[i] = GetInventoryItemLink("player", JEWEL_SLOTS[i]);
		sig = sig .. (links[i] or "-") .. ";";
	end
	if ( sig == cur.jsig ) then return; end
	if ( not force ) then
		if ( sig ~= pendingSig ) then
			pendingSig = sig;
			pendingAt = GetTime();
			return;
		end
		if ( GetTime() - pendingAt < 0.4 ) then return; end
	end
	cur.jsig = sig;
	local baseline = not cur.jewelsSeen or (AZS_GetPhase and AZS_GetPhase() == "ready");
	cur.jewelsSeen = 1;
	cur.jw = cur.jw or {};
	local worn, newOnes = {}, {};
	for i = 1, table.getn(JEWEL_SLOTS) do
		local link = links[i];
		if ( link ) then
			local name = LinkName(link);
			local base = BaseJewel(name);
			worn[base] = 1;
			local had = cur.jn[base];
			if ( had ~= link ) then
				cur.jn[base] = link;
				if ( not baseline ) then
					table.insert(newOnes, { name = name, link = link, slot = JEWEL_SLOTS[i], up = had and 1 or nil });
				end
			end
		end
	end
	local gone;
	for base in pairs(cur.jw) do
		if ( not worn[base] ) then gone = base; end
	end
	cur.jw = worn;
	for i = 1, table.getn(newOnes) do
		local j = newOnes[i];
		AddPick(j.up and "jewelup" or "jewel", j.name, {
			q = LinkQuality(j.link), i = ShortIcon(GetInventoryItemTexture("player", j.slot)),
			l = j.link, x = (not j.up) and gone or nil,
		});
	end
end

local scan = CreateFrame("GameTooltip", "AZSHistoryScanTip", UIParent, "GameTooltipTemplate");

local function Round2(v)
	return math.floor((v or 1) * 100 + 0.5) / 100;
end

local function ScanTip(method, a, b, max)
	local lines = {};
	scan:SetOwner(UIParent, "ANCHOR_NONE");
	scan:ClearLines();
	local ok = method and pcall(method, scan, a, b);
	if ( ok ) then
		local n = math.min(scan:NumLines() or 0, max);
		for i = 1, n do
			local fs = getglobal("AZSHistoryScanTipTextLeft" .. i);
			local text = fs and fs:GetText();
			if ( text and text ~= "" ) then
				local r, g, b = fs:GetTextColor();
				table.insert(lines, { text, Round2(r), Round2(g), Round2(b) });
			end
		end
	end
	scan:Hide();
	return lines;
end

local function ScanSlot(slot)
	return ScanTip(scan.SetInventoryItem, "player", slot, 14);
end

local function KeepSpellLines()
	if ( GetTime() < spellWait or not GetNumSpellTabs or not scan.SetSpell ) then return; end
	spellWait = GetTime() + 5;
	local want = {};
	local list = AZS_SPELLS or {};
	for i = 1, table.getn(list) do
		local key = tostring(list[i].key);
		want[SpellName(key)] = key;
	end
	cur.sl = cur.sl or {};
	pcall(function()
		for tab = 1, GetNumSpellTabs() do
			local _, _, first, count = GetSpellTabInfo(tab);
			first = first or 0;
			for i = first + 1, first + (count or 0) do
				local key = want[GetSpellName(i, "spell") or ""];
				if ( key ) then
					local lines = ScanTip(scan.SetSpell, i, "spell", 30);
					if ( table.getn(lines) > 1 ) then cur.sl[key] = lines; end
				end
			end
		end
	end);
end

local function HasStats(lines)
	return lines and table.getn(lines) > 3;
end

local function KeepJewelLines()
	cur.jl = cur.jl or {};
	cur.jlTry = cur.jlTry or {};
	for i = 1, table.getn(JEWEL_SLOTS) do
		local slot = JEWEL_SLOTS[i];
		local link = GetInventoryItemLink("player", slot);
		if ( link and not cur.jl[link] and GetTime() >= (cur.jlTry[link] or 0) ) then
			cur.jlTry[link] = GetTime() + 5;
			local lines = ScanSlot(slot);
			if ( HasStats(lines) ) then cur.jl[link] = lines; end
		end
	end
end

local function CaptureSlots(slots, withLines)
	local out = {};
	for i = 1, table.getn(slots) do
		local slot = slots[i];
		local link = GetInventoryItemLink("player", slot);
		if ( link ) then
			local e = { s = slot, l = link, n = LinkName(link), q = LinkQuality(link),
				i = ShortIcon(GetInventoryItemTexture("player", slot)) };
			if ( withLines ) then
				e.lines = (cur and cur.jl and cur.jl[link]) or ScanSlot(slot);
			end
			table.insert(out, e);
		end
	end
	return out;
end

local function CopyMeter(lines, most)
	local out = {};
	lines = lines or {};
	for i = 1, math.min(table.getn(lines), most) do
		local l = lines[i];
		table.insert(out, { n = tostring(l.name), d = tonumber(l.dmg) or 0, s = tonumber(l.share) or 0,
			p = (l.proc == 1) and 1 or nil });
	end
	return out;
end

local function CaptureEnd()
	if ( not cur ) then return; end
	ScanSpells();
	ScanJewels(true);
	ScanTalents(AZS_METER);
	ScanTalents(AZS_HEALING);
	ScanTimers();
	for name, t in pairs(cur.talents or {}) do
		for i = 1, table.getn(AZS_METER or {}) do
			local l = AZS_METER[i];
			if ( tostring(l.name) == name ) then t.d = tonumber(l.dmg); t.s = tonumber(l.share); end
		end
		for i = 1, table.getn(AZS_HEALING or {}) do
			local l = AZS_HEALING[i];
			if ( tostring(l.name) == name ) then t.h = tonumber(l.dmg); end
		end
	end
	local build = {};
	local list = AZS_SPELLS or {};
	for i = 1, table.getn(list) do
		local s = list[i];
		local name = SpellName(tostring(s.key));
		table.insert(build, { key = tostring(s.key), n = name, r = tonumber(s.rank) or 1, i = SpellIcon(name),
			lines = cur.sl and cur.sl[tostring(s.key)], racial = (i == table.getn(list) and table.getn(list) > 1) and 1 or nil });
	end
	if ( table.getn(build) > 0 ) then cur.build = build; end
	local jewels = CaptureSlots(JEWEL_SLOTS, true);
	local gear = CaptureSlots(GEAR_SLOTS, false);
	if ( table.getn(jewels) > 0 or not cur.jewels ) then cur.jewels = jewels; end
	if ( table.getn(gear) > 0 or not cur.gear ) then cur.gear = gear; end
	if ( AZS_METER and table.getn(AZS_METER) > 0 ) then cur.meter = CopyMeter(AZS_METER, 14); end
	if ( AZS_HEALING and table.getn(AZS_HEALING) > 0 ) then cur.healing = CopyMeter(AZS_HEALING, 6); end
	if ( AZS_TAKEN and table.getn(AZS_TAKEN) > 0 ) then
		cur.takenBy = {};
		for i = 1, table.getn(AZS_TAKEN) do
			table.insert(cur.takenBy, { n = tostring(AZS_TAKEN[i].source), d = tonumber(AZS_TAKEN[i].dmg) or 0 });
		end
	end
	if ( AZS_STATS ) then cur.stats = Copy(AZS_STATS); end
	if ( AZS_PARTY and table.getn(AZS_PARTY) > 1 ) then
		cur.party = {};
		for i = 1, table.getn(AZS_PARTY) do
			local p = AZS_PARTY[i];
			table.insert(cur.party, { n = tostring(p.name), c = p.class and string.lower(tostring(p.class)),
				d = tonumber(p.dmg) or 0, s = tonumber(p.share), top = p.top ~= "" and p.top or nil });
		end
	end
end

local function Prune()
	while ( table.getn(db.runs) > MAX_RUNS ) do
		table.remove(db.runs);
	end
end

local function Finalize(e, result, stale)
	local r = cur;
	if ( not r ) then return; end
	if ( not stale ) then CaptureEnd(); end
	e = e or r.snap;
	r.ended = time();
	r.result = result or e.result or "quit";
	if ( not RESULT[r.result] ) then r.result = "quit"; end
	r.t = tonumber(e.t) or r.snap.t or 0;
	r.lvl = tonumber(e.lvl) or r.snap.lvl;
	r.kills = tonumber(e.kills) or 0;
	r.elites = tonumber(e.elites) or 0;
	r.guardians = tonumber(e.guardians) or 0;
	r.bosses = tonumber(e.bosses) or 0;
	r.dmg = tonumber(e.dmg) or 0;
	r.taken = tonumber(e.taken) or 0;
	r.gold = tonumber(e.gold) or 0;
	r.chests = tonumber(e.chests) or 0;
	r.magnets = tonumber(e.magnets);
	if ( r.t < 1 and r.kills == 0 ) then
		db.current = nil;
		cur = nil;
		return;
	end
	if ( tonumber(e.endl) == 1 ) then r.endl = 1; end
	if ( r.result == "victory" ) then r.won = 1; end
	r.hero = r.hero or e.hero;
	r.class = r.class or e.class;
	r.cname = r.cname or e.cname;
	r.rname = r.rname or e.rname;
	r.zname = r.zname or e.zname;
	r.ss = nil; r.jn = nil; r.jw = nil; r.jsig = nil; r.seenSpells = nil; r.jewelsSeen = nil;
	r.jl = nil; r.jlTry = nil; r.sl = nil;
	if ( r.result ~= "quit" ) then r.snap = nil; end
	table.insert(db.runs, 1, r);
	Prune();
	db.current = nil;
	db.lastEnded = r.id;
	cur = nil;
	lastEndedAt = GetTime();
	if ( Refresh ) then Refresh(); end
end

local function Reopen()
	local r = db.runs[1];
	if ( cur or not r or r.id ~= db.lastEnded or not r.won ) then return; end
	if ( not AZS_RUN or AZS_RUN.endl ~= 1 ) then return; end
	if ( AZS_ZONE and AZS_ZONE.hero and r.hero ~= AZS_ZONE.hero ) then return; end
	cur = table.remove(db.runs, 1);
	cur.official = cur.official or { t = cur.t, kills = cur.kills, lvl = cur.lvl };
	cur.ss = {}; cur.jn = {}; cur.jw = {}; cur.snap = {};
	pendingSig = nil;
	for i = 1, table.getn(cur.spells) do
		cur.ss[cur.spells[i].key] = 1;
	end
	if ( cur.build ) then
		for i = 1, table.getn(cur.build) do cur.ss[cur.build[i].key] = cur.build[i].r; end
	end
	cur.seenSpells = 1;
	for i = 1, table.getn(cur.jewels or {}) do
		local base = BaseJewel(cur.jewels[i].n);
		cur.jn[base] = cur.jewels[i].l;
		cur.jw[base] = 1;
	end
	cur.jewelsSeen = 1;
	cur.endl = 1;
	db.current = cur;
	AddEvent("endless", nil);
end

local function Resume()
	if ( db.current ) then db.current.jlTry = nil; end
	local c = db.current;
	if ( not c ) then return; end
	if ( not AZS_ZONE or not AZS_ZONE.hero ) then return; end
	local z = AZS_ZONE;
	local t = AZS_RUN and tonumber(AZS_RUN.t);
	if ( c.hero == z.hero and c.zone == z.zone and t and t > 1 and t + 2 >= (tonumber(c.snap and c.snap.t) or 0) ) then
		cur = c;
		return;
	end
	cur = c;
	Finalize(nil, "quit", true);
end

local function OnZone()
	local z = AZS_ZONE or {};
	if ( db.current and not cur ) then Resume(); end
	if ( not cur and AZS_RUN and AZS_RUN.endl == 1 ) then
		Reopen();
		if ( cur ) then return; end
	end
	if ( cur ) then
		local t = AZS_RUN and tonumber(AZS_RUN.t);
		if ( t and t > 1 and cur.hero == z.hero and cur.zone == z.zone ) then return; end
		Finalize(nil, "quit", true);
	end
	NewRun();
end

local function OnRun()
	if ( not AZS_RUN ) then return; end
	local ph = AZS_RUN.ph;
	if ( cur and (ph == "ready" or ph == "playing") ) then
		local t, was = tonumber(AZS_RUN.t), tonumber(cur.snap and cur.snap.t);
		if ( t and was and t + 5 < was ) then
			Finalize(nil, "quit", true);
		end
	end
	if ( not cur ) then
		if ( db.current ) then
			Resume();
		elseif ( AZS_RUN.endl == 1 and ph ~= "dead" ) then
			Reopen();
			if ( not cur and AZS_ZONE and AZS_ZONE.hero ) then NewRun(); end
		elseif ( ph == "ready" or ph == "playing" ) then
			if ( AZS_ZONE and AZS_ZONE.hero and (not lastEndedAt or GetTime() - lastEndedAt > 3) ) then
				NewRun();
			end
		end
	end
	if ( cur ) then Snapshot(); end
end

local OnChat;

do
	local LOOT_LINE = "You receive loot:";
	local NEW_LINE = "New in your collection!";
	local TXP_ONE = "Your {class}s earn {xp} talent experience: 1 new talent point! Spend it in the armory.";
	local TXP_MANY = "Your {class}s earn {xp} talent experience: {n} new talent points! Spend them in the armory.";
	local TXP_NONE = "Your {class}s earn {xp} talent experience.";
	local ZONE_OPEN = "{zone} is now open to your {class}s.";

	local function PlainChat(msg)
		local s = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "");
		s = string.gsub(s, "|r", "");
		return s;
	end

	local function Digits(text)
		if ( not text ) then return nil; end
		local s = string.gsub(tostring(text), "[,%s]", "");
		local _, _, d = string.find(s, "(%d+)");
		return tonumber(d);
	end

	local function ParseTalentXp(msg)
		local plain = PlainChat(msg);
		local caps = LangMatch(plain, TXP_ONE);
		if ( caps ) then return Digits(caps.xp), 1; end
		caps = LangMatch(plain, TXP_MANY);
		if ( caps ) then return Digits(caps.xp), Digits(caps.n) or 0; end
		caps = LangMatch(plain, TXP_NONE);
		if ( caps ) then return Digits(caps.xp), 0; end
		local _, _, xp = string.find(msg, "earn (%d+) talent experience");
		if ( xp ) then
			local _, _, points = string.find(msg, "(%d+) new talent point");
			return tonumber(xp), tonumber(points) or 0;
		end
		return nil;
	end

	local function ParseZoneOpen(msg)
		local caps = LangMatch(PlainChat(msg), ZONE_OPEN);
		if ( caps ) then return caps.zone; end
		local _, _, zone = string.find(msg, "^(.-) is now open to your");
		return zone and PlainChat(zone);
	end

	local function LearnedSpell(msg)
		local _, _, spell = string.find(msg, "learned a new spell: (.-) %(");
		if ( spell ) then return spell; end
		local tpl = ERR_LEARN_SPELL_S;
		if ( type(tpl) ~= "string" ) then return nil; end
		local a, b = string.find(tpl, "%s", 1, 1);
		if ( not a ) then return nil; end
		local pre, post = string.sub(tpl, 1, a - 1), string.sub(tpl, b + 1);
		local s1, e1 = string.find(msg, pre, 1, 1);
		if ( not s1 ) then return nil; end
		local rest = string.sub(msg, e1 + 1);
		if ( post ~= "" ) then
			local s2 = string.find(rest, post, 1, 1);
			if ( s2 ) then rest = string.sub(rest, 1, s2 - 1); end
		end
		rest = string.gsub(rest, "%s*%b().*$", "");
		return rest ~= "" and rest or nil;
	end

	local function NoteLoot(r, msg)
		local low = string.lower(msg);
		local isDrop = event == "CHAT_MSG_LOOT" or string.find(msg, "|cff40ff40", 1, 1)
			or string.find(msg, "|cff9d9d9d", 1, 1) or string.find(low, "loot", 1, 1)
			or string.find(low, "collect", 1, 1) or LangHas(msg, LOOT_LINE) or LangHas(msg, NEW_LINE);
		if ( not isDrop or not string.find(msg, "[", 1, 1) ) then return false; end
		if ( string.find(low, "receives loot", 1, 1) ) then return false; end
		local entry;
		local _, _, link = string.find(msg, "(|c%x+|Hitem:[%d:%-]+|h%[.-%]|h|r)");
		if ( link ) then
			entry = { l = link, n = LinkName(link), q = LinkQuality(link), i = ItemIcon(link) };
		else
			local _, _, hex, name = string.find(msg, "|c%x%x(%x%x%x%x%x%x)%[(.-)%]");
			if ( not name ) then _, _, name = string.find(msg, "%[(.-)%]"); end
			if ( not name or name == "" ) then return false; end
			entry = { n = name, q = (hex and QUALITY_BY_HEX[string.lower(hex)]) or 2,
				i = AZSHistory_Icons and AZSHistory_Icons[name] };
		end
		if ( string.find(msg, "|cff40ff40", 1, 1) or string.find(low, "new in your collection", 1, 1) or LangHas(msg, NEW_LINE) ) then
			entry.new = 1;
		end
		entry.t = Now();
		table.insert(r.loot, entry);
		return true;
	end

	function OnChat(msg)
		if ( not msg ) then return; end
		local r = cur;
		if ( not r and lastEndedAt and GetTime() - lastEndedAt < 15 ) then r = db.runs[1]; end
		if ( not r ) then return; end
		if ( NoteLoot(r, msg) ) then return; end
		local xp, points = ParseTalentXp(msg);
		if ( xp ) then
			r.txp = xp;
			r.tpoints = points or 0;
			return;
		end
		local zone = ParseZoneOpen(msg);
		if ( zone ) then
			for i = 1, table.getn(r.unlocked) do
				if ( r.unlocked[i] == zone ) then return; end
			end
			table.insert(r.unlocked, zone);
			return;
		end
		local spell = LearnedSpell(msg);
		if ( spell and cur ) then
			for i = table.getn(cur.spells), 1, -1 do
				local key = cur.spells[i].key;
				if ( not (AZSHistory_SpellNames and AZSHistory_SpellNames[key]) and not db.names[key] ) then
					db.names[key] = spell;
					break;
				end
			end
		end
	end
end

local function OnBanner(b)
	if ( not b or not cur ) then return; end
	local kind = b.kind;
	if ( kind == "bossdown" or kind == "guardian" or kind == "boss" or kind == "finalboss" or kind == "rune" ) then
		AddEvent(kind, b.name, b.text);
	elseif ( kind == "achievement" ) then
		table.insert(cur.achievements, b.name ~= "" and b.name or b.text);
		AddEvent(kind, b.name, b.text);
	elseif ( kind == "unlocked" ) then
		local zone = b.name ~= "" and b.name or b.text;
		for i = 1, table.getn(cur.unlocked) do
			if ( cur.unlocked[i] == zone ) then zone = nil; break; end
		end
		if ( zone ) then table.insert(cur.unlocked, zone); end
		AddEvent(kind, b.name, b.text);
	end
end

local function Solid(parent, layer, c, a)
	local t = parent:CreateTexture(nil, layer);
	t:SetTexture(WHITE);
	t:SetVertexColor(c[1], c[2], c[3], a or 1);
	return t;
end

local function Rim(f, c, a, inset, layer)
	inset = inset or 0;
	local lines = {};
	local function Line()
		local t = Solid(f, layer or "BORDER", c, a);
		table.insert(lines, t);
		return t;
	end
	local top = Line();
	top:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset);
	top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset);
	top:SetHeight(1);
	local bottom = Line();
	bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset);
	bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset);
	bottom:SetHeight(1);
	local left = Line();
	left:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset);
	left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset);
	left:SetWidth(1);
	local right = Line();
	right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset);
	right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset);
	right:SetWidth(1);
	return lines;
end

local function TintRim(lines, c, a)
	for i = 1, table.getn(lines) do
		lines[i]:SetVertexColor(c[1], c[2], c[3], a or 1);
	end
end

local function Text(parent, font, size, c, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY");
	fs:SetFont(font or BODY_FONT, size or 12);
	c = c or TEXT;
	fs:SetTextColor(c[1], c[2], c[3]);
	fs:SetShadowColor(0, 0, 0, 0.9);
	fs:SetShadowOffset(1, -1);
	if ( justify ) then fs:SetJustifyH(justify); end
	return fs;
end

local function Color(fs, c)
	fs:SetTextColor(c[1], c[2], c[3]);
end

local function Panel(f, alpha)
	local bg = Solid(f, "BACKGROUND", PANEL, alpha or 0.94);
	bg:SetAllPoints(f);
	local glow = Solid(f, "BACKGROUND", { 1, 1, 1 }, 1);
	glow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
	glow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1);
	glow:SetHeight(90);
	glow:SetGradientAlpha("VERTICAL", 0.55, 0.42, 0.22, 0, 0.55, 0.42, 0.22, 0.12);
	f.rim = Rim(f, RIM, 0.9, 0);
	Rim(f, { 0, 0, 0 }, 0.55, 1);
end

local function Button(parent, w, h, label, style)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(w);
	b:SetHeight(h);
	local bg = b:CreateTexture(nil, "BACKGROUND");
	bg:SetTexture(WHITE);
	bg:SetAllPoints(b);
	b.bg = bg;
	b.rim = Rim(b, RIM, 1, 0);
	b.text = Text(b, BODY_FONT, style == "red" and 14 or 12, style == "red" and { 1, 0.9, 0.72 } or LABEL);
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0);
	b.text:SetText(label);
	b.style = style;
	function b:Paint()
		local lit = self.hover or self.selected;
		if ( self.style == "red" ) then
			if ( lit ) then
				self.bg:SetGradientAlpha("VERTICAL", 0.28, 0.04, 0.03, 0.97, 0.5, 0.09, 0.06, 0.97);
			else
				self.bg:SetGradientAlpha("VERTICAL", 0.2, 0.03, 0.02, 0.95, 0.37, 0.06, 0.04, 0.95);
			end
			TintRim(self.rim, lit and RIM_LIT or { 0.75, 0.58, 0.3 }, 1);
		else
			if ( self.selected ) then
				self.bg:SetGradientAlpha("VERTICAL", 0.1, 0.08, 0.04, 0.95, 0.2, 0.15, 0.07, 0.95);
				TintRim(self.rim, RIM_LIT, 1);
				Color(self.text, GOLD);
			else
				local v = self.hover and 0.13 or 0.08;
				self.bg:SetGradientAlpha("VERTICAL", v * 0.7, v * 0.6, v * 0.45, 0.92, v, v * 0.85, v * 0.65, 0.92);
				TintRim(self.rim, self.hover and RIM_LIT or { 0.42, 0.33, 0.18 }, 1);
				Color(self.text, self.hover and TEXT or LABEL);
			end
		end
	end
	b:SetScript("OnEnter", function() this.hover = 1; this:Paint(); end);
	b:SetScript("OnLeave", function() this.hover = nil; this:Paint(); end);
	b:Paint();
	return b;
end

local function Slot(parent, size)
	local s = CreateFrame("Button", nil, parent);
	s:SetWidth(size);
	s:SetHeight(size);
	local bg = Solid(s, "BACKGROUND", { 0, 0, 0 }, 0.8);
	bg:SetAllPoints(s);
	s.icon = s:CreateTexture(nil, "ARTWORK");
	s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -2);
	s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2);
	s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	s.rim = Rim(s, { 0.4, 0.4, 0.4 }, 1, 0, "OVERLAY");
	s.badge = Text(s, BODY_FONT, 11, { 1, 1, 1 }, "RIGHT");
	s.badge:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2);
	s:SetScript("OnEnter", function()
		if ( this.tip ) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
			this.tip(this);
			GameTooltip:Show();
		end
	end);
	s:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	function s:Set(icon, rimColor, badge)
		self.icon:SetTexture(IconPath(icon));
		TintRim(self.rim, rimColor or { 0.4, 0.4, 0.4 }, 1);
		self.badge:SetText(badge or "");
	end
	return s;
end

local function Take(v, kind, make)
	v.used[kind] = (v.used[kind] or 0) + 1;
	local list = v.pool[kind];
	if ( not list ) then
		list = {};
		v.pool[kind] = list;
	end
	local w = list[v.used[kind]];
	if ( not w ) then
		w = make(v);
		table.insert(list, w);
	end
	w:ClearAllPoints();
	w:Show();
	return w;
end

local function Reset(v)
	for kind, list in pairs(v.pool) do
		for i = 1, table.getn(list) do list[i]:Hide(); end
		v.used[kind] = 0;
	end
end

local function VText(v, font, size, c, justify)
	local fs = Take(v, "text", function(view) return Text(view, BODY_FONT, 12); end);
	fs:SetFont(font or BODY_FONT, size or 12);
	Color(fs, c or TEXT);
	fs:SetJustifyH(justify or "LEFT");
	fs:SetWidth(0);
	fs:SetHeight(0);
	return fs;
end

local function VSlot(v, size)
	local s = Take(v, "slot" .. size, function(view) return Slot(view, size); end);
	s.tip = nil;
	return s;
end

local function VSolid(v, c, a)
	local t = Take(v, "solid", function(view) return view:CreateTexture(nil, "BORDER"); end);
	t:SetTexture(WHITE);
	t:SetVertexColor(c[1], c[2], c[3], a or 1);
	return t;
end

local function VBack(v, c, a)
	local t = Take(v, "back", function(view) return view:CreateTexture(nil, "BACKGROUND"); end);
	t:SetTexture(WHITE);
	t:SetVertexColor(c[1], c[2], c[3], a or 1);
	return t;
end

local function VBox(v, x, y, w, h)
	local bg = VBack(v, { 0.02, 0.05, 0.11 }, 0.9);
	bg:SetPoint("TOPLEFT", v, "TOPLEFT", x, y);
	bg:SetWidth(w);
	bg:SetHeight(h);
	local edges = { { 0, 0, w, 1 }, { 0, -(h - 1), w, 1 }, { 0, 0, 1, h }, { w - 1, 0, 1, h } };
	for i = 1, 4 do
		local e = edges[i];
		local t = VSolid(v, BLUE_RIM, 1);
		t:SetPoint("TOPLEFT", v, "TOPLEFT", x + e[1], y + e[2]);
		t:SetWidth(e[3]);
		t:SetHeight(e[4]);
	end
end

local function Scrollbar(parent, height, onScroll)
	local s = CreateFrame("Slider", nil, parent);
	s:SetOrientation("VERTICAL");
	s:SetWidth(10);
	s:SetHeight(height);
	s:SetMinMaxValues(0, 0);
	s:SetValueStep(1);
	s:EnableMouse(true);
	local groove = Solid(s, "BACKGROUND", { 0, 0, 0 }, 0.55);
	groove:SetAllPoints(s);
	Rim(s, { 0.3, 0.24, 0.14 }, 0.9, 0);
	s:SetThumbTexture(WHITE);
	s.thumb = s:GetThumbTexture();
	s.thumb:SetVertexColor(RIM[1], RIM[2], RIM[3], 1);
	s.thumb:SetWidth(8);
	s.thumb:SetHeight(30);
	s:EnableMouseWheel(true);
	s:SetScript("OnMouseWheel", function()
		local lo, hi = this:GetMinMaxValues();
		this:SetValue(math.max(lo, math.min(hi, this:GetValue() - arg1 * (this.wheelStep or 1))));
	end);
	s:SetScript("OnValueChanged", function()
		if ( not this.syncing ) then onScroll(math.floor(this:GetValue() + 0.5)); end
	end);
	s:SetScript("OnEnter", function() this.thumb:SetVertexColor(RIM_LIT[1], RIM_LIT[2], RIM_LIT[3], 1); end);
	s:SetScript("OnLeave", function() this.thumb:SetVertexColor(RIM[1], RIM[2], RIM[3], 1); end);
	function s:Sync(offset, most, visible, total)
		if ( most <= 0 ) then
			self:Hide();
			return;
		end
		self.syncing = 1;
		self:SetMinMaxValues(0, most);
		self:SetValue(offset);
		self.syncing = nil;
		self.thumb:SetHeight(math.max(24, self:GetHeight() * visible / math.max(total, 1)));
		self:Show();
	end
	s:Hide();
	return s;
end

local function Header(v, text, x, y, w)
	local fs = VText(v, TITLE_FONT, 16, GOLD, "CENTER");
	fs:SetPoint("TOP", v, "TOPLEFT", x + w / 2, y);
	fs:SetText(text);
	local l = VSolid(v, RIM, 0.5);
	l:SetHeight(1);
	l:SetPoint("TOPLEFT", v, "TOPLEFT", x, y - 21);
	l:SetPoint("TOPRIGHT", v, "TOPLEFT", x + w, y - 21);
	return y - 28;
end

local function Caps(v, text, x, y, w)
	local fs = VText(v, BODY_FONT, 11, LABEL, "CENTER");
	fs:SetPoint("TOP", v, "TOPLEFT", x + w / 2, y);
	fs:SetText(text);
	return y - 18;
end

local function SpellTip(run, s)
	if ( s.lines and table.getn(s.lines) > 1 ) then
		for i = 1, table.getn(s.lines) do
			local l = s.lines[i];
			if ( i == 1 ) then
				GameTooltip:SetText(Tr(l[1]), l[2], l[3], l[4]);
			else
				GameTooltip:AddLine(Tr(l[1]), l[2], l[3], l[4], 1);
			end
		end
		return;
	end
	GameTooltip:SetText(Tr(s.n), 1, 1, 1);
	if ( s.racial ) then
		GameTooltip:AddLine(Tr("Racial"), GOLD[1], GOLD[2], GOLD[3]);
	else
		GameTooltip:AddLine("Rank " .. (s.r or 1), GOLD[1], GOLD[2], GOLD[3]);
	end
	local learned;
	for i = 1, table.getn(run.spells or {}) do
		if ( run.spells[i].key == s.key ) then learned = run.spells[i]; end
	end
	if ( learned and learned.start ) then
		GameTooltip:AddLine("You had this spell at the start of the run.", MUTED[1], MUTED[2], MUTED[3]);
	elseif ( learned ) then
		GameTooltip:AddLine("You got this spell at " .. Clock(learned.at) .. ".", MUTED[1], MUTED[2], MUTED[3]);
	end
	local ups = "";
	for i = 1, table.getn(run.picks or {}) do
		local p = run.picks[i];
		if ( p.k == "rank" and p.key == s.key ) then
			ups = ups .. (ups == "" and "" or ", ") .. "rank " .. p.r .. " at " .. Clock(p.t);
		end
	end
	if ( ups ~= "" ) then GameTooltip:AddLine(ups, MUTED[1], MUTED[2], MUTED[3], 1); end
end

local function LinesTip(lines, name, q)
	if ( lines and table.getn(lines) > 0 ) then
		for i = 1, table.getn(lines) do
			local l = lines[i];
			if ( i == 1 ) then
				GameTooltip:SetText(Tr(l[1]), l[2], l[3], l[4]);
			else
				GameTooltip:AddLine(Tr(l[1]), l[2], l[3], l[4], 1);
			end
		end
		return;
	end
	local c = QUALITY[q or 1] or QUALITY[1];
	GameTooltip:SetText(Tr(name) or "?", c[1], c[2], c[3]);
end

local function JewelLines(j)
	if ( HasStats(j.lines) ) then return j.lines; end
	for i = 1, table.getn(db.runs) do
		local js = db.runs[i].jewels or {};
		for k = 1, table.getn(js) do
			if ( js[k].n == j.n and HasStats(js[k].lines) ) then return js[k].lines; end
		end
	end
	return j.lines;
end

local function ItemTip(link, name, q, lines)
	if ( lines and table.getn(lines) > 0 ) then
		LinesTip(lines, name, q);
		return;
	end
	local item = LinkItem(link);
	if ( item ) then
		local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, item);
		if ( ok and (GameTooltip:NumLines() or 0) > 0 ) then return; end
	end
	LinesTip(nil, name, q);
end

local W, H = 860, 590;
local LIST_W = 276;
local ROW_H, ROW_GAP = 46, 3;
local ROWS = 9;

local frame = CreateFrame("Frame", "AZSHistoryFrame", UIParent);
frame:SetWidth(W);
frame:SetHeight(H);
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20);
frame:SetFrameStrata("DIALOG");
frame:SetToplevel(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:EnableMouse(true);
frame:Hide();
Panel(frame, 0.96);
if ( UISpecialFrames ) then table.insert(UISpecialFrames, "AZSHistoryFrame"); end

local grip = CreateFrame("Frame", nil, frame);
grip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, 0);
grip:SetHeight(70);
grip:EnableMouse(true);
grip:RegisterForDrag("LeftButton");
grip:SetScript("OnDragStart", function() frame:StartMoving(); end);
grip:SetScript("OnDragStop", function()
	frame:StopMovingOrSizing();
	local p, _, rp, x, y = frame:GetPoint();
	db.settings.point = { p, rp, x, y };
end);

local title = Text(frame, TITLE_FONT, 30, GOLD, "CENTER");
title:SetPoint("TOP", frame, "TOP", 0, -14);
title:SetText("Run History");
local summary = Text(frame, BODY_FONT, 12, LABEL, "CENTER");
summary:SetPoint("TOP", frame, "TOP", 0, -50);

local close = Button(frame, 26, 26, "X", "tab");
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12);
close:SetScript("OnClick", function() frame:Hide(); end);

local list = CreateFrame("Frame", nil, frame);
list:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -74);
list:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14);
list:SetWidth(LIST_W);
Panel(list, 0.6);
list:EnableMouseWheel(true);

local FILTERS = { "all", "victory", "lost" };
local FILTER_LABEL = { all = "All runs", victory = "Victories", lost = "Died" };
local filterButtons = {};
for i = 1, 3 do
	local key = FILTERS[i];
	local b = Button(list, 82, 22, FILTER_LABEL[key], "tab");
	b:SetPoint("TOPLEFT", list, "TOPLEFT", 9 + (i - 1) * 86, -9);
	b:SetScript("OnClick", function()
		db.settings.filter = key;
		db.settings.offset = 0;
		Refresh();
	end);
	filterButtons[key] = b;
end

local classButton = Button(list, 254, 20, "All classes", "tab");
classButton:SetPoint("TOPLEFT", list, "TOPLEFT", 11, -36);
classButton.text:SetFont(BODY_FONT, 11);

local listEmpty = Text(list, BODY_FONT, 12, MUTED, "CENTER");
listEmpty:SetPoint("CENTER", list, "CENTER", 0, 0);
listEmpty:SetWidth(LIST_W - 30);

local listBar = Scrollbar(list, ROWS * (ROW_H + ROW_GAP) - ROW_GAP, function(offset)
	db.settings.offset = offset;
	Refresh();
end);
listBar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -62);

local rows = {};
local shown = {};
local selectedId;

local function RunMatches(r, filter, class)
	if ( class and r.class ~= class ) then return false; end
	if ( filter == "victory" ) then return r.won == 1 or r.result == "victory"; end
	if ( filter == "lost" ) then return r.result ~= "victory" and not r.won; end
	return true;
end

for i = 1, ROWS do
	local row = CreateFrame("Button", nil, list);
	row:SetWidth(LIST_W - 34);
	row:SetHeight(ROW_H);
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 9, -62 - (i - 1) * (ROW_H + ROW_GAP));
	row.bg = Solid(row, "BACKGROUND", { 0, 0, 0 }, 0.35);
	row.bg:SetAllPoints(row);
	row.rim = Rim(row, { 0.3, 0.24, 0.14 }, 0.8, 0);
	row.icon = Slot(row, 36);
	row.icon:SetPoint("LEFT", row, "LEFT", 5, 0);
	row.icon:EnableMouse(false);
	row.name = Text(row, BODY_FONT, 13, TEXT, "LEFT");
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -7);
	row.name:SetWidth(96);
	row.name:SetHeight(15);
	row.zone = Text(row, BODY_FONT, 11, MUTED, "LEFT");
	row.zone:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 48, 7);
	row.zone:SetWidth(104);
	row.zone:SetHeight(13);
	row.result = Text(row, BODY_FONT, 12, LOSS, "RIGHT");
	row.result:SetPoint("TOPRIGHT", row, "TOPRIGHT", -7, -7);
	row.when = Text(row, BODY_FONT, 11, MUTED, "RIGHT");
	row.when:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -7, 7);
	row:SetScript("OnEnter", function() this.hover = 1; this:Paint(); end);
	row:SetScript("OnLeave", function() this.hover = nil; this:Paint(); end);
	row:SetScript("OnClick", function()
		if ( this.runId ) then
			selectedId = this.runId;
			Refresh();
		end
	end);
	function row:Paint()
		if ( self.runId and self.runId == selectedId ) then
			self.bg:SetVertexColor(0.32, 0.22, 0.08, 0.55);
			TintRim(self.rim, RIM_LIT, 1);
		elseif ( self.hover ) then
			self.bg:SetVertexColor(0.2, 0.15, 0.08, 0.45);
			TintRim(self.rim, RIM, 0.9);
		else
			self.bg:SetVertexColor(0, 0, 0, 0.35);
			TintRim(self.rim, { 0.3, 0.24, 0.14 }, 0.8);
		end
	end
	rows[i] = row;
end

list:SetScript("OnMouseWheel", function()
	local most = math.max(0, table.getn(shown) - ROWS);
	db.settings.offset = math.max(0, math.min(most, (db.settings.offset or 0) - arg1));
	Refresh();
end);

classButton:SetScript("OnClick", function()
	local order = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" };
	local played = {};
	for i = 1, table.getn(db.runs) do played[db.runs[i].class or ""] = 1; end
	local at = 0;
	for i = 1, 9 do
		if ( order[i] == db.settings.class ) then at = i; end
	end
	local nextClass;
	for i = at + 1, 9 do
		if ( played[order[i]] ) then nextClass = order[i]; break; end
	end
	db.settings.class = nextClass;
	db.settings.offset = 0;
	Refresh();
end);

local detail = CreateFrame("Frame", nil, frame);
detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + LIST_W + 12, -74);
detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14);
Panel(detail, 0.6);

local dTitle = Text(detail, TITLE_FONT, 30, LOSS, "CENTER");
dTitle:SetPoint("TOP", detail, "TOP", 0, -12);
local dSub = Text(detail, BODY_FONT, 14, TEXT, "CENTER");
dSub:SetPoint("TOP", detail, "TOP", 0, -50);
local dMeta = Text(detail, BODY_FONT, 11, MUTED, "CENTER");
dMeta:SetPoint("TOP", detail, "TOP", 0, -69);
dMeta:SetWidth(520);
dMeta:SetHeight(14);
local dEmpty = Text(detail, BODY_FONT, 13, MUTED, "CENTER");
dEmpty:SetPoint("CENTER", detail, "CENTER", 0, 0);
dEmpty:SetWidth(380);

local TABS = { "summary", "build", "talents", "damage", "hero", "timeline" };
local TAB_LABEL = { summary = "Summary", build = "Build", talents = "Talents", damage = "Damage", hero = "Stats",
	timeline = "Timeline" };
local tabButtons = {};
for i = 1, table.getn(TABS) do
	local key = TABS[i];
	local b = Button(detail, 80, 22, TAB_LABEL[key], "tab");
	b:SetPoint("TOP", detail, "TOP", (i - 3.5) * 84, -88);
	b:SetScript("OnClick", function()
		db.settings.tab = key;
		Refresh();
	end);
	tabButtons[key] = b;
end

local views = {};
for i = 1, table.getn(TABS) do
	local v = CreateFrame("Frame", nil, detail);
	v:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -120);
	v:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -14, 44);
	v.pool = {};
	v.used = {};
	v:Hide();
	views[TABS[i]] = v;
end
local VW = W - 14 - LIST_W - 12 - 14 - 28;

local delete = Button(detail, 140, 24, "Delete run", "red");
delete.text:SetFont(BODY_FONT, 12);
delete:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 12);
local position = Text(detail, BODY_FONT, 11, MUTED, "RIGHT");
position:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -14, 18);

local function Selected()
	for i = 1, table.getn(db.runs) do
		if ( db.runs[i].id == selectedId ) then return db.runs[i], i; end
	end
end

local function DisarmDelete()
	if ( this.armed and GetTime() - this.armed >= 4 ) then
		this.armed = nil;
		this.text:SetText("Delete run");
		this:SetScript("OnUpdate", nil);
	end
end

delete:SetScript("OnClick", function()
	local run, index = Selected();
	if ( not run ) then return; end
	if ( this.armed and GetTime() - this.armed < 4 ) then
		table.remove(db.runs, index);
		if ( index == 1 ) then lastEndedAt = nil; end
		this.armed = nil;
		this:SetScript("OnUpdate", nil);
		this.text:SetText("Delete run");
		local nextRun = db.runs[index] or db.runs[index - 1];
		selectedId = nextRun and nextRun.id;
		Refresh();
		return;
	end
	this.armed = GetTime();
	this.text:SetText("Push again to delete");
	this:SetScript("OnUpdate", DisarmDelete);
end);

local function StatGrid(v, y, entries, colX, labelW)
	local half = math.ceil(table.getn(entries) / 2);
	for i = 1, table.getn(entries) do
		local col = (i <= half) and 0 or 1;
		local rowY = y - math.mod(i - 1, half) * 20;
		local cx = colX[col + 1];
		local label = VText(v, BODY_FONT, 14, LABEL, "RIGHT");
		label:SetPoint("TOPRIGHT", v, "TOPLEFT", cx, rowY);
		label:SetText(Tr(entries[i][1]));
		local value = VText(v, BODY_FONT, 14, VALUE, "LEFT");
		value:SetPoint("TOPLEFT", v, "TOPLEFT", cx + 12, rowY);
		value:SetText(entries[i][2]);
	end
	return y - half * 20;
end

local function LootGrid(v, y, items, cols, most)
	local colW = VW / cols;
	local n = math.min(table.getn(items), most);
	for i = 1, n do
		local it = items[i];
		local col = math.mod(i - 1, cols);
		local row = math.floor((i - 1) / cols);
		local x = col * colW + 4;
		local s = VSlot(v, 22);
		s:SetPoint("TOPLEFT", v, "TOPLEFT", x, y - row * 28);
		local qc = QUALITY[it.q or 1] or QUALITY[1];
		s:Set(it.i or ItemIcon(it.l), qc);
		s.tip = function() ItemTip(it.l, it.n, it.q, it.lines); end;
		local name = VText(v, BODY_FONT, 12, qc, "LEFT");
		name:SetPoint("LEFT", s, "RIGHT", 6, 0);
		name:SetWidth(colW - 36 - (it.new and 40 or 0));
		name:SetHeight(14);
		name:SetText(Tr(it.n));
		if ( it.new ) then
			local tag = VText(v, BODY_FONT, 10, GREEN, "LEFT");
			tag:SetPoint("LEFT", name, "RIGHT", 3, 0);
			tag:SetText(Tr("NEW"));
		end
	end
	local rowsUsed = math.ceil(n / cols);
	local y2 = y - rowsUsed * 28;
	if ( table.getn(items) > most ) then
		local more = VText(v, BODY_FONT, 11, MUTED, "CENTER");
		more:SetPoint("TOP", v, "TOPLEFT", VW / 2, y2);
		more:SetText(string.format("+%d more", table.getn(items) - most));
		y2 = y2 - 16;
	end
	return y2;
end

local DRAW = {};

function DRAW.summary(v, run)
	local y = 0;
	local lines = {};
	if ( (run.tpoints or 0) > 0 ) then
		table.insert(lines, { (run.tpoints == 1) and "+1 talent point!" or string.format("+%d talent points!", run.tpoints), TEXT });
	end
	for i = 1, table.getn(run.unlocked or {}) do
		table.insert(lines, { "New zone opened: " .. Tr(run.unlocked[i]), GREEN });
	end
	for i = 1, table.getn(run.achievements or {}) do
		table.insert(lines, { "Achievement: " .. Tr(run.achievements[i]), GOLD });
	end
	local newLoot = 0;
	for i = 1, table.getn(run.loot or {}) do
		if ( run.loot[i].new ) then newLoot = newLoot + 1; end
	end
	local boxH = 44 + table.getn(lines) * 18;
	VBox(v, 0, y, VW, boxH);
	local head = VText(v, BODY_FONT, 15, BLUE, "LEFT");
	head:SetPoint("TOPLEFT", v, "TOPLEFT", 14, y - 12);
	head:SetText("Talent experience");
	local xp = VText(v, TITLE_FONT, 22, { 1, 1, 1 }, "RIGHT");
	xp:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 14, y - 8);
	xp:SetText(run.txp and ("+" .. run.txp) or "None");
	for i = 1, table.getn(lines) do
		local fs = VText(v, BODY_FONT, 13, lines[i][2], "LEFT");
		fs:SetPoint("TOPLEFT", v, "TOPLEFT", 14, y - 36 - (i - 1) * 18);
		fs:SetText(lines[i][1]);
	end
	y = y - boxH - 12;

	y = Caps(v, string.format("LOOT · %d NEW ITEMS", newLoot), 0, y, VW);
	if ( table.getn(run.loot or {}) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y - 2);
		none:SetText("No loot dropped in this run.");
		y = y - 22;
	else
		local worn = {};
		for i = 1, table.getn(run.gear or {}) do worn[run.gear[i].n] = run.gear[i].i; end
		for i = 1, table.getn(run.loot) do
			local l = run.loot[i];
			if ( not l.i and not l.l ) then l.i = worn[l.n]; end
		end
		local items = {};
		for i = 1, table.getn(run.loot) do if ( run.loot[i].new ) then table.insert(items, run.loot[i]); end end
		for i = 1, table.getn(run.loot) do if ( not run.loot[i].new ) then table.insert(items, run.loot[i]); end end
		y = LootGrid(v, y - 2, items, 3, 6) - 6;
	end
	y = y - 6;
	StatGrid(v, y, {
		{ "Time", Clock(run.t) }, { "Level", tostring(run.lvl or "?") }, { "Kills", Comma(run.kills) },
		{ "Elites killed", Comma(run.elites) }, { "Guardians killed", Comma(run.guardians) },
		{ "Bosses killed", Comma(run.bosses) }, { "Damage dealt", Comma(run.dmg) },
		{ "Damage taken", Comma(run.taken) }, { "Gold earned", Comma(run.gold) },
		{ "Chests opened", Comma(run.chests) },
	}, { VW * 0.27, VW * 0.77 });
end

function DRAW.build(v, run)
	local y = Header(v, "Spells", 0, 0, VW);
	local build = run.build or {};
	if ( table.getn(build) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		none:SetText("The addon did not record spells for this run.");
		y = y - 20;
	else
		local size, gap = 40, 8;
		local n = table.getn(build);
		local x0 = (VW - (n * size + (n - 1) * gap)) / 2;
		for i = 1, n do
			local s = build[i];
			local slot = VSlot(v, size);
			slot:SetPoint("TOPLEFT", v, "TOPLEFT", x0 + (i - 1) * (size + gap), y);
			slot:Set(s.i or SpellIcon(s.n), s.racial and { 0.55, 0.55, 0.6 } or RIM_LIT, s.racial and "" or tostring(s.r or 1));
			slot.tip = function() SpellTip(run, s); end;
		end
		y = y - size - 4;
		local names = VText(v, BODY_FONT, 11, MUTED, "CENTER");
		names:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		names:SetWidth(VW - 20);
		local s = "";
		for i = 1, n do
			if ( not build[i].racial ) then
				s = s .. (s == "" and "" or "  ·  ") .. Tr(build[i].n) .. " " .. (build[i].r or 1);
			end
		end
		names:SetText(s);
		y = y - (names:GetHeight() or 14) - 8;
	end

	y = Header(v, "Jewelry", 0, y, VW);
	local jewels = run.jewels or {};
	if ( table.getn(jewels) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		none:SetText("You did not wear rings, trinkets or an amulet in this run.");
		y = y - 22;
	else
		local items = {};
		for i = 1, table.getn(jewels) do
			local j = jewels[i];
			table.insert(items, { l = j.l, n = j.n, q = j.q, i = j.i, lines = JewelLines(j) });
		end
		y = LootGrid(v, y, items, 2, 6) - 4;
	end

	y = Header(v, "Worn gear", 0, y, VW);
	local gear = run.gear or {};
	if ( table.getn(gear) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		none:SetText("You did not wear gear in this run.");
	else
		local size, gap = 32, 6;
		local n = table.getn(gear);
		local x0 = (VW - (n * size + (n - 1) * gap)) / 2;
		for i = 1, n do
			local g = gear[i];
			local slot = VSlot(v, size);
			slot:SetPoint("TOPLEFT", v, "TOPLEFT", x0 + (i - 1) * (size + gap), y);
			slot:Set(g.i, QUALITY[g.q or 1]);
			slot.tip = function() ItemTip(g.l, g.n, g.q); end;
		end
	end
end

local TALENT_ROWS = 7;
local TALENT_H = 36;

local function JoinedAt(run)
	if ( run.from ) then return run.from; end
	local first = run.spells and run.spells[1];
	if ( first and first.start and (first.at or 0) > 5 ) then return first.at; end
	return nil;
end

local function Before(run, t)
	local from = JoinedAt(run);
	return from and (t.at or 0) <= from + 2 and from;
end

local function TalentTip(run, name, t, info)
	GameTooltip:SetText(Tr(name), 1, 1, 1);
	if ( info ) then
		local kind = "";
		if ( info[2] and string.find(info[2], "^Milestone%.") ) then kind = " · milestone"; end
		if ( info[2] and string.find(info[2], "^Capstone%.") ) then kind = " · capstone"; end
		GameTooltip:AddLine(Tr(info[1]) .. kind, GOLD[1], GOLD[2], GOLD[3]);
		if ( info[2] ) then
			local desc = TalentText(info);
			GameTooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
		end
	else
		GameTooltip:AddLine("Damage or healing from a talent or an effect", GOLD[1], GOLD[2], GOLD[3]);
	end
	if ( t.d and t.d > 0 ) then
		GameTooltip:AddLine(string.format("%s damage, %d%% of your damage", Comma(t.d), math.floor((t.s or 0) * 100 + 0.5)), TEXT[1], TEXT[2], TEXT[3]);
	end
	if ( t.h and t.h > 0 ) then GameTooltip:AddLine(Comma(t.h) .. " healing", GREEN[1], GREEN[2], GREEN[3]); end
	if ( t.w ) then GameTooltip:AddLine(string.format("Maximum rate: 1 time in %s seconds", Short(t.w)), MUTED[1], MUTED[2], MUTED[3]); end
	local from = Before(run, t);
	if ( from ) then
		GameTooltip:AddLine("The addon started to record this run at " .. Clock(from) .. ". This talent was active before that time.", MUTED[1], MUTED[2], MUTED[3], 1);
	else
		GameTooltip:AddLine("First time at " .. Clock(t.at), MUTED[1], MUTED[2], MUTED[3]);
	end
end

function DRAW.talents(v, run)
	local list = {};
	for name, t in pairs(run.talents or {}) do
		table.insert(list, { n = name, t = t, info = OwnTalent(run.class, name) });
	end
	table.sort(list, function(a, b)
		local x, y = (a.t.d or 0) + (a.t.h or 0), (b.t.d or 0) + (b.t.h or 0);
		if ( x ~= y ) then return x > y; end
		return (a.t.at or 0) < (b.t.at or 0);
	end);
	local y = Header(v, "Active talents", 0, 0, VW);
	if ( table.getn(list) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y - 4);
		none:SetWidth(VW - 40);
		none:SetText("No talent did damage or healing in this run.");
	end
	local most = math.max(0, table.getn(list) - TALENT_ROWS);
	v.offset = math.max(0, math.min(v.offset or 0, most));
	for i = 1, math.min(TALENT_ROWS, table.getn(list) - v.offset) do
		local e = list[i + v.offset];
		local t, info = e.t, e.info;
		local ry = y - (i - 1) * TALENT_H;
		local s = VSlot(v, 30);
		s:SetPoint("TOPLEFT", v, "TOPLEFT", 0, ry);
		s:Set(t.i or SpellIcon(e.n), RIM);
		s.tip = function() TalentTip(run, e.n, t, info); end;
		local name = VText(v, BODY_FONT, 13, GOLD, "LEFT");
		name:SetPoint("TOPLEFT", v, "TOPLEFT", 40, ry - 1);
		name:SetWidth(VW - 210);
		name:SetHeight(15);
		name:SetText(Tr(e.n));
		local sub = VText(v, BODY_FONT, 11, MUTED, "LEFT");
		sub:SetPoint("TOPLEFT", v, "TOPLEFT", 40, ry - 17);
		sub:SetWidth(VW - 210);
		sub:SetHeight(13);
		local kind = info and Tr(info[1]) or "Talent or effect";
		if ( info and info[2] and string.find(info[2], "^Milestone%.") ) then kind = kind .. " · milestone"; end
		if ( info and info[2] and string.find(info[2], "^Capstone%.") ) then kind = kind .. " · capstone"; end
		sub:SetText(kind);
		local right = VText(v, BODY_FONT, 12, VALUE, "RIGHT");
		right:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 16, ry - 1);
		if ( t.d and t.d > 0 ) then
			right:SetText(string.format("%s  %d%%", Short(t.d), math.floor((t.s or 0) * 100 + 0.5)));
		elseif ( t.h and t.h > 0 ) then
			right:SetText("healing " .. Short(t.h));
			Color(right, GREEN);
		else
			right:SetText("");
		end
		local when = VText(v, BODY_FONT, 11, MUTED, "RIGHT");
		when:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 16, ry - 17);
		local from = Before(run, t);
		local at = from and ("before " .. Clock(from)) or ("from " .. Clock(t.at));
		if ( t.w ) then
			when:SetText(string.format("1 time in %s s · %s", Short(t.w), at));
		else
			when:SetText(at);
		end
	end
	v.bar:Sync(v.offset, most, TALENT_ROWS, table.getn(list));
	local note = VText(v, BODY_FONT, 10, MUTED, "CENTER");
	note:SetPoint("BOTTOM", v, "BOTTOM", 0, 0);
	note:SetWidth(VW - 20);
	note:SetText("The addon cannot see talents that only change values. This list shows the talents that did damage, did healing or used a timer.");
end

local TAKEN_LABEL = {
	["boss melee"] = { "Boss melee", "Ability_Warrior_Cleave" }, ["boss spell"] = { "Boss spells", "Spell_Shadow_ShadowBolt" },
	["elite"] = { "Elites", "Ability_Warrior_Charge" }, ["mob melee"] = { "Mob melee", "Ability_MeleeDamage" },
	["mob spell"] = { "Mob spells", "Spell_Nature_StarFall" }, ["area"] = { "Ground effects", "Spell_Fire_Fire" },
};

local function Bars(v, x, y, w, lines, total, color, most)
	local top = (lines[1] and lines[1].d) or 0;
	for i = 1, math.min(table.getn(lines), most) do
		local l = lines[i];
		local by = y - (i - 1) * 20;
		local back = VBack(v, { 0, 0, 0 }, 0.4);
		back:SetPoint("TOPLEFT", v, "TOPLEFT", x + 20, by);
		back:SetWidth(w - 20);
		back:SetHeight(18);
		local fill = VSolid(v, l.color or (l.p and { 0.3, 0.55, 1 }) or color, 0.5);
		fill:SetPoint("TOPLEFT", v, "TOPLEFT", x + 20, by);
		fill:SetWidth(math.max(1, (w - 20) * ((top > 0) and l.d / top or 0)));
		fill:SetHeight(18);
		local s = VSlot(v, 18);
		s:SetPoint("TOPLEFT", v, "TOPLEFT", x, by);
		s:Set(l.i or SpellIcon(l.n) or QUESTION, { 0.25, 0.25, 0.25 });
		s:EnableMouse(false);
		local name = VText(v, BODY_FONT, 11, TEXT, "LEFT");
		name:SetPoint("TOPLEFT", v, "TOPLEFT", x + 25, by - 3);
		name:SetWidth(w - 110);
		name:SetHeight(13);
		name:SetText(Tr(l.n));
		local val = VText(v, BODY_FONT, 11, TEXT, "RIGHT");
		val:SetPoint("TOPRIGHT", v, "TOPLEFT", x + w - 4, by - 3);
		local share = l.s;
		if ( not share and total and total > 0 ) then share = l.d / total; end
		val:SetText(string.format("%s  %d%%", Short(l.d), math.floor((share or 0) * 100 + 0.5)));
	end
	return y - math.min(table.getn(lines), most) * 20;
end

function DRAW.damage(v, run)
	local cls = CLASSES[run.class or ""] or { nil, 0.75, 0.75, 0.8 };
	local color = { cls[2], cls[3], cls[4] };
	local half = (VW - 16) / 2;
	local y = Header(v, "Damage done", 0, 0, half);
	local meter = run.meter or {};
	if ( table.getn(meter) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", half / 2, y);
		none:SetText("The addon did not record damage for this run.");
	else
		y = Bars(v, 0, y, half, meter, run.dmg, color, 13);
		local dps = VText(v, BODY_FONT, 11, MUTED, "CENTER");
		dps:SetPoint("TOP", v, "TOPLEFT", half / 2, y - 6);
		dps:SetText(string.format("%s total · %s per second", Short(run.dmg), Short((run.dmg or 0) / math.max(run.t or 1, 1))));
	end

	local x = half + 16;
	if ( run.party and table.getn(run.party) > 1 ) then
		y = Header(v, "Party", x, 0, half);
		local party = {};
		for i = 1, table.getn(run.party) do
			local p = run.party[i];
			local cls = CLASSES[p.c or ""];
			table.insert(party, { n = p.n .. (p.top and ("  |cff9d9d9d" .. p.top .. "|r") or ""), d = p.d, s = p.s,
				i = cls and cls[1], color = cls and { cls[2], cls[3], cls[4] } });
		end
		y = Bars(v, x, y, half, party, nil, { 0.75, 0.75, 0.8 }, 5);
		y = Header(v, "Damage taken", x, y - 10, half);
		local taken = {};
		for i = 1, table.getn(run.takenBy or {}) do
			local t = run.takenBy[i];
			local info = TAKEN_LABEL[t.n];
			table.insert(taken, { n = info and info[1] or t.n, i = info and info[2], d = t.d });
		end
		Bars(v, x, y, half, taken, run.taken, { 0.85, 0.3, 0.25 }, 6);
		return;
	end
	y = Header(v, "Healing done", x, 0, half);
	local heal = run.healing or {};
	if ( table.getn(heal) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", x + half / 2, y);
		none:SetText("The addon did not record healing for this run.");
		y = y - 20;
	else
		y = Bars(v, x, y, half, heal, nil, { 0.35, 0.85, 0.45 }, 5);
	end
	y = Header(v, "Damage taken", x, y - 10, half);
	local taken = {};
	for i = 1, table.getn(run.takenBy or {}) do
		local t = run.takenBy[i];
		local info = TAKEN_LABEL[t.n];
		table.insert(taken, { n = info and info[1] or t.n, i = info and info[2], d = t.d });
	end
	if ( table.getn(taken) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", x + half / 2, y);
		none:SetText("You did not take damage in this run.");
	else
		Bars(v, x, y, half, taken, run.taken, { 0.85, 0.3, 0.25 }, 6);
	end
end

local function GearLine(s)
	local parts = {};
	local function Add(v, text) if ( v and v ~= 0 ) then table.insert(parts, text); end end
	Add(s.ghp, string.format("+%.0f max health", s.ghp or 0));
	Add(s.gdmg, string.format("+%.0f%% damage", (s.gdmg or 0) * 100));
	Add(s.gcd, string.format("-%.0f%% cooldowns", (s.gcd or 0) * 100));
	Add(s.gcrit, string.format("+%.0f%% critical strike", (s.gcrit or 0) * 100));
	Add(s.gcm, string.format("+%.0f%% critical damage", (s.gcm or 0) * 100));
	Add(s.garm, string.format("+%.0f%% damage reduction", (s.garm or 0) * 100));
	Add(s.greg, string.format("+%.1f health per second", s.greg or 0));
	Add(s.garea, string.format("+%.0f%% area of effect", (s.garea or 0) * 100));
	Add(s.gcnt, string.format("+%d targets", s.gcnt or 0));
	Add(s.gecho, string.format("+%.0f%% echo", (s.gecho or 0) * 100));
	Add(s.gspd, string.format("+%.0f%% movement speed", (s.gspd or 0) * 100));
	Add(s.gpick, string.format("+%.0f%% pickup range", (s.gpick or 0) * 100));
	Add(s.ggold, string.format("+%.0f%% gold", (s.ggold or 0) * 100));
	local out = "";
	for i = 1, table.getn(parts) do out = out .. (i > 1 and " · " or "") .. parts[i]; end
	return out;
end

function DRAW.hero(v, run)
	local s = run.stats;
	if ( not s ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOP", 0, -40);
		none:SetText("The addon did not record stats for this run.");
		return;
	end
	local y = Header(v, "Stats at the end of the run", 0, 0, VW);
	local function N(k, d) return tonumber(s[k]) or d or 0; end
	local entries = {
		{ "Health", string.format("%.0f", N("hp")) }, { "Damage", Pct(N("dmg", 1) - 1) },
		{ "Haste", Pct(1 - N("cd", 1)) }, { "Crit", string.format("%.1f%%", N("crit") * 100) },
		{ "Crit Dmg", string.format("%.0f%%", N("cm") * 100) }, { "Armor", string.format("%.0f%%", N("arm") * 100) },
		{ "Area", Pct(N("area", 1) - 1) }, { "Targets", string.format("+%d", N("cnt")) },
		{ "Echo", string.format("%.0f%%", N("echo") * 100) }, { "Speed", Pct(N("spd", 1) - 1) },
		{ "Regen", string.format("%.1f", N("reg")) }, { "Pickup", string.format("%.0f yd", N("pick")) },
		{ "Lifesteal", string.format("%.1f%%", N("lch") * 100) }, { "Kill Heal", string.format("%.1f", N("heal")) },
		{ "Thorns", string.format("%.0f%%", N("thn") * 100) }, { "Experience", Pct(N("xp", 1) - 1) },
		{ "Gold", Pct(N("gold", 1) - 1) }, { "Luck", string.format("%.0f%%", N("luck") * 100) },
	};
	y = StatGrid(v, y, entries, { VW * 0.3, VW * 0.78 }) - 10;
	local gear = GearLine(s);
	if ( gear ~= "" ) then
		y = Caps(v, "WORN GEAR", 0, y, VW);
		local fs = VText(v, BODY_FONT, 12, GREEN, "CENTER");
		fs:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		fs:SetWidth(VW - 20);
		fs:SetText(gear);
	end
end

local TIMELINE_ROWS = 19;

local function Timeline(run)
	local out = {};
	for i = 1, table.getn(run.picks or {}) do
		local p = run.picks[i];
		local pn = Tr(p.n);
		local text, icon, c = pn, p.i, TEXT;
		if ( p.k == "spell" ) then
			text = Tr("New spell") .. ": " .. pn;
		elseif ( p.k == "rank" ) then
			text = pn .. " · rank " .. (p.r or "?");
		elseif ( p.k == "jewel" ) then
			c = QUALITY[p.q or 1] or TEXT;
			text = pn .. (RARITY[p.q or 1] and (" · " .. Tr(RARITY[p.q or 1])) or "");
			if ( p.x ) then text = text .. ", in place of " .. Tr(p.x); end
		elseif ( p.k == "jewelup" ) then
			c = QUALITY[p.q or 1] or TEXT;
			text = pn .. " · higher rank";
		end
		table.insert(out, { t = p.t, text = text, icon = icon or SpellIcon(p.n), c = c });
	end
	local EVENT = {
		boss = { "Spell_Shadow_RaiseDead", LABEL }, finalboss = { "Spell_Shadow_RaiseDead", LOSS },
		bossdown = { "INV_Misc_Head_Dragon_01", GOLD }, guardian = { "Ability_Warrior_Charge", GOLD },
		achievement = { "INV_Misc_Book_07", GOLD }, unlocked = { "INV_Misc_Map_01", GREEN },
		rune = { "INV_Misc_Rune_01", BLUE }, endless = { "Spell_Shadow_RaiseDead", WIN },
	};
	for i = 1, table.getn(run.events or {}) do
		local e = run.events[i];
		local info = EVENT[e.k] or { QUESTION, TEXT };
		local text = Tr(e.x or e.n) or e.k;
		if ( e.k == "guardian" and e.n and e.n ~= "" ) then text = "Guardian killed: " .. Tr(e.n); end
		if ( e.k == "bossdown" and e.n and e.n ~= "" ) then text = "Boss killed: " .. Tr(e.n); end
		if ( e.k == "endless" ) then text = "Endless mode started"; end
		table.insert(out, { t = e.t, text = text, icon = info[1], c = info[2] });
	end
	for i = 1, table.getn(run.loot or {}) do
		local l = run.loot[i];
		table.insert(out, { t = l.t or run.t, text = "Loot: " .. Tr(l.n) .. (l.new and "  |cff40ff40NEW|r" or ""),
			icon = l.i, c = QUALITY[l.q or 1] or TEXT });
	end
	for lvl, t in pairs(run.levels or {}) do
		if ( math.mod(lvl, 5) == 0 ) then
			table.insert(out, { t = t, text = "Level " .. lvl, icon = "Spell_Holy_HolyBolt", c = LABEL });
		end
	end
	table.sort(out, function(a, b) return (a.t or 0) < (b.t or 0); end);
	local res = RESULT[run.result] or RESULT.quit;
	table.insert(out, { t = run.t, text = res[1] .. string.format(" · level %s", tostring(run.lvl or "?")),
		icon = run.result == "victory" and "INV_Misc_Head_Dragon_01" or "Ability_Rogue_FeignDeath", c = res[2] });
	return out;
end

function DRAW.timeline(v, run)
	local items = Timeline(run);
	local most = math.max(0, table.getn(items) - TIMELINE_ROWS);
	v.offset = math.max(0, math.min(v.offset or 0, most));
	for i = 1, math.min(TIMELINE_ROWS, table.getn(items) - v.offset) do
		local it = items[i + v.offset];
		local y = -(i - 1) * 17;
		local t = VText(v, BODY_FONT, 12, VALUE, "RIGHT");
		t:SetPoint("TOPRIGHT", v, "TOPLEFT", 52, y - 1);
		t:SetText(Clock(it.t));
		local s = VSlot(v, 16);
		s:SetPoint("TOPLEFT", v, "TOPLEFT", 60, y);
		s:Set(it.icon or QUESTION, { 0.25, 0.25, 0.25 });
		s:EnableMouse(false);
		local fs = VText(v, BODY_FONT, 12, it.c or TEXT, "LEFT");
		fs:SetPoint("TOPLEFT", v, "TOPLEFT", 82, y - 1);
		fs:SetWidth(VW - 104);
		fs:SetHeight(14);
		fs:SetText(it.text);
	end
	if ( table.getn(items) > TIMELINE_ROWS ) then
		local hint = VText(v, BODY_FONT, 10, MUTED, "RIGHT");
		hint:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -16, 0);
		hint:SetText(string.format("%d-%d of %d", v.offset + 1,
			math.min(v.offset + TIMELINE_ROWS, table.getn(items)), table.getn(items)));
	end
	v.bar:Sync(v.offset, most, TIMELINE_ROWS, table.getn(items));
end

views.timeline:EnableMouseWheel(true);
views.timeline:SetScript("OnMouseWheel", function()
	this.offset = (this.offset or 0) - arg1 * 3;
	Refresh();
end);
views.timeline.bar = Scrollbar(views.timeline, TIMELINE_ROWS * 17, function(offset)
	views.timeline.offset = offset;
	Refresh();
end);
views.timeline.bar.wheelStep = 3;
views.timeline.bar:SetPoint("TOPRIGHT", views.timeline, "TOPRIGHT", 0, 0);

views.talents:EnableMouseWheel(true);
views.talents:SetScript("OnMouseWheel", function()
	this.offset = (this.offset or 0) - arg1;
	Refresh();
end);
views.talents.bar = Scrollbar(views.talents, TALENT_ROWS * TALENT_H - 6, function(offset)
	views.talents.offset = offset;
	Refresh();
end);
views.talents.bar:SetPoint("TOPRIGHT", views.talents, "TOPRIGHT", 0, -28);


local function DrawDetail(run)
	for i = 1, table.getn(TABS) do views[TABS[i]]:Hide(); end
	if ( not run ) then
		dTitle:SetText("");
		dSub:SetText("");
		dMeta:SetText("");
		for i = 1, table.getn(TABS) do tabButtons[TABS[i]]:Hide(); end
		delete:Hide();
		position:SetText("");
		dEmpty:SetText("This window shows each run after it ends. It shows your spells, your items, your loot, your stats and more.");
		return;
	end
	dEmpty:SetText("");
	delete:Show();
	local res = RESULT[run.result] or RESULT.quit;
	if ( run.won ) then res = RESULT.victory; end
	dTitle:SetText(Tr(res[1]));
	Color(dTitle, res[2]);
	dSub:SetText(string.format("%s, %s %s · %s", run.hero or "?", Tr(run.rname or run.race) or "", Tr(run.cname) or "", Tr(run.zname) or "?"));
	local meta = DateText(run.ended or run.started);
	if ( run.zsub and run.zsub ~= "" ) then meta = meta .. " · " .. Tr(run.zsub); end
	if ( run.mods and run.mods ~= "" and run.mods ~= "100 100 100 100" ) then
		local _, _, a, b, c, d = string.find(run.mods, "(%d+) (%d+) (%d+) (%d+)");
		meta = meta .. string.format(" · density %s%% health %s%% damage %s%% speed %s%%", a or "?", b or "?", c or "?", d or "?");
	else
		meta = meta .. " · Normal difficulty";
	end
	if ( run.official ) then
		meta = meta .. string.format(" · zone complete at %s, endless mode until %s", Clock(run.official.t), Clock(run.t));
	elseif ( run.won and run.result ~= "victory" ) then
		meta = meta .. " · zone complete, then endless mode";
	end
	dMeta:SetText(meta);
	local tab = db.settings.tab or "summary";
	if ( not views[tab] ) then tab = "summary"; end
	for i = 1, table.getn(TABS) do
		local b = tabButtons[TABS[i]];
		b:Show();
		b.selected = (TABS[i] == tab);
		b:Paint();
	end
	if ( run.id ~= detail.runId ) then
		detail.runId = run.id;
		for i = 1, table.getn(TABS) do views[TABS[i]].offset = 0; end
	end
	local v = views[tab];
	Reset(v);
	DRAW[tab](v, run);
	v:Show();
end

local function Summary()
	local n, wins, longest, kills = table.getn(db.runs), 0, 0, 0;
	for i = 1, n do
		local r = db.runs[i];
		if ( r.won or r.result == "victory" ) then wins = wins + 1; end
		if ( (r.t or 0) > longest ) then longest = r.t; end
		if ( (r.kills or 0) > kills ) then kills = r.kills; end
	end
	if ( n == 0 ) then return "No runs"; end
	return string.format("%d %s  ·  %d %s  ·  longest %s  ·  most kills %s", n, n == 1 and "run" or "runs",
		wins, wins == 1 and "victory" or "victories", Clock(longest), Comma(kills));
end

Refresh = function()
	if ( not db or not frame:IsShown() ) then return; end
	summary:SetText(Summary());
	local filter = db.settings.filter or "all";
	for key, b in pairs(filterButtons) do
		b.selected = (key == filter);
		b:Paint();
	end
	local class = db.settings.class;
	classButton.text:SetText(class and ((CLASSES[class] and "Only " .. (LangKey("class." .. class .. ".name") or (string.upper(string.sub(class, 1, 1)) .. string.sub(class, 2)))) or class) or "All classes");
	shown = {};
	for i = 1, table.getn(db.runs) do
		if ( RunMatches(db.runs[i], filter, class) ) then table.insert(shown, i); end
	end
	local offset = math.max(0, math.min(db.settings.offset or 0, math.max(0, table.getn(shown) - ROWS)));
	db.settings.offset = offset;
	local found;
	for i = 1, table.getn(shown) do
		if ( db.runs[shown[i]].id == selectedId ) then found = 1; end
	end
	if ( not found ) then selectedId = shown[1] and db.runs[shown[1]].id; end

	for i = 1, ROWS do
		local row = rows[i];
		local index = shown[i + offset];
		local r = index and db.runs[index];
		if ( r ) then
			row.runId = r.id;
			local cls = CLASSES[r.class or ""] or { QUESTION, 0.75, 0.75, 0.8 };
			row.icon:Set(cls[1], { cls[2], cls[3], cls[4] });
			row.name:SetText(string.format("%s |cff9d9d9d%s|r", r.hero or "?", tostring(r.lvl or "?")));
			row.name:SetTextColor(cls[2], cls[3], cls[4]);
			row.zone:SetText(Tr(r.zname) or "?");
			local res = RESULT[r.result] or RESULT.quit;
			local label = res[3];
			if ( r.won and r.result ~= "victory" ) then label = "Victory+"; end
			row.result:SetText(Tr(label) .. "  " .. Clock(r.t));
			Color(row.result, (r.won or r.result == "victory") and WIN or res[2]);
			row.when:SetText(DayText(r.ended or r.started) .. " " .. DateText(r.ended or r.started, "%H:%M"));
			row:Show();
			row:Paint();
		else
			row.runId = nil;
			row:Hide();
		end
	end
	if ( table.getn(shown) == 0 ) then
		listEmpty:SetText(table.getn(db.runs) == 0 and "No runs.\n\nWhen a run ends, the addon records it here." or "No runs show with this filter.");
	else
		listEmpty:SetText("");
	end
	listBar:Sync(offset, table.getn(shown) - ROWS, ROWS, table.getn(shown));
	local run, index = Selected();
	DrawDetail(run);
	if ( run ) then
		local at = 0;
		for i = 1, table.getn(shown) do if ( shown[i] == index ) then at = i; end end
		position:SetText(string.format("Run %d of %d", at, table.getn(shown)));
	end
end

local HUD_PARTS = { "banners", "clock", "tally", "bosses", "loot", "levels" };

local function HideHud()
	if ( not AZS_SetHudShown or not AZS_IsHudShown or db.settings.hudHidden ) then return; end
	local hidden = {};
	for i = 1, table.getn(HUD_PARTS) do
		if ( AZS_IsHudShown(HUD_PARTS[i]) ) then
			AZS_SetHudShown(HUD_PARTS[i], false);
			table.insert(hidden, HUD_PARTS[i]);
		end
	end
	db.settings.hudHidden = hidden;
end

local function RestoreHud()
	local hidden = db and db.settings.hudHidden;
	if ( not hidden or not AZS_SetHudShown ) then return; end
	for i = 1, table.getn(hidden) do AZS_SetHudShown(hidden[i], true); end
	db.settings.hudHidden = nil;
end

local hudWait = 0;
frame:SetScript("OnUpdate", function()
	hudWait = hudWait + arg1;
	if ( hudWait < 0.2 ) then return; end
	hudWait = 0;
	if ( AZS_GetPhase and AZS_GetPhase() == "ready" ) then HideHud(); else RestoreHud(); end
end);

frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	DetectLang();
	if ( AZS_GetPhase and AZS_GetPhase() == "ready" ) then HideHud(); end
	Refresh();
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	RestoreHud();
end);

function AZSHistory_Toggle()
	if ( frame:IsShown() ) then frame:Hide(); else frame:Show(); end
end

BINDING_HEADER_AZSHISTORY = "Run History";
BINDING_NAME_AZSHISTORY_TOGGLE = "Open Run History";

local mm = CreateFrame("Button", "AZSHistoryMinimapButton", Minimap);
mm:SetWidth(31);
mm:SetHeight(31);
mm:SetFrameStrata("MEDIUM");
mm:SetFrameLevel(8);
if ( mm.SetHighlightTexture ) then mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); end
local mmIcon = mm:CreateTexture(nil, "BACKGROUND");
mmIcon:SetTexture(ICONS .. "INV_Misc_Book_09");
mmIcon:SetWidth(20);
mmIcon:SetHeight(20);
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5);
local mmBorder = mm:CreateTexture(nil, "OVERLAY");
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
mmBorder:SetWidth(53);
mmBorder:SetHeight(53);
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0);
mm:RegisterForClicks("LeftButtonUp");
mm:RegisterForDrag("LeftButton");

local function PlaceMinimapButton()
	local a = math.rad(db.settings.mm or 205);
	mm:ClearAllPoints();
	mm:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - 80 * math.cos(a), 80 * math.sin(a) - 52);
end

mm:SetScript("OnClick", function() AZSHistory_Toggle(); end);
local function DragMinimapButton()
	local mx, my = Minimap:GetCenter();
	local px, py = GetCursorPosition();
	local s = Minimap:GetEffectiveScale();
	db.settings.mm = math.deg(math.atan2(py / s - my, mx - px / s));
	PlaceMinimapButton();
end

mm:SetScript("OnDragStart", function() this:SetScript("OnUpdate", DragMinimapButton); end);
mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil); end);
mm:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT");
	GameTooltip:SetText("Run History", 1, 1, 1);
	GameTooltip:AddLine(Summary(), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	GameTooltip:AddLine("Click to open. Drag to move.", MUTED[1], MUTED[2], MUTED[3]);
	GameTooltip:Show();
end);
mm:SetScript("OnLeave", function() GameTooltip:Hide(); end);

SLASH_AZSHISTORY1 = "/runs";
SLASH_AZSHISTORY2 = "/runhistory";
SLASH_AZSHISTORY3 = "/azh";
local function ApplyKey()
	local key = db and db.settings.key;
	if ( key and SetBinding ) then SetBinding(key, "AZSHISTORY_TOGGLE"); end
end

local function SetKey(key)
	if ( key == "" ) then
		Print(db.settings.key and ("The key for the history is " .. db.settings.key .. ".") or "The history has no key. Type /runs key <key> to set one. Example: /runs key F8.");
		return;
	end
	if ( db.settings.key and SetBinding ) then SetBinding(db.settings.key); end
	if ( key == "NONE" ) then
		db.settings.key = nil;
		Print("The history has no key now.");
		return;
	end
	local old = GetBindingAction and GetBindingAction(key);
	db.settings.key = key;
	ApplyKey();
	if ( old and old ~= "" and old ~= "AZSHISTORY_TOGGLE" ) then
		Print("The key " .. key .. " opens the history now. It no longer does " .. (getglobal("BINDING_NAME_" .. old) or old) .. ".");
	else
		Print("The key " .. key .. " opens the history now.");
	end
end

SlashCmdList["AZSHISTORY"] = function(msg)
	msg = string.lower(msg or "");
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$");
	if ( cmd == "key" ) then
		SetKey(string.upper(rest));
	elseif ( cmd == "minimap" ) then
		db.settings.hideMinimap = not db.settings.hideMinimap;
		if ( db.settings.hideMinimap ) then mm:Hide(); else mm:Show(); end
		Print(db.settings.hideMinimap and "The minimap button is hidden. Type /runs minimap to show it." or "The minimap button is shown.");
	elseif ( cmd == "tz" ) then
		local h = tonumber(rest);
		db.settings.tz = h;
		Print(h and string.format("Times show in UTC%+g.", h) or "Times show in UTC.");
		Refresh();
	elseif ( cmd == "help" ) then
		Print("Type /runs to open or close the history. Type /runs minimap to show or hide the minimap button. Type /runs key <key> to set a key for the history. Type /runs key none to remove it. Type /runs tz <hours> to set your time zone in hours from UTC. Example: /runs tz -5.");
	else
		AZSHistory_Toggle();
	end
end;

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("PLAYER_LOGOUT");
events:RegisterEvent("CHAT_MSG_ADDON");
events:RegisterEvent("CHAT_MSG_SYSTEM");
events:RegisterEvent("CHAT_MSG_LOOT");
local CHAT_EVENTS = { CHAT_MSG_SYSTEM = 1, CHAT_MSG_LOOT = 1 };
local EXTRA_CHAT = { "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_RAID_BOSS_EMOTE", "UI_INFO_MESSAGE" };
for i = 1, table.getn(EXTRA_CHAT) do
	if ( pcall(events.RegisterEvent, events, EXTRA_CHAT[i]) ) then CHAT_EVENTS[EXTRA_CHAT[i]] = 1; end
end
events:RegisterEvent("UNIT_INVENTORY_CHANGED");
events:RegisterEvent("UPDATE_INVENTORY_ALERTS");
events:RegisterEvent("SPELLS_CHANGED");

local function Init()
	AZSHistoryDB = AZSHistoryDB or {};
	db = AZSHistoryDB;
	db.runs = db.runs or {};
	db.names = db.names or {};
	db.icons = db.icons or {};
	db.settings = db.settings or {};
	db.diag = nil; db.tl = nil;
	SetLang(db.lang);
	db.version = 2;
	for i = table.getn(db.runs), 1, -1 do
		local r = db.runs[i];
		if ( (tonumber(r.t) or 0) < 1 and (tonumber(r.kills) or 0) == 0 ) then table.remove(db.runs, i); end
	end
	RestoreHud();
	if ( db.settings.point ) then
		local p = db.settings.point;
		frame:ClearAllPoints();
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]);
	end
	PlaceMinimapButton();
	if ( db.settings.hideMinimap ) then mm:Hide(); end
	if ( AZS_RegisterBannerHandler ) then AZS_RegisterBannerHandler(OnBanner); end
end

local scanWait = 0;
events:SetScript("OnUpdate", function()
	if ( not cur ) then return; end
	scanWait = scanWait + arg1;
	if ( scanWait < 0.5 ) then return; end
	scanWait = 0;
	ScanJewels();
	local ph = AZS_GetPhase and AZS_GetPhase();
	if ( ph ~= "victory" and ph ~= "dead" ) then KeepJewelLines(); KeepSpellLines(); end
end);

events:SetScript("OnEvent", function()
	if ( event == "ADDON_LOADED" ) then
		if ( arg1 == ADDON ) then Init(); end
		return;
	end
	if ( not db ) then return; end
	if ( event == "CHAT_MSG_ADDON" ) then
		if ( arg1 == "AZSRUN" ) then
			OnRun();
		elseif ( arg1 == "AZSZONE" ) then
			DetectLang();
			OnZone();
		elseif ( arg1 == "AZSSPELLS" ) then
			if ( not cur ) then OnRun(); end
			ScanSpells();
		elseif ( arg1 == "AZSMETER" ) then
			ScanTalents(AZS_METER);
		elseif ( arg1 == "AZSHEAL" ) then
			ScanTalents(AZS_HEALING);
		elseif ( arg1 == "AZSTIMERS" ) then
			ScanTimers();
		elseif ( arg1 == "AZSEND" ) then
			if ( AZS_END and AZS_END.result ) then
				if ( not cur and db.current ) then Resume(); end
				if ( cur ) then Finalize(AZS_END, AZS_END.result); end
			else
				Reopen();
			end
		end
	elseif ( CHAT_EVENTS[event] ) then
		OnChat(arg1);
	elseif ( event == "UNIT_INVENTORY_CHANGED" or event == "UPDATE_INVENTORY_ALERTS" ) then
		if ( cur and (event ~= "UNIT_INVENTORY_CHANGED" or arg1 == "player") ) then ScanJewels(); end
	elseif ( event == "SPELLS_CHANGED" ) then
		LearnSpellbook();
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		LearnSpellbook();
		DetectLang();
		ApplyKey();
	elseif ( event == "PLAYER_LOGOUT" ) then
		if ( cur ) then CaptureEnd(); end
		RestoreHud();
	end
end);
