local ADDON = "AZSHistory";
local TITLE_FONT = "Fonts\\MORPHEUS.TTF";
local BODY_FONT = "Fonts\\FRIZQT__.TTF";
local WHITE = "Interface\\Buttons\\WHITE8X8";
local ICONS = "Interface\\Icons\\";
local QUESTION = "INV_Misc_QuestionMark";
local MAX_RUNS = 50;

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
local function L(text)
	local custom, strings = AZSHistory_Custom, AZSHistory_Strings;
	return (custom and custom[text]) or (strings and strings[text]) or text;
end

local function LF(key, a, b, c, d)
	local ok, text = pcall(string.format, L(key), a, b, c, d);
	if ( ok ) then return text; end
	return string.format(key, a, b, c, d);
end

local RARITY = { [0] = L("Poor"), [1] = L("Common"), [2] = L("Uncommon"), [3] = L("Rare"), [4] = L("Epic"), [5] = L("Legendary") };

local RESULT = {
	victory = { L("Victory!"), WIN, L("Victory") },
	defeat = { L("You died"), LOSS, L("Died") },
	left = { L("You left the run"), LOSS, L("Left") },
	quit = { L("The run stopped before its end"), MUTED, L("Stopped") },
};

local db;
local cur;
local lastEndedAt;
local pendingSig, pendingAt;
local Refresh;

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L("Run History") .. ":|r " .. msg);
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
	if ( day == today ) then return L("Today"); end
	if ( day == today - 1 ) then return L("Yesterday"); end
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

local function SpellById(id)
	local entry = AZSHistory_Spells and AZSHistory_Spells[id];
	if ( not entry ) then return nil; end
	local _, _, name, icon = string.find(entry, "^(.*)|(%d*)$");
	return name, icon and AZSHistory_SpellIcons and AZSHistory_SpellIcons[tonumber(icon)];
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

local ScanSpells, ScanTalents, ScanTimers, ScanJewels, KeepSpellLines, HasStats, KeepJewelLines,
	ScanPets, NoteBuffs, CaptureEnd, Finalize, Reopen, Resume, OnZone, OnRun, OnChat, OnBanner;

do
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
		local lives, rerolls = tonumber(r.lives), tonumber(r.rr);
		if ( lives ) then
			if ( cur.lv and lives < cur.lv ) then
				cur.livesUsed = (cur.livesUsed or 0) + (cur.lv - lives);
				AddEvent("life", nil, nil);
			end
			cur.lv = lives;
		end
		if ( rerolls ) then
			if ( cur.rrv and rerolls < cur.rrv ) then cur.rerollsUsed = (cur.rerollsUsed or 0) + (cur.rrv - rerolls); end
			cur.rrv = rerolls;
		end
	end

	local spellWait = 0;

	function ScanSpells()
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

	function ScanTalents(lines)
		if ( not cur ) then return; end
		for i = 1, table.getn(lines or {}) do
			local name = tostring(lines[i].name);
			if ( lines[i].proc == 1 or OwnTalent(cur.class, name) ) then NoteTalent(name); end
		end
	end

	function ScanTimers()
		if ( not cur ) then return; end
		local list = AZS_TIMERS or {};
		for i = 1, table.getn(list) do
			NoteTalent(tostring(list[i].name), list[i].icon, tonumber(list[i].wait));
		end
	end

	function ScanJewels(force)
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

	function KeepSpellLines()
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

	function HasStats(lines)
		return lines and table.getn(lines) > 3;
	end

	function KeepJewelLines()
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

	function ScanPets()
		if ( not cur ) then return; end
		local list = AZS_PETS or {};
		if ( table.getn(list) == 0 ) then return; end
		cur.pets = cur.pets or {};
		cur.petIds = cur.petIds or {};
		cur.petN = (cur.petN or 0) + 1;
		if ( cur.petN > 300 ) then
			local keep = {};
			for i = 1, table.getn(list) do keep[tostring(list[i].id)] = 1; end
			cur.petIds = keep;
			cur.petN = 0;
		end
		for i = 1, table.getn(list) do
			local p = list[i];
			local name = tostring(p.name or "");
			local id = tostring(p.id);
			if ( name ~= "" and not cur.petIds[id] ) then
				cur.petIds[id] = 1;
				local e = cur.pets[name];
				if ( not e ) then
					e = { c = 0, at = Now() };
					cur.pets[name] = e;
				end
				e.c = e.c + 1;
			end
		end
	end

	function NoteBuffs()
		if ( not cur ) then return; end
		local list = AZS_BUFFS or {};
		local t = Now();
		cur.buffs = cur.buffs or {};
		local was, last = cur.bnow or {}, cur.bt or t;
		local now = {};
		for i = 1, table.getn(list) do
			local id = tonumber(list[i].spell);
			if ( id and not now[id] and SpellById(id) ~= "Divine Shield" ) then
				now[id] = true;
				local b = cur.buffs[id];
				if ( not b ) then
					b = { c = 0, up = 0, at = t };
					cur.buffs[id] = b;
				end
				if ( not was[id] ) then b.c = b.c + 1; end
			end
		end
		for id in pairs(was) do
			local b = cur.buffs[id];
			if ( b ) then b.up = b.up + math.max(0, t - last); end
		end
		cur.bnow = now;
		cur.bt = t;
	end

	function CaptureEnd()
		if ( not cur ) then return; end
		ScanSpells();
		ScanPets();
		NoteBuffs();
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
		local count = 0;
		for i = 1, table.getn(db.runs) do
			if ( not db.runs[i].star ) then count = count + 1; end
		end
		local removed = 0;
		for i = table.getn(db.runs), 1, -1 do
			if ( count <= MAX_RUNS ) then break; end
			if ( not db.runs[i].star ) then
				table.remove(db.runs, i);
				count = count - 1;
				removed = removed + 1;
			end
		end
		return removed;
	end

	function Finalize(e, result, stale)
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
		r.jl = nil; r.jlTry = nil; r.sl = nil; r.lv = nil; r.rrv = nil; r.petIds = nil; r.petN = nil; r.bnow = nil; r.bt = nil;
		if ( r.result ~= "quit" ) then r.snap = nil; end
		table.insert(db.runs, 1, r);
		local removed = Prune();
		if ( removed > 0 ) then
			if ( removed == 1 ) then
				Print(LF("The history keeps your last %d runs that are not starred. The addon removed %d old run. Star a run to keep it.", MAX_RUNS, removed));
			else
				Print(LF("The history keeps your last %d runs that are not starred. The addon removed %d old runs. Star a run to keep it.", MAX_RUNS, removed));
			end
		end
		db.current = nil;
		db.lastEnded = r.id;
		cur = nil;
		lastEndedAt = GetTime();
		if ( Refresh ) then Refresh(); end
	end

	function Reopen()
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

	function Resume()
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

	function OnZone()
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

	function OnRun()
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

	function OnBanner(b)
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
		GameTooltip:AddLine(Tr(L("Racial")), GOLD[1], GOLD[2], GOLD[3]);
	else
		GameTooltip:AddLine(LF("Rank %d", s.r or 1), GOLD[1], GOLD[2], GOLD[3]);
	end
	local learned;
	for i = 1, table.getn(run.spells or {}) do
		if ( run.spells[i].key == s.key ) then learned = run.spells[i]; end
	end
	if ( learned and learned.start ) then
		GameTooltip:AddLine(L("You had this spell at the start of the run."), MUTED[1], MUTED[2], MUTED[3]);
	elseif ( learned ) then
		GameTooltip:AddLine(LF("You got this spell at %s.", Clock(learned.at)), MUTED[1], MUTED[2], MUTED[3]);
	end
	local ups = "";
	for i = 1, table.getn(run.picks or {}) do
		local p = run.picks[i];
		if ( p.k == "rank" and p.key == s.key ) then
			ups = ups .. (ups == "" and "" or ", ") .. LF("rank %d at %s", p.r, Clock(p.t));
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

local ROWS, ui, RunMatches, TABS, VW;

do
	local W, H = 860, 590;
	local LIST_W = 276;
	local ROW_H, ROW_GAP = 46, 3;
	ROWS = 9;

	ui = {};

	ui.frame = CreateFrame("Frame", "AZSHistoryFrame", UIParent);
	ui.frame:SetWidth(W);
	ui.frame:SetHeight(H);
	ui.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20);
	ui.frame:SetFrameStrata("DIALOG");
	ui.frame:SetToplevel(true);
	ui.frame:SetMovable(true);
	ui.frame:SetClampedToScreen(true);
	ui.frame:EnableMouse(true);
	ui.frame:Hide();
	Panel(ui.frame, 0.96);
	if ( UISpecialFrames ) then table.insert(UISpecialFrames, "AZSHistoryFrame"); end

	ui.grip = CreateFrame("Frame", nil, ui.frame);
	ui.grip:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 0, 0);
	ui.grip:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -46, 0);
	ui.grip:SetHeight(70);
	ui.grip:EnableMouse(true);
	ui.grip:RegisterForDrag("LeftButton");
	ui.grip:SetScript("OnDragStart", function() ui.frame:StartMoving(); end);
	ui.grip:SetScript("OnDragStop", function()
		ui.frame:StopMovingOrSizing();
		local p, _, rp, x, y = ui.frame:GetPoint();
		db.settings.point = { p, rp, x, y };
	end);

	ui.title = Text(ui.frame, TITLE_FONT, 30, GOLD, "CENTER");
	ui.title:SetPoint("TOP", ui.frame, "TOP", 0, -14);
	ui.title:SetText(L("Run History"));
	ui.summary = Text(ui.frame, BODY_FONT, 12, LABEL, "CENTER");
	ui.summary:SetPoint("TOP", ui.frame, "TOP", 0, -50);

	ui.close = Button(ui.frame, 26, 26, "X", "tab");
	ui.close:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -12, -12);
	ui.close:SetScript("OnClick", function() ui.frame:Hide(); end);

	ui.list = CreateFrame("Frame", nil, ui.frame);
	ui.list:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 14, -74);
	ui.list:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 14, 14);
	ui.list:SetWidth(LIST_W);
	Panel(ui.list, 0.6);
	ui.list:EnableMouseWheel(true);

	local FILTERS = { "all", "victory", "lost", "starred" };
	local FILTER_LABEL = { all = L("All runs"), victory = L("Victories"), lost = L("Died"), starred = L("Starred") };
	ui.filterButtons = {};
	for i = 1, 4 do
		local key = FILTERS[i];
		local b = Button(ui.list, 62, 22, FILTER_LABEL[key], "tab");
		b:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 9 + (i - 1) * 66, -9);
		b:SetScript("OnClick", function()
			db.settings.filter = key;
			db.settings.offset = 0;
			Refresh();
		end);
		ui.filterButtons[key] = b;
	end

	ui.classButton = Button(ui.list, 170, 20, L("All classes"), "tab");
	ui.classButton:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 11, -36);
	ui.classButton.text:SetFont(BODY_FONT, 11);

	ui.trendButton = Button(ui.list, 80, 20, L("Trends"), "tab");
	ui.trendButton:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 185, -36);
	ui.trendButton.text:SetFont(BODY_FONT, 11);
	ui.trendButton:SetScript("OnClick", function()
		db.settings.trends = (not db.settings.trends) and 1 or nil;
		Refresh();
	end);

	ui.listEmpty = Text(ui.list, BODY_FONT, 12, MUTED, "CENTER");
	ui.listEmpty:SetPoint("CENTER", ui.list, "CENTER", 0, 0);
	ui.listEmpty:SetWidth(LIST_W - 30);

	ui.listBar = Scrollbar(ui.list, ROWS * (ROW_H + ROW_GAP) - ROW_GAP, function(offset)
		db.settings.offset = offset;
		Refresh();
	end);
	ui.listBar:SetPoint("TOPRIGHT", ui.list, "TOPRIGHT", -8, -62);

	ui.rows = {};
	ui.shown = {};

	function RunMatches(r, filter, class)
		if ( class and r.class ~= class ) then return false; end
		if ( filter == "victory" ) then return r.won == 1 or r.result == "victory"; end
		if ( filter == "lost" ) then return r.result ~= "victory" and not r.won; end
		if ( filter == "starred" ) then return r.star == 1; end
		return true;
	end

	for i = 1, ROWS do
		local row = CreateFrame("Button", nil, ui.list);
		row:SetWidth(LIST_W - 34);
		row:SetHeight(ROW_H);
		row:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 9, -62 - (i - 1) * (ROW_H + ROW_GAP));
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
		row.star = Solid(row, "ARTWORK", GOLD, 1);
		row.star:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1);
		row.star:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1);
		row.star:SetWidth(3);
		row.star:Hide();
		row:SetScript("OnEnter", function() this.hover = 1; this:Paint(); end);
		row:SetScript("OnLeave", function() this.hover = nil; this:Paint(); end);
		row:SetScript("OnClick", function()
			if ( this.runId ) then
				ui.selectedId = this.runId;
				db.settings.trends = nil;
				Refresh();
			end
		end);
		function row:Paint()
			if ( self.runId and self.runId == ui.selectedId ) then
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
		ui.rows[i] = row;
	end

	ui.list:SetScript("OnMouseWheel", function()
		local most = math.max(0, table.getn(ui.shown) - ROWS);
		db.settings.offset = math.max(0, math.min(most, (db.settings.offset or 0) - arg1));
		Refresh();
	end);

	ui.classButton:SetScript("OnClick", function()
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

	ui.detail = CreateFrame("Frame", nil, ui.frame);
	ui.detail:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 14 + LIST_W + 12, -74);
	ui.detail:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -14, 14);
	Panel(ui.detail, 0.6);

	ui.dTitle = Text(ui.detail, TITLE_FONT, 30, LOSS, "CENTER");
	ui.dTitle:SetPoint("TOP", ui.detail, "TOP", 0, -12);
	ui.dSub = Text(ui.detail, BODY_FONT, 14, TEXT, "CENTER");
	ui.dSub:SetPoint("TOP", ui.detail, "TOP", 0, -50);
	ui.dMeta = Text(ui.detail, BODY_FONT, 11, MUTED, "CENTER");
	ui.dMeta:SetPoint("TOP", ui.detail, "TOP", 0, -69);
	ui.dMeta:SetWidth(520);
	ui.dMeta:SetHeight(14);
	ui.dEmpty = Text(ui.detail, BODY_FONT, 13, MUTED, "CENTER");
	ui.dEmpty:SetPoint("CENTER", ui.detail, "CENTER", 0, 0);
	ui.dEmpty:SetWidth(380);

	TABS = { "summary", "build", "talents", "buffs", "damage", "hero", "timeline" };
	local TAB_LABEL = { summary = L("Summary"), build = L("Build"), talents = L("Talents"), buffs = L("Buffs"), damage = L("Damage"),
		hero = L("Stats"), timeline = L("Timeline") };
	ui.tabButtons = {};
	for i = 1, table.getn(TABS) do
		local key = TABS[i];
		local b = Button(ui.detail, 72, 22, TAB_LABEL[key], "tab");
		b:SetPoint("TOP", ui.detail, "TOP", (i - (table.getn(TABS) + 1) / 2) * 75, -88);
		b:SetScript("OnClick", function()
			db.settings.tab = key;
			Refresh();
		end);
		ui.tabButtons[key] = b;
	end

	ui.views = {};
	for i = 1, table.getn(TABS) do
		local v = CreateFrame("Frame", nil, ui.detail);
		v:SetPoint("TOPLEFT", ui.detail, "TOPLEFT", 14, -120);
		v:SetPoint("BOTTOMRIGHT", ui.detail, "BOTTOMRIGHT", -14, 44);
		v.pool = {};
		v.used = {};
		v:Hide();
		ui.views[TABS[i]] = v;
	end

	ui.trendKeys = { "spells", "jewels", "zones", "classes" };
	local TREND_LABEL = { spells = L("Spells"), jewels = L("Jewelry"), zones = L("Zones"), classes = L("Classes") };
	ui.trendButtons = {};
	ui.trendViews = {};
	for i = 1, table.getn(ui.trendKeys) do
		local key = ui.trendKeys[i];
		local b = Button(ui.detail, 90, 22, TREND_LABEL[key], "tab");
		b:SetPoint("TOP", ui.detail, "TOP", (i - (table.getn(ui.trendKeys) + 1) / 2) * 94, -88);
		b:SetScript("OnClick", function()
			db.settings.trendTab = key;
			Refresh();
		end);
		b:Hide();
		ui.trendButtons[key] = b;
		local v = CreateFrame("Frame", nil, ui.detail);
		v:SetPoint("TOPLEFT", ui.detail, "TOPLEFT", 14, -120);
		v:SetPoint("BOTTOMRIGHT", ui.detail, "BOTTOMRIGHT", -14, 44);
		v.pool = {};
		v.used = {};
		v:Hide();
		ui.trendViews[key] = v;
	end
	VW = W - 14 - LIST_W - 12 - 14 - 28;
end

ui.delete = Button(ui.detail, 140, 24, L("Delete run"), "red");
ui.delete.text:SetFont(BODY_FONT, 12);
ui.delete:SetPoint("BOTTOMLEFT", ui.detail, "BOTTOMLEFT", 12, 12);
ui.starButton = Button(ui.detail, 100, 24, L("Star run"), "tab");
ui.starButton:SetPoint("BOTTOMLEFT", ui.detail, "BOTTOMLEFT", 160, 12);
ui.starButton.text:SetFont(BODY_FONT, 12);
ui.position = Text(ui.detail, BODY_FONT, 11, MUTED, "RIGHT");
ui.position:SetPoint("BOTTOMRIGHT", ui.detail, "BOTTOMRIGHT", -14, 18);

local function Selected()
	for i = 1, table.getn(db.runs) do
		if ( db.runs[i].id == ui.selectedId ) then return db.runs[i], i; end
	end
end

do
	local function DisarmDelete()
		if ( this.armed and GetTime() - this.armed >= 4 ) then
			this.armed = nil;
			this.text:SetText(L("Delete run"));
			this:SetScript("OnUpdate", nil);
		end
	end

	ui.starButton:SetScript("OnClick", function()
		local run = Selected();
		if ( not run ) then return; end
		run.star = (not run.star) and 1 or nil;
		Refresh();
	end);

	ui.delete:SetScript("OnClick", function()
		local run, index = Selected();
		if ( not run ) then return; end
		if ( this.armed and GetTime() - this.armed < 4 ) then
			table.remove(db.runs, index);
			if ( index == 1 ) then lastEndedAt = nil; end
			this.armed = nil;
			this:SetScript("OnUpdate", nil);
			this.text:SetText(L("Delete run"));
			local nextRun = db.runs[index] or db.runs[index - 1];
			ui.selectedId = nextRun and nextRun.id;
			Refresh();
			return;
		end
		this.armed = GetTime();
		this.text:SetText(L("Push again to delete"));
		this:SetScript("OnUpdate", DisarmDelete);
	end);
end

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
			tag:SetText(Tr(L("NEW")));
		end
	end
	local rowsUsed = math.ceil(n / cols);
	local y2 = y - rowsUsed * 28;
	if ( table.getn(items) > most ) then
		local more = VText(v, BODY_FONT, 11, MUTED, "CENTER");
		more:SetPoint("TOP", v, "TOPLEFT", VW / 2, y2);
		more:SetText(LF("+%d more", table.getn(items) - most));
		y2 = y2 - 16;
	end
	return y2;
end

local DRAW = {};

function DRAW.summary(v, run)
	local y = 0;
	local lines = {};
	if ( (run.tpoints or 0) > 0 ) then
		table.insert(lines, { (run.tpoints == 1) and L("+1 talent point!") or LF("+%d talent points!", run.tpoints), TEXT });
	end
	for i = 1, table.getn(run.unlocked or {}) do
		table.insert(lines, { LF("New zone opened: %s", Tr(run.unlocked[i])), GREEN });
	end
	for i = 1, table.getn(run.achievements or {}) do
		table.insert(lines, { LF("Achievement: %s", Tr(run.achievements[i])), GOLD });
	end
	local newLoot = 0;
	for i = 1, table.getn(run.loot or {}) do
		if ( run.loot[i].new ) then newLoot = newLoot + 1; end
	end
	local boxH = 44 + table.getn(lines) * 18;
	VBox(v, 0, y, VW, boxH);
	local head = VText(v, BODY_FONT, 15, BLUE, "LEFT");
	head:SetPoint("TOPLEFT", v, "TOPLEFT", 14, y - 12);
	head:SetText(L("Talent experience"));
	local xp = VText(v, TITLE_FONT, 22, { 1, 1, 1 }, "RIGHT");
	xp:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 14, y - 8);
	xp:SetText(run.txp and ("+" .. run.txp) or L("None"));
	for i = 1, table.getn(lines) do
		local fs = VText(v, BODY_FONT, 13, lines[i][2], "LEFT");
		fs:SetPoint("TOPLEFT", v, "TOPLEFT", 14, y - 36 - (i - 1) * 18);
		fs:SetText(lines[i][1]);
	end
	y = y - boxH - 12;

	y = Caps(v, LF("LOOT · %d NEW ITEMS", newLoot), 0, y, VW);
	if ( table.getn(run.loot or {}) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y - 2);
		none:SetText(L("No loot dropped in this run."));
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
		{ L("Time"), Clock(run.t) }, { L("Level"), tostring(run.lvl or "?") }, { L("Kills"), Comma(run.kills) },
		{ L("Elites killed"), Comma(run.elites) }, { L("Guardians killed"), Comma(run.guardians) },
		{ L("Bosses killed"), Comma(run.bosses) }, { L("Damage dealt"), Comma(run.dmg) },
		{ L("Damage taken"), Comma(run.taken) }, { L("Gold earned"), Comma(run.gold) },
		{ L("Chests opened"), Comma(run.chests) },
	}, { VW * 0.27, VW * 0.77 });
end

function DRAW.build(v, run)
	local y = Header(v, L("Spells"), 0, 0, VW);
	local build = run.build or {};
	if ( table.getn(build) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		none:SetText(L("The addon did not record spells for this run."));
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
		local pets = {};
		for name, e in pairs(run.pets or {}) do table.insert(pets, { n = name, c = e.c or 1 }); end
		table.sort(pets, function(a, b)
			if ( a.c ~= b.c ) then return a.c > b.c; end
			return a.n < b.n;
		end);
		if ( table.getn(pets) > 0 ) then
			local text = "";
			for i = 1, math.min(6, table.getn(pets)) do
				text = text .. (i > 1 and "  ·  " or "") .. Tr(pets[i].n) .. " x" .. pets[i].c;
			end
			local fs = VText(v, BODY_FONT, 11, MUTED, "CENTER");
			fs:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
			fs:SetWidth(VW - 20);
			fs:SetText(LF("Summons: %s", text));
			y = y - (fs:GetHeight() or 14) - 6;
		end
	end

	y = Header(v, L("Jewelry"), 0, y, VW);
	local jewels = run.jewels or {};
	if ( table.getn(jewels) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		none:SetText(L("You did not wear rings, trinkets or an amulet in this run."));
		y = y - 22;
	else
		local items = {};
		for i = 1, table.getn(jewels) do
			local j = jewels[i];
			table.insert(items, { l = j.l, n = j.n, q = j.q, i = j.i, lines = JewelLines(j) });
		end
		y = LootGrid(v, y, items, 2, 6) - 4;
	end

	y = Header(v, L("Worn gear"), 0, y, VW);
	local gear = run.gear or {};
	if ( table.getn(gear) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
		none:SetText(L("You did not wear gear in this run."));
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

do
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
			if ( info[2] and string.find(info[2], "^Milestone%.") ) then kind = " · " .. L("milestone"); end
			if ( info[2] and string.find(info[2], "^Capstone%.") ) then kind = " · " .. L("capstone"); end
			GameTooltip:AddLine(Tr(info[1]) .. kind, GOLD[1], GOLD[2], GOLD[3]);
			if ( info[2] ) then
				local desc = TalentText(info);
				GameTooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
			end
		else
			GameTooltip:AddLine(L("Damage or healing from a talent or an effect"), GOLD[1], GOLD[2], GOLD[3]);
		end
		if ( t.d and t.d > 0 ) then
			GameTooltip:AddLine(LF("%s damage, %d%% of your damage", Comma(t.d), math.floor((t.s or 0) * 100 + 0.5)), TEXT[1], TEXT[2], TEXT[3]);
		end
		if ( t.h and t.h > 0 ) then GameTooltip:AddLine(LF("%s healing", Comma(t.h)), GREEN[1], GREEN[2], GREEN[3]); end
		if ( t.w ) then GameTooltip:AddLine(LF("Maximum rate: 1 time in %s seconds", Short(t.w)), MUTED[1], MUTED[2], MUTED[3]); end
		local from = Before(run, t);
		if ( from ) then
			GameTooltip:AddLine(LF("The addon started to record this run at %s. This talent was active before that time.", Clock(from)), MUTED[1], MUTED[2], MUTED[3], 1);
		else
			GameTooltip:AddLine(LF("First time at %s", Clock(t.at)), MUTED[1], MUTED[2], MUTED[3]);
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
		local y = Header(v, L("Active talents"), 0, 0, VW);
		if ( table.getn(list) == 0 ) then
			local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
			none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y - 4);
			none:SetWidth(VW - 40);
			none:SetText(L("No talent did damage or healing in this run."));
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
			local kind = info and Tr(info[1]) or L("Talent or effect");
			if ( info and info[2] and string.find(info[2], "^Milestone%.") ) then kind = kind .. " · " .. L("milestone"); end
			if ( info and info[2] and string.find(info[2], "^Capstone%.") ) then kind = kind .. " · " .. L("capstone"); end
			sub:SetText(kind);
			local right = VText(v, BODY_FONT, 12, VALUE, "RIGHT");
			right:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 16, ry - 1);
			if ( t.d and t.d > 0 ) then
				right:SetText(string.format("%s  %d%%", Short(t.d), math.floor((t.s or 0) * 100 + 0.5)));
			elseif ( t.h and t.h > 0 ) then
				right:SetText(LF("healing %s", Short(t.h)));
				Color(right, GREEN);
			else
				right:SetText("");
			end
			local when = VText(v, BODY_FONT, 11, MUTED, "RIGHT");
			when:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 16, ry - 17);
			local from = Before(run, t);
			local at = from and LF("before %s", Clock(from)) or LF("from %s", Clock(t.at));
			if ( t.w ) then
				when:SetText(LF("1 time in %s s · %s", Short(t.w), at));
			else
				when:SetText(at);
			end
		end
		v.bar:Sync(v.offset, most, TALENT_ROWS, table.getn(list));
		local note = VText(v, BODY_FONT, 10, MUTED, "CENTER");
		note:SetPoint("BOTTOM", v, "BOTTOM", 0, 0);
		note:SetWidth(VW - 20);
		note:SetText(L("The addon cannot see talents that only change values. This list shows the talents that did damage, did healing or used a timer."));
	end
end

function DRAW.buffs(v, run)
	local list = {};
	for id, b in pairs(run.buffs or {}) do
		local name, icon = SpellById(id);
		if ( name ~= "Divine Shield" ) then
			table.insert(list, { id = id, n = name or LF("Spell %d", id), i = icon, c = b.c or 1, up = b.up or 0, at = b.at or 0 });
		end
	end
	table.sort(list, function(a, b)
		if ( a.up ~= b.up ) then return a.up > b.up; end
		return a.at < b.at;
	end);
	local y = Header(v, L("Buffs"), 0, 0, VW);
	if ( table.getn(list) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", VW / 2, y - 4);
		none:SetWidth(VW - 40);
		none:SetText(L("The addon did not record buffs for this run."));
	end
	local most = math.max(0, table.getn(list) - TALENT_ROWS);
	v.offset = math.max(0, math.min(v.offset or 0, most));
	local span = math.max(run.t or 1, 1);
	for i = 1, math.min(TALENT_ROWS, table.getn(list) - v.offset) do
		local e = list[i + v.offset];
		local ry = y - (i - 1) * TALENT_H;
		local s = VSlot(v, 30);
		s:SetPoint("TOPLEFT", v, "TOPLEFT", 0, ry);
		s:Set(e.i or QUESTION, RIM);
		s.tip = function()
			GameTooltip:SetText(Tr(e.n), 1, 1, 1);
			GameTooltip:AddLine(LF("Time active: %s", Clock(e.up)), TEXT[1], TEXT[2], TEXT[3]);
		end;
		local name = VText(v, BODY_FONT, 13, GOLD, "LEFT");
		name:SetPoint("TOPLEFT", v, "TOPLEFT", 40, ry - 1);
		name:SetWidth(VW - 210);
		name:SetHeight(15);
		name:SetText(Tr(e.n));
		local sub = VText(v, BODY_FONT, 11, MUTED, "LEFT");
		sub:SetPoint("TOPLEFT", v, "TOPLEFT", 40, ry - 17);
		sub:SetWidth(VW - 210);
		sub:SetHeight(13);
		if ( e.c == 1 ) then
			sub:SetText(LF("Applied 1 time · first at %s", Clock(e.at)));
		else
			sub:SetText(LF("Applied %d times · first at %s", e.c, Clock(e.at)));
		end
		local right = VText(v, BODY_FONT, 12, VALUE, "RIGHT");
		right:SetPoint("TOPRIGHT", v, "TOPLEFT", VW - 16, ry - 1);
		right:SetText(LF("%d%% uptime", math.min(100, math.floor(e.up * 100 / span + 0.5))));
	end
	v.bar:Sync(v.offset, most, TALENT_ROWS, table.getn(list));
	local note = VText(v, BODY_FONT, 10, MUTED, "CENTER");
	note:SetPoint("BOTTOM", v, "BOTTOM", 0, 0);
	note:SetWidth(VW - 20);
	note:SetText(L("This list shows the buffs that the game reported during the run. Uptime is the part of the run that the buff was active."));
end

local TAKEN_LABEL = {
	["boss melee"] = { L("Boss melee"), "Ability_Warrior_Cleave" }, ["boss spell"] = { L("Boss spells"), "Spell_Shadow_ShadowBolt" },
	["elite"] = { L("Elites"), "Ability_Warrior_Charge" }, ["mob melee"] = { L("Mob melee"), "Ability_MeleeDamage" },
	["mob spell"] = { L("Mob spells"), "Spell_Nature_StarFall" }, ["area"] = { L("Ground effects"), "Spell_Fire_Fire" },
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
		if ( l.v ) then
			val:SetText(l.v);
		else
			val:SetText(string.format("%s  %d%%", Short(l.d), math.floor((share or 0) * 100 + 0.5)));
		end
	end
	return y - math.min(table.getn(lines), most) * 20;
end

function DRAW.damage(v, run)
	local cls = CLASSES[run.class or ""] or { nil, 0.75, 0.75, 0.8 };
	local color = { cls[2], cls[3], cls[4] };
	local half = (VW - 16) / 2;
	local y = Header(v, L("Damage done"), 0, 0, half);
	local meter = run.meter or {};
	if ( table.getn(meter) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", half / 2, y);
		none:SetText(L("The addon did not record damage for this run."));
	else
		y = Bars(v, 0, y, half, meter, run.dmg, color, 13);
		local dps = VText(v, BODY_FONT, 11, MUTED, "CENTER");
		dps:SetPoint("TOP", v, "TOPLEFT", half / 2, y - 6);
		dps:SetText(LF("%s total · %s per second", Short(run.dmg), Short((run.dmg or 0) / math.max(run.t or 1, 1))));
	end

	local x = half + 16;
	if ( run.party and table.getn(run.party) > 1 ) then
		y = Header(v, L("Party"), x, 0, half);
		local party = {};
		for i = 1, table.getn(run.party) do
			local p = run.party[i];
			local cls = CLASSES[p.c or ""];
			table.insert(party, { n = p.n .. (p.top and ("  |cff9d9d9d" .. p.top .. "|r") or ""), d = p.d, s = p.s,
				i = cls and cls[1], color = cls and { cls[2], cls[3], cls[4] } });
		end
		y = Bars(v, x, y, half, party, nil, { 0.75, 0.75, 0.8 }, 5);
		y = Header(v, L("Damage taken"), x, y - 10, half);
		local taken = {};
		for i = 1, table.getn(run.takenBy or {}) do
			local t = run.takenBy[i];
			local info = TAKEN_LABEL[t.n];
			table.insert(taken, { n = info and info[1] or t.n, i = info and info[2], d = t.d });
		end
		Bars(v, x, y, half, taken, run.taken, { 0.85, 0.3, 0.25 }, 6);
		return;
	end
	y = Header(v, L("Healing done"), x, 0, half);
	local heal = run.healing or {};
	if ( table.getn(heal) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", x + half / 2, y);
		none:SetText(L("The addon did not record healing for this run."));
		y = y - 20;
	else
		y = Bars(v, x, y, half, heal, nil, { 0.35, 0.85, 0.45 }, 5);
	end
	y = Header(v, L("Damage taken"), x, y - 10, half);
	local taken = {};
	for i = 1, table.getn(run.takenBy or {}) do
		local t = run.takenBy[i];
		local info = TAKEN_LABEL[t.n];
		table.insert(taken, { n = info and info[1] or t.n, i = info and info[2], d = t.d });
	end
	if ( table.getn(taken) == 0 ) then
		local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		none:SetPoint("TOP", v, "TOPLEFT", x + half / 2, y);
		none:SetText(L("You did not take damage in this run."));
	else
		Bars(v, x, y, half, taken, run.taken, { 0.85, 0.3, 0.25 }, 6);
	end
end

do
	local function GearLine(s)
		local parts = {};
		local function Add(v, text) if ( v and v ~= 0 ) then table.insert(parts, text); end end
		Add(s.ghp, LF("+%.0f max health", s.ghp or 0));
		Add(s.gdmg, LF("+%.0f%% damage", (s.gdmg or 0) * 100));
		Add(s.gcd, LF("-%.0f%% cooldowns", (s.gcd or 0) * 100));
		Add(s.gcrit, LF("+%.0f%% critical strike", (s.gcrit or 0) * 100));
		Add(s.gcm, LF("+%.0f%% critical damage", (s.gcm or 0) * 100));
		Add(s.garm, LF("+%.0f%% damage reduction", (s.garm or 0) * 100));
		Add(s.greg, LF("+%.1f health per second", s.greg or 0));
		Add(s.garea, LF("+%.0f%% area of effect", (s.garea or 0) * 100));
		Add(s.gcnt, LF("+%d targets", s.gcnt or 0));
		Add(s.gecho, LF("+%.0f%% echo", (s.gecho or 0) * 100));
		Add(s.gspd, LF("+%.0f%% movement speed", (s.gspd or 0) * 100));
		Add(s.gpick, LF("+%.0f%% pickup range", (s.gpick or 0) * 100));
		Add(s.ggold, LF("+%.0f%% gold", (s.ggold or 0) * 100));
		local out = "";
		for i = 1, table.getn(parts) do out = out .. (i > 1 and " · " or "") .. parts[i]; end
		return out;
	end

	function DRAW.hero(v, run)
		local s = run.stats;
		if ( not s ) then
			local none = VText(v, BODY_FONT, 12, MUTED, "CENTER");
			none:SetPoint("TOP", v, "TOP", 0, -40);
			none:SetText(L("The addon did not record stats for this run."));
			return;
		end
		local y = Header(v, L("Stats at the end of the run"), 0, 0, VW);
		local function N(k, d) return tonumber(s[k]) or d or 0; end
		local entries = {
			{ L("Health"), string.format("%.0f", N("hp")) }, { L("Damage"), Pct(N("dmg", 1) - 1) },
			{ L("Haste"), Pct(1 - N("cd", 1)) }, { L("Crit"), string.format("%.1f%%", N("crit") * 100) },
			{ L("Crit Dmg"), string.format("%.0f%%", N("cm") * 100) }, { L("Armor"), string.format("%.0f%%", N("arm") * 100) },
			{ L("Area"), Pct(N("area", 1) - 1) }, { L("Targets"), string.format("+%d", N("cnt")) },
			{ L("Echo"), string.format("%.0f%%", N("echo") * 100) }, { L("Speed"), Pct(N("spd", 1) - 1) },
			{ L("Regen"), string.format("%.1f", N("reg")) }, { L("Pickup"), LF("%.0f yd", N("pick")) },
			{ L("Lifesteal"), string.format("%.1f%%", N("lch") * 100) }, { L("Kill Heal"), string.format("%.1f", N("heal")) },
			{ L("Thorns"), string.format("%.0f%%", N("thn") * 100) }, { L("Experience"), Pct(N("xp", 1) - 1) },
			{ L("Gold"), Pct(N("gold", 1) - 1) }, { L("Luck"), string.format("%.0f%%", N("luck") * 100) },
			{ L("Extra lives used"), tostring(run.livesUsed or 0) }, { L("Rerolls used"), tostring(run.rerollsUsed or 0) },
			{ L("Magnets taken"), Comma(run.magnets or 0) },
		};
		y = StatGrid(v, y, entries, { VW * 0.3, VW * 0.78 }) - 10;
		local gear = GearLine(s);
		if ( gear ~= "" ) then
			y = Caps(v, L("WORN GEAR"), 0, y, VW);
			local fs = VText(v, BODY_FONT, 12, GREEN, "CENTER");
			fs:SetPoint("TOP", v, "TOPLEFT", VW / 2, y);
			fs:SetWidth(VW - 20);
			fs:SetText(gear);
		end
	end
end

do
	local TIMELINE_ROWS = 19;

	local function Timeline(run)
		local out = {};
		for i = 1, table.getn(run.picks or {}) do
			local p = run.picks[i];
			local pn = Tr(p.n);
			local text, icon, c = pn, p.i, TEXT;
			if ( p.k == "spell" ) then
				text = Tr(L("New spell")) .. ": " .. pn;
			elseif ( p.k == "rank" ) then
				text = LF("%s · rank %s", pn, p.r or "?");
			elseif ( p.k == "jewel" ) then
				c = QUALITY[p.q or 1] or TEXT;
				text = pn .. (RARITY[p.q or 1] and (" · " .. Tr(RARITY[p.q or 1])) or "");
				if ( p.x ) then text = LF("%s, in place of %s", text, Tr(p.x)); end
			elseif ( p.k == "jewelup" ) then
				c = QUALITY[p.q or 1] or TEXT;
				text = LF("%s · higher rank", pn);
			end
			table.insert(out, { t = p.t, text = text, icon = icon or SpellIcon(p.n), c = c });
		end
		local EVENT = {
			boss = { "Spell_Shadow_RaiseDead", LABEL }, finalboss = { "Spell_Shadow_RaiseDead", LOSS },
			bossdown = { "INV_Misc_Head_Dragon_01", GOLD }, guardian = { "Ability_Warrior_Charge", GOLD },
			achievement = { "INV_Misc_Book_07", GOLD }, unlocked = { "INV_Misc_Map_01", GREEN },
			life = { "Spell_Holy_Resurrection", GOLD },
			rune = { "INV_Misc_Rune_01", BLUE }, endless = { "Spell_Shadow_RaiseDead", WIN },
		};
		for i = 1, table.getn(run.events or {}) do
			local e = run.events[i];
			local info = EVENT[e.k] or { QUESTION, TEXT };
			local text = Tr(e.x or e.n) or e.k;
			if ( e.k == "guardian" and e.n and e.n ~= "" ) then text = LF("Guardian killed: %s", Tr(e.n)); end
			if ( e.k == "bossdown" and e.n and e.n ~= "" ) then text = LF("Boss killed: %s", Tr(e.n)); end
			if ( e.k == "endless" ) then text = L("Endless mode started"); end
			if ( e.k == "life" ) then text = L("Extra life used"); end
			table.insert(out, { t = e.t, text = text, icon = info[1], c = info[2] });
		end
		for i = 1, table.getn(run.loot or {}) do
			local l = run.loot[i];
			table.insert(out, { t = l.t or run.t, text = LF("Loot: %s", Tr(l.n)) .. (l.new and ("  |cff40ff40" .. Tr(L("NEW")) .. "|r") or ""),
				icon = l.i, c = QUALITY[l.q or 1] or TEXT });
		end
		for lvl, t in pairs(run.levels or {}) do
			if ( math.mod(lvl, 5) == 0 ) then
				table.insert(out, { t = t, text = LF("Level %d", lvl), icon = "Spell_Holy_HolyBolt", c = LABEL });
			end
		end
		table.sort(out, function(a, b) return (a.t or 0) < (b.t or 0); end);
		local res = RESULT[run.result] or RESULT.quit;
		table.insert(out, { t = run.t, text = LF("%s · level %s", Tr(res[1]), tostring(run.lvl or "?")),
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

	ui.views.timeline:EnableMouseWheel(true);
	ui.views.timeline:SetScript("OnMouseWheel", function()
		this.offset = (this.offset or 0) - arg1 * 3;
		Refresh();
	end);
	ui.views.timeline.bar = Scrollbar(ui.views.timeline, TIMELINE_ROWS * 17, function(offset)
		ui.views.timeline.offset = offset;
		Refresh();
	end);
	ui.views.timeline.bar.wheelStep = 3;
	ui.views.timeline.bar:SetPoint("TOPRIGHT", ui.views.timeline, "TOPRIGHT", 0, 0);
end

ui.views.talents:EnableMouseWheel(true);
ui.views.talents:SetScript("OnMouseWheel", function()
	this.offset = (this.offset or 0) - arg1;
	Refresh();
end);
ui.views.talents.bar = Scrollbar(ui.views.talents, TALENT_ROWS * TALENT_H - 6, function(offset)
	ui.views.talents.offset = offset;
	Refresh();
end);
ui.views.talents.bar:SetPoint("TOPRIGHT", ui.views.talents, "TOPRIGHT", 0, -28);

ui.views.buffs:EnableMouseWheel(true);
ui.views.buffs:SetScript("OnMouseWheel", function()
	this.offset = (this.offset or 0) - arg1;
	Refresh();
end);
ui.views.buffs.bar = Scrollbar(ui.views.buffs, TALENT_ROWS * TALENT_H - 6, function(offset)
	ui.views.buffs.offset = offset;
	Refresh();
end);
ui.views.buffs.bar:SetPoint("TOPRIGHT", ui.views.buffs, "TOPRIGHT", 0, -28);


local Summary;

do
	local function RunsText(n)
		if ( n == 1 ) then return LF("%d run", n); end
		return LF("%d runs", n);
	end

	local function Dps(r)
		return (r.dmg or 0) / math.max(r.t or 1, 1);
	end

	local function Sorted(map)
		local list = {};
		for _, e in pairs(map) do table.insert(list, e); end
		table.sort(list, function(a, b)
			if ( a.d ~= b.d ) then return a.d > b.d; end
			return tostring(a.n) < tostring(b.n);
		end);
		return list;
	end

	local function DpsList(map, avg)
		local list, wide = {}, {};
		for _, e in pairs(map) do
			if ( e.runs > 0 ) then
				local d = e.sum / e.runs;
				local entry = { n = e.n, i = e.i, color = e.color, d = d };
				if ( avg and avg > 0 ) then
					entry.v = LF("%s/s · %+d%%", Short(d), math.floor((d / avg - 1) * 100 + 0.5));
				else
					entry.v = LF("%s/s", Short(d));
				end
				table.insert(wide, entry);
				if ( e.runs >= 2 ) then table.insert(list, entry); end
			end
		end
		if ( table.getn(list) == 0 ) then list = wide; end
		table.sort(list, function(a, b) return a.d > b.d; end);
		return list;
	end

	local function NeedClass(v, x, y, w)
		local fs = VText(v, BODY_FONT, 12, MUTED, "CENTER");
		fs:SetPoint("TOP", v, "TOPLEFT", x + w / 2, y - 4);
		fs:SetWidth(w - 20);
		fs:SetText(L("Choose a class with the class button to compare damage."));
	end

	local function ClassColor(class)
		local cls = CLASSES[class or ""] or { nil, 0.75, 0.75, 0.8 };
		return { cls[2], cls[3], cls[4] };
	end

	local TREND = {};

	function TREND.spells(v, runs, class)
		local half = (VW - 16) / 2;
		local picks, shares, metered = {}, {}, 0;
		for _, r in ipairs(runs) do
			for _, sp in ipairs(r.build or {}) do
				if ( not sp.racial ) then
					local e = picks[sp.key];
					if ( not e ) then
						e = { n = Tr(sp.n), i = sp.i or SpellIcon(sp.n), d = 0 };
						picks[sp.key] = e;
					end
					e.d = e.d + 1;
				end
			end
			if ( r.meter and table.getn(r.meter) > 0 ) then
				metered = metered + 1;
				for _, l in ipairs(r.meter) do
					local key = Native(l.n);
					local e = shares[key];
					if ( not e ) then
						e = { n = Tr(l.n), i = SpellIcon(l.n), p = l.p, d = 0 };
						shares[key] = e;
					end
					e.d = e.d + (l.s or 0) * 100;
				end
			end
		end
		local left = Sorted(picks);
		for _, e in ipairs(left) do e.v = RunsText(e.d); end
		local y = Header(v, L("Most picked spells"), 0, 0, half);
		Bars(v, 0, y, half, left, nil, ClassColor(class), 13);
		local x = half + 16;
		y = Header(v, L("Average share of damage"), x, 0, half);
		local right = Sorted(shares);
		for _, e in ipairs(right) do
			e.d = e.d / math.max(metered, 1);
			e.v = LF("%d%%", math.floor(e.d + 0.5));
		end
		table.sort(right, function(a, b) return a.d > b.d; end);
		Bars(v, x, y, half, right, nil, ClassColor(class), 13);
	end

	function TREND.jewels(v, runs, class)
		local half = (VW - 16) / 2;
		local worn, total, counted = {}, 0, 0;
		for _, r in ipairs(runs) do
			if ( (r.dmg or 0) > 0 ) then
				total = total + Dps(r);
				counted = counted + 1;
			end
			local seen = {};
			for _, j in ipairs(r.jewels or {}) do
				local base = BaseJewel(j.n) or j.n;
				if ( base and not seen[base] ) then
					seen[base] = true;
					local e = worn[base];
					if ( not e ) then
						e = { n = Tr(base), i = j.i, color = QUALITY[j.q or 1], d = 0, sum = 0, runs = 0 };
						worn[base] = e;
					end
					e.d = e.d + 1;
					if ( (r.dmg or 0) > 0 ) then
						e.sum = e.sum + Dps(r);
						e.runs = e.runs + 1;
					end
				end
			end
		end
		local left = Sorted(worn);
		for _, e in ipairs(left) do e.v = RunsText(e.d); end
		local y = Header(v, L("Most worn jewelry"), 0, 0, half);
		Bars(v, 0, y, half, left, nil, ClassColor(class), 13);
		local x = half + 16;
		y = Header(v, L("Damage per second with each item"), x, 0, half);
		if ( not class ) then
			NeedClass(v, x, y, half);
			return;
		end
		Bars(v, x, y, half, DpsList(worn, counted > 0 and total / counted or nil), nil, ClassColor(class), 13);
	end

	function TREND.zones(v, runs, class)
		local half = (VW - 16) / 2;
		local zones = {};
		for _, r in ipairs(runs) do
			local key = r.zone or r.zname or "?";
			local e = zones[key];
			if ( not e ) then
				e = { n = Tr(r.zname) or key, i = "INV_Misc_Map_01", d = 0, w = 0, sum = 0, runs = 0 };
				zones[key] = e;
			end
			e.d = e.d + 1;
			if ( r.won or r.result == "victory" ) then e.w = e.w + 1; end
			if ( (r.dmg or 0) > 0 ) then
				e.sum = e.sum + Dps(r);
				e.runs = e.runs + 1;
			end
		end
		local left = Sorted(zones);
		for _, e in ipairs(left) do e.v = LF("%s · %d won", RunsText(e.d), e.w); end
		local y = Header(v, L("Most played zones"), 0, 0, half);
		Bars(v, 0, y, half, left, nil, ClassColor(class), 13);
		local x = half + 16;
		y = Header(v, L("Damage per second by zone"), x, 0, half);
		if ( not class ) then
			NeedClass(v, x, y, half);
			return;
		end
		Bars(v, x, y, half, DpsList(zones), nil, ClassColor(class), 13);
	end

	function TREND.classes(v, runs, class)
		local half = (VW - 16) / 2;
		local classes = {};
		for _, r in ipairs(runs) do
			local key = r.class or "?";
			local e = classes[key];
			if ( not e ) then
				local cls = CLASSES[key];
				e = { n = LangKey("class." .. key .. ".name") or Tr(r.cname) or key, i = cls and cls[1], color = ClassColor(key),
					d = 0, sum = 0, runs = 0 };
				classes[key] = e;
			end
			e.d = e.d + 1;
			if ( (r.dmg or 0) > 0 ) then
				e.sum = e.sum + Dps(r);
				e.runs = e.runs + 1;
			end
		end
		local left = Sorted(classes);
		for _, e in ipairs(left) do e.v = RunsText(e.d); end
		local y = Header(v, L("Runs by class"), 0, 0, half);
		Bars(v, 0, y, half, left, nil, ClassColor(class), 9);
		local x = half + 16;
		y = Header(v, L("Damage per second by class"), x, 0, half);
		Bars(v, x, y, half, DpsList(classes), nil, ClassColor(class), 9);
	end

	local function DrawTrends(class)
		for i = 1, table.getn(TABS) do
			ui.views[TABS[i]]:Hide();
			ui.tabButtons[TABS[i]]:Hide();
		end
		for _, v in pairs(ui.trendViews) do v:Hide(); end
		ui.delete:Hide();
		ui.starButton:Hide();
		ui.position:SetText("");
		local runs = {};
		for i = 1, table.getn(ui.shown) do table.insert(runs, db.runs[ui.shown[i]]); end
		local n = table.getn(runs);
		ui.dTitle:SetText(L("Trends"));
		Color(ui.dTitle, GOLD);
		local who = class and (LangKey("class." .. class .. ".name") or class) or L("All classes");
		ui.dSub:SetText(who .. " · " .. RunsText(n));
		ui.dMeta:SetText(L("The charts use the runs that match the filters on the left."));
		if ( n == 0 ) then
			for _, b in pairs(ui.trendButtons) do b:Hide(); end
			ui.dEmpty:SetText(L("No runs show with this filter."));
			return;
		end
		ui.dEmpty:SetText("");
		local tab = db.settings.trendTab or "spells";
		if ( not ui.trendViews[tab] ) then tab = "spells"; end
		for key, b in pairs(ui.trendButtons) do
			b:Show();
			b.selected = (key == tab);
			b:Paint();
		end
		local v = ui.trendViews[tab];
		Reset(v);
		TREND[tab](v, runs, class);
		v:Show();
	end

	local function DrawDetail(run)
		for _, v in pairs(ui.trendViews) do v:Hide(); end
		for _, b in pairs(ui.trendButtons) do b:Hide(); end
		for i = 1, table.getn(TABS) do ui.views[TABS[i]]:Hide(); end
		if ( not run ) then
			ui.dTitle:SetText("");
			ui.dSub:SetText("");
			ui.dMeta:SetText("");
			for i = 1, table.getn(TABS) do ui.tabButtons[TABS[i]]:Hide(); end
			ui.delete:Hide();
			ui.starButton:Hide();
			ui.position:SetText("");
			ui.dEmpty:SetText(L("This window shows each run after it ends. It shows your spells, your items, your loot, your stats and more."));
			return;
		end
		ui.dEmpty:SetText("");
		ui.delete:Show();
		ui.starButton:Show();
		ui.starButton.text:SetText(run.star and L("Unstar run") or L("Star run"));
		ui.starButton.selected = run.star and true or nil;
		ui.starButton:Paint();
		local res = RESULT[run.result] or RESULT.quit;
		if ( run.won ) then res = RESULT.victory; end
		ui.dTitle:SetText(Tr(res[1]));
		Color(ui.dTitle, res[2]);
		local g = tonumber(run.gender);
		local gender = (g == 1 and LangKey("common.female")) or (g == 0 and LangKey("common.male")) or nil;
		ui.dSub:SetText(string.format("%s%s, %s %s · %s", run.hero or "?", gender and (" (" .. gender .. ")") or "",
			Tr(run.rname or run.race) or "", Tr(run.cname) or "", Tr(run.zname) or "?"));
		local meta = DateText(run.ended or run.started);
		if ( run.zsub and run.zsub ~= "" ) then meta = meta .. " · " .. Tr(run.zsub); end
		if ( run.mods and run.mods ~= "" and run.mods ~= "100 100 100 100" ) then
			local _, _, a, b, c, d = string.find(run.mods, "(%d+) (%d+) (%d+) (%d+)");
			meta = meta .. " · " .. LF("density %s%% health %s%% damage %s%% speed %s%%", a or "?", b or "?", c or "?", d or "?");
		else
			meta = meta .. " · " .. L("Normal difficulty");
		end
		if ( run.official ) then
			meta = meta .. " · " .. LF("zone complete at %s, endless mode until %s", Clock(run.official.t), Clock(run.t));
		elseif ( run.won and run.result ~= "victory" ) then
			meta = meta .. " · " .. L("zone complete, then endless mode");
		end
		ui.dMeta:SetText(meta);
		local tab = db.settings.tab or "summary";
		if ( not ui.views[tab] ) then tab = "summary"; end
		for i = 1, table.getn(TABS) do
			local b = ui.tabButtons[TABS[i]];
			b:Show();
			b.selected = (TABS[i] == tab);
			b:Paint();
		end
		if ( run.id ~= ui.detail.runId ) then
			ui.detail.runId = run.id;
			for i = 1, table.getn(TABS) do ui.views[TABS[i]].offset = 0; end
		end
		local v = ui.views[tab];
		Reset(v);
		DRAW[tab](v, run);
		v:Show();
	end

	function Summary()
		local n, wins, longest, kills = table.getn(db.runs), 0, 0, 0;
		for i = 1, n do
			local r = db.runs[i];
			if ( r.won or r.result == "victory" ) then wins = wins + 1; end
			if ( (r.t or 0) > longest ) then longest = r.t; end
			if ( (r.kills or 0) > kills ) then kills = r.kills; end
		end
		if ( n == 0 ) then return L("No runs"); end
		local runsText, winsText;
		if ( n == 1 ) then runsText = LF("%d run", n); else runsText = LF("%d runs", n); end
		if ( wins == 1 ) then winsText = LF("%d victory", wins); else winsText = LF("%d victories", wins); end
		return LF("%s  ·  %s  ·  longest %s  ·  most kills %s", runsText, winsText, Clock(longest), Comma(kills));
	end

	Refresh = function()
		if ( not db or not ui.frame:IsShown() ) then return; end
		ui.summary:SetText(Summary());
		local filter = db.settings.filter or "all";
		for key, b in pairs(ui.filterButtons) do
			b.selected = (key == filter);
			b:Paint();
		end
		local class = db.settings.class;
		local classText = L("All classes");
		if ( class ) then
			classText = class;
			if ( CLASSES[class] ) then
				classText = LF("Only %s", LangKey("class." .. class .. ".name") or (string.upper(string.sub(class, 1, 1)) .. string.sub(class, 2)));
			end
		end
		ui.classButton.text:SetText(classText);
		ui.shown = {};
		for i = 1, table.getn(db.runs) do
			if ( RunMatches(db.runs[i], filter, class) ) then table.insert(ui.shown, i); end
		end
		local offset = math.max(0, math.min(db.settings.offset or 0, math.max(0, table.getn(ui.shown) - ROWS)));
		db.settings.offset = offset;
		local found;
		for i = 1, table.getn(ui.shown) do
			if ( db.runs[ui.shown[i]].id == ui.selectedId ) then found = 1; end
		end
		if ( not found ) then ui.selectedId = ui.shown[1] and db.runs[ui.shown[1]].id; end

		for i = 1, ROWS do
			local row = ui.rows[i];
			local index = ui.shown[i + offset];
			local r = index and db.runs[index];
			if ( r ) then
				row.runId = r.id;
				if ( r.star ) then row.star:Show(); else row.star:Hide(); end
				local cls = CLASSES[r.class or ""] or { QUESTION, 0.75, 0.75, 0.8 };
				row.icon:Set(cls[1], { cls[2], cls[3], cls[4] });
				row.name:SetText(string.format("%s |cff9d9d9d%s|r", r.hero or "?", tostring(r.lvl or "?")));
				row.name:SetTextColor(cls[2], cls[3], cls[4]);
				row.zone:SetText(Tr(r.zname) or "?");
				local res = RESULT[r.result] or RESULT.quit;
				local label = res[3];
				if ( r.won and r.result ~= "victory" ) then label = L("Victory+"); end
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
		if ( table.getn(ui.shown) == 0 ) then
			ui.listEmpty:SetText(table.getn(db.runs) == 0 and L("No runs.\n\nWhen a run ends, the addon records it here.") or L("No runs show with this filter."));
		else
			ui.listEmpty:SetText("");
		end
		ui.listBar:Sync(offset, table.getn(ui.shown) - ROWS, ROWS, table.getn(ui.shown));
		ui.trendButton.selected = db.settings.trends and true or nil;
		ui.trendButton:Paint();
		local run, index = Selected();
		if ( db.settings.trends ) then
			DrawTrends(class);
			return;
		end
		DrawDetail(run);
		if ( run ) then
			local at = 0;
			for i = 1, table.getn(ui.shown) do if ( ui.shown[i] == index ) then at = i; end end
			ui.position:SetText(LF("Run %d of %d", at, table.getn(ui.shown)));
		end
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

do
	local hudWait = 0;
	ui.frame:SetScript("OnUpdate", function()
		hudWait = hudWait + arg1;
		if ( hudWait < 0.2 ) then return; end
		hudWait = 0;
		if ( AZS_GetPhase and AZS_GetPhase() == "ready" ) then HideHud(); else RestoreHud(); end
	end);
end

ui.frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	DetectLang();
	if ( AZS_GetPhase and AZS_GetPhase() == "ready" ) then HideHud(); end
	Refresh();
end);
ui.frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	RestoreHud();
end);

function AZSHistory_Toggle()
	if ( ui.frame:IsShown() ) then ui.frame:Hide(); else ui.frame:Show(); end
end

BINDING_HEADER_AZSHISTORY = L("Run History");
BINDING_NAME_AZSHISTORY_TOGGLE = L("Open Run History");

ui.mm = CreateFrame("Button", "AZSHistoryMinimapButton", Minimap);
ui.mm:SetWidth(31);
ui.mm:SetHeight(31);
ui.mm:SetFrameStrata("MEDIUM");
ui.mm:SetFrameLevel(8);
if ( ui.mm.SetHighlightTexture ) then ui.mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); end
ui.mmIcon = ui.mm:CreateTexture(nil, "BACKGROUND");
ui.mmIcon:SetTexture(ICONS .. "INV_Misc_Book_09");
ui.mmIcon:SetWidth(20);
ui.mmIcon:SetHeight(20);
ui.mmIcon:SetPoint("TOPLEFT", ui.mm, "TOPLEFT", 7, -5);
ui.mmBorder = ui.mm:CreateTexture(nil, "OVERLAY");
ui.mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
ui.mmBorder:SetWidth(53);
ui.mmBorder:SetHeight(53);
ui.mmBorder:SetPoint("TOPLEFT", ui.mm, "TOPLEFT", 0, 0);
ui.mm:RegisterForClicks("LeftButtonUp");
ui.mm:RegisterForDrag("LeftButton");

local function PlaceMinimapButton()
	local a = math.rad(db.settings.mm or 205);
	ui.mm:ClearAllPoints();
	ui.mm:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - 80 * math.cos(a), 80 * math.sin(a) - 52);
end

ui.mm:SetScript("OnClick", function() AZSHistory_Toggle(); end);
local function DragMinimapButton()
	local mx, my = Minimap:GetCenter();
	local px, py = GetCursorPosition();
	local s = Minimap:GetEffectiveScale();
	db.settings.mm = math.deg(math.atan2(py / s - my, mx - px / s));
	PlaceMinimapButton();
end

ui.mm:SetScript("OnDragStart", function() this:SetScript("OnUpdate", DragMinimapButton); end);
ui.mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil); end);
ui.mm:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT");
	GameTooltip:SetText(L("Run History"), 1, 1, 1);
	GameTooltip:AddLine(Summary(), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	GameTooltip:AddLine(L("Click to open. Drag to move."), MUTED[1], MUTED[2], MUTED[3]);
	GameTooltip:Show();
end);
ui.mm:SetScript("OnLeave", function() GameTooltip:Hide(); end);

SLASH_AZSHISTORY1 = "/runs";
SLASH_AZSHISTORY2 = "/runhistory";
SLASH_AZSHISTORY3 = "/azh";
local ApplyKey;

do
	function ApplyKey()
		local key = db and db.settings.key;
		if ( key and SetBinding ) then SetBinding(key, "AZSHISTORY_TOGGLE"); end
	end

	local function SetKey(key)
		if ( key == "" ) then
			if ( db.settings.key ) then
				Print(LF("The key for the history is %s.", db.settings.key));
			else
				Print(L("The history has no key. Type /runs key <key> to set one. Example: /runs key F8."));
			end
			return;
		end
		if ( db.settings.key and SetBinding ) then SetBinding(db.settings.key); end
		if ( key == "NONE" ) then
			db.settings.key = nil;
			Print(L("The history has no key now."));
			return;
		end
		local old = GetBindingAction and GetBindingAction(key);
		db.settings.key = key;
		ApplyKey();
		if ( old and old ~= "" and old ~= "AZSHISTORY_TOGGLE" ) then
			Print(LF("The key %s opens the history now. It no longer does %s.", key, getglobal("BINDING_NAME_" .. old) or old));
		else
			Print(LF("The key %s opens the history now.", key));
		end
	end

	SlashCmdList["AZSHISTORY"] = function(msg)
		msg = string.lower(msg or "");
		local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$");
		if ( cmd == "key" ) then
			SetKey(string.upper(rest));
		elseif ( cmd == "minimap" ) then
			db.settings.hideMinimap = not db.settings.hideMinimap;
			if ( db.settings.hideMinimap ) then ui.mm:Hide(); else ui.mm:Show(); end
			if ( db.settings.hideMinimap ) then
				Print(L("The minimap button is hidden. Type /runs minimap to show it."));
			else
				Print(L("The minimap button is shown."));
			end
		elseif ( cmd == "tz" ) then
			local h = tonumber(rest);
			db.settings.tz = h;
			if ( h ) then
				Print(LF("Times show in UTC%+g.", h));
			else
				Print(L("Times show in UTC."));
			end
			Refresh();
		elseif ( cmd == "help" ) then
			Print(L("Type /runs to open or close the history. Type /runs minimap to show or hide the minimap button. Type /runs key <key> to set a key for the history. Type /runs key none to remove it. Star a run in the window to keep it: the history keeps your last 50 runs that are not starred. Type /runs tz <hours> to set your time zone in hours from UTC. Example: /runs tz -5."));
		else
			AZSHistory_Toggle();
		end
	end;
end

ui.events = CreateFrame("Frame");
ui.events:RegisterEvent("ADDON_LOADED");
ui.events:RegisterEvent("PLAYER_ENTERING_WORLD");
ui.events:RegisterEvent("PLAYER_LOGOUT");
ui.events:RegisterEvent("CHAT_MSG_ADDON");
ui.events:RegisterEvent("CHAT_MSG_SYSTEM");
ui.events:RegisterEvent("CHAT_MSG_LOOT");
local CHAT_EVENTS;

do
	CHAT_EVENTS = { CHAT_MSG_SYSTEM = 1, CHAT_MSG_LOOT = 1 };
	local EXTRA_CHAT = { "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_RAID_BOSS_EMOTE", "UI_INFO_MESSAGE" };
	for i = 1, table.getn(EXTRA_CHAT) do
		if ( pcall(ui.events.RegisterEvent, ui.events, EXTRA_CHAT[i]) ) then CHAT_EVENTS[EXTRA_CHAT[i]] = 1; end
	end
end
ui.events:RegisterEvent("UNIT_INVENTORY_CHANGED");
ui.events:RegisterEvent("UPDATE_INVENTORY_ALERTS");
ui.events:RegisterEvent("SPELLS_CHANGED");

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
		ui.frame:ClearAllPoints();
		ui.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]);
	end
	PlaceMinimapButton();
	if ( db.settings.hideMinimap ) then ui.mm:Hide(); end
	if ( AZS_RegisterBannerHandler ) then AZS_RegisterBannerHandler(OnBanner); end
end

do
	local scanWait = 0;
	ui.events:SetScript("OnUpdate", function()
		if ( not cur ) then return; end
		scanWait = scanWait + arg1;
		if ( scanWait < 0.5 ) then return; end
		scanWait = 0;
		ScanJewels();
		local ph = AZS_GetPhase and AZS_GetPhase();
		if ( ph ~= "victory" and ph ~= "dead" ) then KeepJewelLines(); KeepSpellLines(); end
	end);
end

ui.events:SetScript("OnEvent", function()
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
		elseif ( arg1 == "AZSPETS" ) then
			ScanPets();
		elseif ( arg1 == "AZSBUFFS" ) then
			NoteBuffs();
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
