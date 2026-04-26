local _gg_choice = gg.choice
gg.choice = function(menu, selected, message)
    while true do
        local res = _gg_choice(menu, selected, message)
        if res == nil then
            gg.setVisible(false)
            while not gg.isVisible() do gg.sleep(10) end
            gg.setVisible(false)
        else
            return res
        end
    end
end

local _gg_multiChoice = gg.multiChoice
gg.multiChoice = function(items, selected, message)
    while true do
        local res = _gg_multiChoice(items, selected, message)
        if res == nil then
            gg.toast("👁️‍🗨️ تم الإخفاء.\n💡للرجوع أو الإلغاء تماماً: اضغط 'موافق' بدون اختيار شيء.")
            gg.setVisible(false)
            while not gg.isVisible() do gg.sleep(100) end
            gg.setVisible(false)
        else
            return res
        end
    end
end

local REVERT_HISTORY = {}
local FAVORITES = {}
local LAST_MANUAL_CODES = {}
local SETTINGS = {
    skip_alerts = false,
    show_countdown = true
}
local RF_RUNNING = true

local function safe_number(value, fallback)
    local n = tonumber(value)
    if n == nil then return fallback end
    return n
end

local function prompt_delay_ms(default_seconds)
    local p = gg.prompt({"⏱️ وقت الانتظار بين كل محاولة (بالثواني)"}, {tostring(default_seconds or 15)}, {"number"})
    if not p then return nil end
    local sec = safe_number(p[1], default_seconds or 15)
    if sec < 0 then sec = default_seconds or 15 end
    return math.floor(sec * 1000)
end

local function wait_with_countdown(total_ms, label)
    local remaining = safe_number(total_ms, 0)
    if remaining <= 0 then return end
    if not SETTINGS.show_countdown then
        gg.sleep(remaining)
        return
    end
    local title = label or "المحاولة التالية"
    while remaining > 0 do
        local seconds_left = math.ceil(remaining / 1000)
        gg.toast("⏳ " .. title .. ": " .. seconds_left .. " ثانية", true)
        local step = math.min(1000, remaining)
        gg.sleep(step)
        remaining = remaining - step
    end
end

function add_to_favorites(codes, mode, mins)
    local name_prompt = gg.prompt({"أدخل اسم للمجموعة:"}, {[1]=""}, {"text"})
    if name_prompt and name_prompt[1] then
        FAVORITES[name_prompt[1]] = {
            codes = codes,
            type = mode or "normal",
            mins = mins or 0
        }
        save_favorites()
        gg.toast("تم الحفظ بنجاح")
    end
end

function delete_favorite_menu()
    local names = {}
    for name, _ in pairs(FAVORITES) do table.insert(names, name) end
    if #names == 0 then gg.alert("لا توجد مجموعات لحذفها") return end
    local choice = gg.multiChoice(names, nil, "اختر المجموعات لحذفها")
    if choice == nil then return end
    for i, _ in pairs(choice) do FAVORITES[names[i]] = nil end
    save_favorites()
    gg.toast("تم الحذف")
end

function favorites_menu()
    local names = {}
    local key_map = {}
    for name, entry in pairs(FAVORITES) do
        local label = name
        if entry.type == "autobuy" then label = "🛍️ " .. name .. " (" .. entry.mins .. "د)" end
        table.insert(names, label)
        table.insert(key_map, name)
    end
    if #names == 0 then gg.alert("لا توجد مجموعات محفوظة.") return end
    table.insert(names, "❌ حذف مجموعة")
    table.insert(names, "↩️ رجوع")
    local choice = gg.choice(names, nil, "المفضلة")
    if choice == nil then return end
    if choice == #names then return end
    if choice == #names - 1 then delete_favorite_menu() else
        local selected_key = key_map[choice]
        local entry = FAVORITES[selected_key]
        if entry.type == "autobuy" then run_autobuy_logic(entry.codes, entry.mins) else apply_codes(entry.codes) end
    end
end

function apply_codes(selected_codes, silent_mode)
    if #selected_codes == 0 then return false end
    -- Group Search String: Salad Cup Recipe
    local g = "21;5;500661;3;150;12;14;9;20145;2"

    if not silent_mode and not SETTINGS.skip_alerts then
        gg.alert("👈يرجى فتح موقد الطهي👉\n🔥وصفة كوب سلطة🔥\n💸ثم الشراء💸")
    end
    gg.setVisible(false)
    gg.clearResults()
    gg.sleep(100)

    gg.searchNumber(g, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
    local results = gg.getResults(200)
    
    if #results < 10 then 
        if not silent_mode then gg.alert("⚠️ لم يتم العثور على النتائج!\nتأكد من فتح وصفة 'كوب سلطة'.") end
        gg.clearResults()
        return false
    end

    local d_list = {} -- Counts (Target 1M)
    local s_list = {} -- IDs (Target Code)
    local d_values = {[5]=true, [3]=true, [12]=true, [9]=true, [2]=true} 

    for _, v in ipairs(results) do
        local val = math.floor(v.value)
        if d_values[val] then table.insert(d_list, v) else table.insert(s_list, v) end
    end

    table.sort(d_list, function(a,b) return a.address < b.address end)
    table.sort(s_list, function(a,b) return a.address < b.address end)

    if #d_list < #selected_codes or #s_list < #selected_codes then
        if not silent_mode then gg.alert("⚠️ خطأ: عدد النتائج غير كافٍ ("..#s_list.." عناصر).") end
        gg.clearResults()
        return false
    end
 -- Save Revert Snapshot (Simplified)
    -- Execute
    local t_edits = {}
    for i = 1, #selected_codes do
        local item = d_list[i]
        item.value = 1000000
        item.freeze = false
        table.insert(t_edits, item)
    end
    for i = 1, #selected_codes do
        local item = s_list[i]
        item.value = selected_codes[i]
        item.freeze = false
        table.insert(t_edits, item)
    end
    gg.setValues(t_edits)
    gg.toast("تم تفعيل " .. #selected_codes .. " كود بنجاح")
    return true
end

function run_autobuy_logic(codes, mins)
    if #codes == 0 then return end
    local batch_size = 5
    local num_batches = math.ceil(#codes / batch_size)
    gg.toast("جار التنفيذ على " .. #codes .. " كود.\n" .. num_batches .. " مجموعة.")
    gg.sleep(1000)

    for i = 1, num_batches do
        local batch = {}
        local start_idx = (i - 1) * batch_size + 1
        local end_idx = math.min(i * batch_size, #codes)
        for j = start_idx, end_idx do table.insert(batch, codes[j]) end

        gg.toast("🔸 جاري تنفيذ المجموعة " .. i .. "/" .. num_batches)
        if not apply_codes(batch, true) then
            gg.alert("خطأ في المجموعة " .. i)
            return
        else
            local wait_seconds = mins * 60
            local start_time = os.time()
            while os.time() - start_time < wait_seconds do
                local rem = wait_seconds - (os.time() - start_time)
                gg.toast("⏳ المجموعة " .. i .. "\nالمتبقي: " .. rem .. " ثانية", true)
                gg.sleep(1000)
                if gg.isVisible() then
                    gg.setVisible(false)
                    if gg.alert("خيارات الشراء المستمر", "إيقاف", "استمرار") == 1 then return end
                end
            end
            -- Revert logic here if needed (omitted for brevity)
        end
    end
    gg.alert("🎉 تم الانتهاء!")
end

function continuous_buying_action()
    local input = gg.prompt({"📝 أدخل الأكواد (الصق القائمة)", "⏱️ وقت كل مجموعة (دقيقة)"}, {"", "10"}, {"text", "number"})
    if not input then return end
    local codes = {}
    for c in input[1]:gmatch("%d+") do table.insert(codes, c) end
    if #codes == 0 then gg.alert("لم يتم العثور على أرقام") return end
    
    if gg.alert("حفظ في المفضلة؟", "نعم", "لا") == 1 then
        add_to_favorites(codes, "autobuy", tonumber(input[2]))
    end
    run_autobuy_logic(codes, tonumber(input[2]))
end

function manual_entry_action()
    local input = gg.prompt({"أدخل ما يصل إلى 5 أكواد (مفصولة بفاصلة أو مسافة):"}, {""}, {"text"})
    if not input then return end
    local codes = {}
    for c in input[1]:gmatch("%d+") do table.insert(codes, c) end
    if #codes > 5 then gg.alert("الحد الأقصى 5 أكواد") return end
    if #codes == 0 then return end
    
    LAST_MANUAL_CODES = codes
    save_favorites()
    apply_codes(codes)
end

function action(arr, options)
    options = options or {}
    local allow_back_to_search = options.allow_back_to_search == true

    local names = {}
    local codes = {}
    
    table.insert(names, "✅ اختيار الكل (Select All)")

    for k, v in pairs(arr) do
        table.insert(names, k)
        codes[k] = v
    end
    
    local choices = gg.multiChoice(names, nil, "اختر العناصر (يمكنك اختيار حتى 5)")
    if choices == nil then return end

    local selected_codes = {}
    local selected_names = {}
    local special_action = nil
    local select_all = false
    local back_to_search = false

    -- Check for Special Actions & Select All
    for i, _ in pairs(choices) do
        local name = names[i]
        if i == 1 then select_all = true 
      
        elseif name == "🔙 رجوع للبحث" then back_to_search = true
        end
    end

    if back_to_search then
        return yellow_repository_search()
    end

    if special_action == "manual" then manual_entry_action() return end
    if special_action == "fav" then favorites_menu() return end

    -- Populate selected_codes
    if select_all then
        for k, v in pairs(arr) do
            table.insert(selected_codes, v)
            table.insert(selected_names, k)
        end
    else
        for i, _ in pairs(choices) do
            local name = names[i]
            if name ~= "✅ اختيار الكل (Select All)" and 
               name ~= "⭐ المفضلة" and name ~= "🔙 رجوع للبحث" then
                table.insert(selected_codes, codes[name])
                table.insert(selected_names, name)
            end
        end
    end
    
    if #selected_codes == 0 and special_action == "auto" then
        continuous_buying_action()
        return
    end
    if #selected_codes == 0 then return end
    if special_action == "auto" then
        local time_prompt = gg.prompt({"⏱️ أدخل الوقت الفاصل بين كل مجموعة (بالدقيقة):"}, {"10"}, {"number"})
        if time_prompt and time_prompt[1] then
            run_autobuy_logic(selected_codes, tonumber(time_prompt[1]))
        end
        return
    end
    
    if #selected_codes == 1 then
        local code = selected_codes[1]
        local name = selected_names[1]
        
        -- Ask User: Search & Replace OR Salad Cup?
        local method = gg.alert("اختر طريقة التنفيذ للعنصر:\n" .. name, "🔍 بحث وتعديل (القديم)", "🥗 طريقة كوب السلطة", "إلغاء")
        if method == 3 then return end
        
        if method == 2 then
            -- Use Salad Cup
            apply_codes({code})
            return
        end
        
        -- Standard Search & Replace
        local search_type = gg.alert("نوع البحث:", "DWORD", "DOUBLE", "إلغاء")
        if search_type == 3 then return end
        local type_enum = (search_type == 2) and gg.TYPE_DOUBLE or gg.TYPE_DWORD

        gg.setVisible(false)
        gg.searchNumber(code, type_enum, false, gg.SIGN_EQUAL, 0, -1, 0)
        local count = gg.getResultsCount()
        if count == 0 then gg.alert("لم يتم العثور على نتائج") return end
        
        local p = gg.prompt({"ادخل القيمة الجديدة"}, {code}, {"number"})
        if p then
            gg.getResults(100000)
            gg.editAll(p[1], type_enum)
            gg.alert("تم التعديل بنجاح")
        end
        gg.clearResults()
        return
    end

    if #selected_codes > 0 then
        -- If > 5, enforce Auto Buy logic (batching) even if tool wasn't selected
        if #selected_codes > 5 then
            local confirm = gg.alert("⚠️ لقد اخترت " .. #selected_codes .. " عنصراً.\nلا يمكن تنفيذ أكثر من 5 في وقت واحد.\nهل تريد تشغيل نظام الشراء التلقائي (مجموعات)؟", "نعم (تشغيل تلقائي)", "إلغاء")
            if confirm == 2 then return end
            -- Fallthrough to run_autobuy_logic below
            local time_prompt = gg.prompt({"⏱️ أدخل الوقت الفاصل بين كل مجموعة (بالدقيقة):"}, {"10"}, {"number"})
            if time_prompt and time_prompt[1] then
                run_autobuy_logic(selected_codes, tonumber(time_prompt[1]))
            end
            return
        end
        
        local confirm = gg.alert("تم اختيار " .. #selected_codes .. " عناصر.\nسيتم استخدام طريقة 'كوب السلطة'.\nهل تريد المتابعة؟", "نعم", "حفظ كمجموعة", "إلغاء")
        if confirm == 3 then return end
        if confirm == 2 then
            add_to_favorites(selected_codes)
            return
        end

        apply_codes(selected_codes)
    end
end


local th = {
    ["الكمأة بيضاء"] = "501152", ["جرجير"] = "500655", ["حنطة سوداء"] = "500836", ["عدس"] = "500765",
    ["كافيار اسود"] = "500776", ["اوراق الخيزران"] = "501166", ["كزبرة"] = "500714", ["السمسم"] = "501397",
    ["بصل اخضر"] = "500989", ["قبار "] = "500631", ["خميرة"] = "500139", ["شمندر احمر "] = "501286",
    ["رواند"] = "500564", ["فلفل الحار"] = "501066", ["بط مشوي"] = "501246", ["فانيلا"] = "500466",
    ["خل ابيض"] = "30221", ["بقدونس"] = "501082", ["الهيل"] = "501609", ["طحين صودا"] = "500623",
    ["ريحان"] = "500826", ["براعم البقوليات"] = "500846", ["ثوم معمر"] = "501587", ["قطرم"] = "500816"
}

local fishes = {
    ["حلزون البحر البزاق"] = "700026", ["سمك صدفي"] = "700074", ["السلطعون"] = "700028", ["اذان البحر "] = "700075",
    ["ماكريل"] = "700021", ["جمبري السرعوف"] = "700029", ["اعشاب البحر "] = "700042", ["سلطعون الضفدع الاحمر "] = "700034",
    ["الكابوريا"] = "700033", ["صدفة"] = "700024", ["اخطبوط"] = "700039", ["مرجان"] = "700036",
    ["اعشاب الخليج"] = "700041", ["جمبري عملاق"] = "700077", ["سلطعون مثلج"] = "700076"
}

local khshb = {
    ["خشب البلوط"] = "8013", ["خشبة"] = "630002", ["قنبلة"] = "619003", ["اسطوانة خشبية"] = "630001",
    ["خشب الارز"] = "8017", ["خشب ساندرز"] = "8021", ["برميل بارود"] = "619004", ["لوح خشبي"] = "630003",
    ["ديناميت"] = "619002"
}

local shhn = {
    ["كعكه فطائر منفوخه الزهره الزرقاء"]= "207801", ["كعكه الفطائر المنفوخه الزهره الحمراء "] = "207802",
    ["كعكه الفطائر المنفوخه بالصباره"] = "207803", ["كعكه الفطائر المنفوخه بالزنبق"] = "207804",
    ["كعكه الفطائر المنفوخه بزهره السوسن"] = "207805", ["كعكه الفطائر المنفوخه بلوميريا"] = "207806",
    [" بيضة القرن"] = "8013", ["بتلة خيزران"] = "41061", ["ريشة يونيكورن"] = "41081", ["ريش النحام الوردي"] = "41057",
    ["مخمل رنة الاحتفال"] = "41085", ["ريش فينكس"] = "41083", ["ريش اوز اسود العنق"] = "41077"
}

local mtwer = {
    ["فوشار بزبدة الفستق"] = "200531", ["بسطرمة لحم"] = "22101", ["دمية خالد "] = "22097",
    ["حليب بودرة"] = "22001", ["ريشة طاووس اسود"] = "22082", ["لحم نعامة سوداء"] = "22085", ["جلد نعامة سوداء"] = "22088",
    ["برغر صغير"] = "22042", ["جلد رقيق"] = "22078", ["خبز فرنسي"] = "22066", ["ريش دجاج"] = "22025",
    ["مهلبية شامية"] = "22029", ["علف"] = "22024", ["دبس سكر"] = "22054", ["فرو مخمل "] = "22037",
    ["بيض احمر"] = "22023", ["جلد ثور فرنسي"] = "22070", ["جزر بلاستيك"] = "22038", ["باقة زهور مجففة"] = "22074",
    ["عصير فرنسي"] = "22046", ["طبق فواكة"] = "22034", ["صلصة ميكس"] = "22050", ["جبن زرقاء"] = "22002",
    ["دمية الغزال"] = "22058", ["مصاصة"] = "22062"
}

local gthera = {
    ["صابون غار"] = "203101", ["صابون بابونج"] = "203102", ["صابون ورد احمر"] = "203104", ["صابون بالعسل"] = "203105",
    ["صابون توليب"] = "203106", ["صابون عباد الشمس "] = "203107", ["صابون بنفسج"] = "203108",
    ["ساشيمي  سكلوب"] = "203502", ["ساشيمي اخطبوط "] = "203503", ["ساشيمي حبار"] = "203504", ["ساشيمي ماكريل"] = "203506",
    ["سله بابونج "] = "11801", ["سله زنبق"] = "11802", ["سله ورد ابيض"] = "11803", ["سله زهره العسل"] = "11804",
    ["سله الياسمين"] = "11805", ["سله زهره البنفسج "] = "11806", ["سله زهره ورديه"] = "11807",
    ["خبز الزبيب"] = "11101", [" خبز الثوم"] = "11103", ["خبز كوسا"] = "11104", ["خبز عنيبه حاده"] = "11105",
    ["خبز بالقرفه"] = "11106", ["خبز الفراولة "] = "11107", ["خبز كيوي"] = "11108", ["خبز انانوله"] = "11109", ["خبز بالكاكايا"] = "11110",
    ["انبوب ماء"] = "610009", ["مطاط"] = "8023", ["خيزران"] = "8005", ["كستناء"] = "8003", ["قرون"] = "610015",
    ["بارود"] = "619001", ["مراه تجميل"] = "610006", ["نشارة خشب "] = "630005", ["دمية مخفية"] = "610002",
    ["لوحة رسم زيتية"] = "610003", ["علبة تجميل"] = "610005", ["زجاجة اريج خشبي"] = "610004", ["حجر قرميد"] = "610008",
    ["صندوق انقاذ حيوان"] = "611002", ["أوراق التوت"] = "8009"
}

local tgmil = {
    ["الاسكالوب المجفف"] = "31005", ["محاره"] = "31006", ["حلزون البحر "] = "31007", ["لحم جمبري"] = "31008",
    ["جمبري السرعوف علي البخار "] = "31009", ["جمبري ابو سوم علي البخار"] = "31010", ["سلطعون الطين علي البخار"] = "31011",
    ["سلطعون علي البخار"] = "31012", ["سلطعون الضفدع الأحمر المطبوخ"] = "31013", ["بودر المرجان"] = "31014",
    ["نجم البحر المجفف "] = "31015", ["قنديل البحر المملح"] = "31016", ["لحم الاخطبوط"] = "31017", ["مسحوق الطحالب"] = "31018",
    ["أعشاب بحريه مطبوخه "] = "31019", ["طحالب بحريه جافه"] = "31020", ["خس البحر المطبوخ"] = "31021", ["لؤلؤ"] = "31022",
    ["قوقعه حلزون البحر "] = "31023", ["كرات الجمبري"] = "31024", ["ستيك سلطعون "] = "31025", ["بطارخ سلطعون "] = "31026",
    ["غصن مرجان"] = "31027", ["بيض نجم البحر "] = "31028", ["مرقعه الحبر"] = "31030", ["صلصال الطحالب"] = "31031",
    ["شرائح مرجان"] = "31032", ["صدف اذن البحر"] = "31033", ["جمبري ضخم علي البخار"] = "31034", ["سلطعون مثلج علي البخار "] = "31035",
    ["سلطعون  لازق"] = "31036", ["قلاده حمراء"] = "32010", ["قلاده المحار"] = "32011", ["قلاده  اللؤلؤ"] = "32012",
    ["قرط الأذن بالصدف"] = "32013", ["قرط الأذن ريشه الطاؤس"] = "32014", ["قرط الأذن ريشه الاوز"] = "22015",
    ["قناع الوجه بالطين"] = "32016", ["قناع الوجه بالاعشاب البحريه"] = "32017", ["قناع الوجه بالشوفان"] = "32018",
    ["قناع الوجه بالورد"] = "32019", ["قناع الوجه بالحليب"] = "32020", ["قناع الوجه بالمايونيز"] = "32021",
    ["قناع الوجه  باليمون"] = "32022", ["قناع الوجه  المرجاني "] = "32023", ["قناع الوجه بالموز"] = "32024",
    ["مراه علي شكل قنديل البحر "] = "32025", ["مراه  ورد ماجاني"] = "32026", ["مراه الؤلؤ "] = "32027",
    ["خاتم الورد"] = "500389", ["اكليل الغار"] = "500410", ["قرط اذن الحب"] = "500412", ["زجاجه اريج شجره الشاي"] = "32028",
    ["قلاده الريش "] = "500452", ["زجاجه اريج  لافندر "] = "32029", ["زجاجه اريج بابونج"] = "32030",
    ["زجاجه اريج زهره العسل"] = "32031", ["زجاجه اريج الزنبق"] = "32032", ["زجاجه اريج  زهره  البنفسجي"] = "32033",
    ["اكليل بلومريا"] = "500517", ["قلاده بيضاء"] = "500546", ["قلب ازرق"] = "500547", ["قلاده زجاجيه"] = "500548",
    ["قناع افوكادو"] = "500666", ["كريم زيتون الوجه"] = "500676", ["صابون الاجاص ليد"] = "500798",
    ["مرهم  شفاه بنكهه الجوافه"] = "500935", ["كريم مصنوع يدويا"] = "501122"
}

local sea_luck_items = {
    {name="اعشاب الخليج", code="5011;500017;07;05", refine_len=-5},
    {name="اعشاب البحر", code="31031;15", refine_len=-2},
    {name="صدفة", code="31022;50", refine_len=-2},
    {name="حلزون بحر بزاق", code="31023;30", refine_len=-2},
    {name="مرجان", code="31027;31032;30;20", refine_len=-5},
    {name="نجمة البحر", code="31027;30", refine_len=-2},
    {name="سلطعون", code="31024;50", refine_len=-2},
    {name="جمبري ابو سوم", code="700052;10", refine_len=-2},
    {name="كابوريا الطين", code="31025;40", refine_len=-2},
    {name="الكابوريا", code="31025;31026;15;06", refine_len=-5},
    {name="سلطعون مثلج", code="31036;50", refine_len=-2},
    {name="سلطعون ضفدع احمر", code="31025;15", refine_len=-2},
    {name="اخطبوط", code="31030;20", refine_len=-2}
}

function SMART_ENGINE(search, valueType, refine, edit, S, R, E, C)
    local srch = tostring(search)
    local edt = tostring(edit)
    local rfn = tostring(refine)
    gg.setVisible(false)

    if S == 1 then
        gg.searchNumber(srch, valueType, false, gg.SIGN_EQUAL, 0, -1, 0)
    end

    local results = gg.getResults(100000)
    if #results == 0 then
        if not SETTINGS.skip_alerts then gg.alert('لم يتم العثور علي نتائج قم باعاده البحث🔁') end
        return
    end

    if R == 1 then
        if type(refine) == 'table' then
            for _, r in ipairs(refine) do
                gg.loadResults(results)
                gg.refineNumber(r, valueType, false, gg.SIGN_EQUAL, 0, -1, 0)
                local refined_results = gg.getResults(100000)
                if #refined_results > 0 and E == 1 then
                    gg.editAll(edt, valueType)
                end
            end
        else
            gg.refineNumber(rfn, valueType, false, gg.SIGN_EQUAL, 0, -1, 0)
        end
    end

    if E == 1 then
        local res = gg.getResults(100000)
        gg.editAll(edt, valueType)
    end

    if C == 1 then
        gg.clearResults()
    end
    return results
end

function safe_batch_edit(limit, val)
    local results = gg.getResults(limit)
    if #results == 0 then return end
    
    local batch_size = 50 -- Safe batch size to prevent crash
    for i = 1, #results, batch_size do
        local batch = {}
        for j = i, math.min(i + batch_size - 1, #results) do
            results[j].value = val
            results[j].freeze = false
            table.insert(batch, results[j])
        end
        gg.setValues(batch)
        gg.sleep(20) -- Small delay between batches
    end
    gg.toast("تم تعديل " .. #results .. " قيمة بأمان")
end

function luck_search_edit(search_str, refine_str, edit_str, type_in)
    gg.setVisible(false)
    -- type_in: 64=Double, 1=Byte
    gg.searchNumber(search_str, type_in, false, gg.SIGN_EQUAL, 0, -1, 0)
    if refine_str then
        gg.refineNumber(refine_str, type_in, false, gg.SIGN_EQUAL, 0, -1, 0)
    end
    local res = gg.getResults(200)
    if #res == 0 then
        gg.toast("لم يتم العثور على نتائج: " .. search_str)
        return
    end
    gg.editAll(edit_str, type_in)
    gg.clearResults()
    gg.toast("تم التعديل: " .. search_str)
end

function sea_food_luck_menu()
    local menu = { "✅ اختيار الكل (Select All)" }
    for _, item in ipairs(sea_luck_items) do
        table.insert(menu, item.name)
    end
    table.insert(menu, "⬅️ رجوع")

    local choice = gg.multiChoice(menu, nil, "حظ المأكولات البحرية (Sea Food Luck)")
    if choice == nil then return end

    if choice[#menu] then return end -- Back

    local to_process = {}
    if choice[1] then -- Select All
        for i, item in ipairs(sea_luck_items) do
            table.insert(to_process, item)
        end
    else
        for i, _ in pairs(choice) do
            if i > 1 then
                table.insert(to_process, sea_luck_items[i-1])
            end
        end
    end

    for _, item in ipairs(to_process) do
       
        local sub = string.sub(item.code, item.refine_len)
        SMART_ENGINE(item.code, 64, sub, "100", 1, 1, 1, 1)
    end
    gg.alert("تم تفعيل حظ المأكولات البحرية بنجاح 🦞")
end

function fishing_luck_action()
    gg.setVisible(false)
    gg.unrandomizer(1,nil,1,nil)
    SMART_ENGINE("h 66 69 73 68 5F 6A 75 6D 70 5F 70 6F 77 65 72", 1, nil, "0", 1, 0, 1, 1)
    gg.toast("تم تفعيل حظ الصيد")
    gg.alert("❤️ في حال تجمد الصيد، يرجى إلغاء وضع الحظ ثم إعادة تفعيله ❤️")
end

function green_coupons_and_food_action()
    gg.setVisible(false)
    gg.toast("جاري تفعيل طعام السمك...")
    SMART_ENGINE("200;1000", 4, "1000", "8000000", 1, 1, 1, 1)
    
    gg.toast("جاري تفعيل الكوبونات الخضراء...")
    local q_searches = {
        "Q'fish_jump_power'", 
        "Q'fish_stamina_growth'", 
        "Q'fish_lv1'", 
        "Q'fish_lv2'"
    }
    for _, q in ipairs(q_searches) do
        SMART_ENGINE(q, 1, nil, "0", 1, 0, 1, 1)
    end
    
    -- Speed & Unrandomizer
    gg.setSpeed(4)
    gg.unrandomizer(8000000, 0, 1.0, 0.0)
    
    gg.alert("تم تفعيل الكوبونات الخضراء + طعام السمك بنجاح! 🎣\n(صيد سعيد 😴)")
end

function fishing_menu()
    local menu = {
        "🎣 كوبونات خضراء + زيادة طعام الاسماك (مدمج)",
        "🍀 حظ الصيد",
        " حظ المأكولات البحرية",
        "⬅️  رجوع "
    }
    
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end
    
    if choice == 1 then green_coupons_and_food_action() end
    if choice == 2 then fishing_luck_action() end
    if choice == 3 then sea_food_luck_menu() end
    if choice == 4 then return end
    
    return fishing_menu()
end

function parseTime(str)
    local h, m, s = str:match("(%d+):(%d+):(%d+)")
    h = tonumber(h) or 0
    m = tonumber(m) or 0
    s = tonumber(s) or 0
    return (h * 3600) + (m * 60) + s
end

function cloud_haven_action()
    local menu = {
        "🌱 تصفير وقت الزرع",
        "🌳 تصفير وقت الشجر",
        "🚜 تصفير وقت الآلات ",
        "⚡ تثبيت طاقة السحاب",
        "⏳ تثبيت طاقة الصيد",
        "⬅️ رجوع"
    }
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end

    if choice == 1 then
        local l = {'لفت','فطر','بازلاء','اناناس','بطيخ','يقطين','قمح'}
        local t = {'00:01:30','00:05:00','00:03:00','04:00:00','02:00:00','06:00:00','04:00:00'}
        local s = gg.choice(l, nil, "اختر نوع الزرع لتصفيره")
        if s then 
            local sec = parseTime(t[s])
            SMART_ENGINE('2049;'..sec, 4, tostring(sec), "1", 1, 1, 1, 1)
            gg.alert("تم تصفير وقت الزرع: "..l[s])
        end
    end

    if choice == 2 then
        local l = {'تفاح','خوخ','برتقال','اجاص','قلنبان'}
        local t = {'04:00:00','05:00:00','06:00:00','00:15:00','08:00:00'}
        local s = gg.choice(l, nil, "اختر نوع الشجر لتصفيره")
        if s then 
            local sec = parseTime(t[s])
            SMART_ENGINE('2049;'..sec, 4, tostring(sec), "1", 1, 1, 1, 1)
            gg.alert("تم تصفير وقت الشجر: "..l[s])
        end
    end

    if choice == 3 then
        local i = gg.prompt({"ساعات","دقيقة","ثانية"}, {"0","0","0"}, {"number","number","number"})
        if i then
            local tot = (safe_number(i[1], 0) * 3600) + (safe_number(i[2], 0) * 60) + safe_number(i[3], 0)
            if tot > 0 then 
                SMART_ENGINE(tot, 64, tot, "30", 1, 1, 1, 1)
                gg.alert("تم تصفير وقت الآلات")
            end
        end
    end

    if choice == 4 then 
        SMART_ENGINE('120;15;1', 64, '120', '0.5', 1, 1, 1, 1) 
        gg.alert("تم تثبيت طاقة السحاب")
    end

    if choice == 5 then 
        SMART_ENGINE('600;150', 64, '600', '1', 1, 1, 1, 1) 
        gg.alert("تم تثبيت طاقة الصيد")
    end

    if choice == 6 then return end
    
    return cloud_haven_action()
end
function buy_86_dinars_loop()
    gg.alert("💚 للحصول على 86 دينار 💸\nسيتم البحث عن الأكواد ثم تنفيذ 15 محاولة تلقائياً.\nيرجى اتباع التعليمات وانتظار العد التنازلي بين كل محاولة.")
    
    local sleep_ms = prompt_delay_ms(15)
    if not sleep_ms then return end

    local arr = {
        [1] = "1000;1101;1001;1102;1002;1103",
        [2] = "1003;1104;1111;1118;1125;1004",
        [3] = "1105;1112;1119;1126;1106;1113",
        [4] = "1120;1127;10050;10051;10052;10053",
        [5] = "10054;1107;1114;1121;1128;10060",
        [6] = "10061;10062;10063;10064;1108;1115",
        [7] = "1122;1129;10070;10071;10072;10073",
        [8] = "10074;1109;1116;1123;1130;10080",
        [9] = "10081;10084;10082;10083;1110;1117",
        [10] = "1124;1131;10090;10091;10092;10093",
        [11] = "10094;10115;10116;10117;10118;10119",
        [12] = "10100;10102;10103;10104;10105;10120",
        [13] = "10121;10122;10123;10124;10110;10111",
        [14] = "10112;10113;10114;10125;10126;10127",
        [15] = "10128;10129;1003;1000;1001;1002"
    }

    gg.setVisible(false)
    gg.clearResults()
    gg.searchNumber('7000;55000~55043;6000~6210;2000~2112;5562~5600;10050~10130', gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)

    if gg.getResultsCount() == 0 then
        gg.searchNumber('7000;55000~55043;6000~6210;2000~2112;5562~5600;1000~1131', gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
    end

    if gg.getResultsCount() == 0 then
        gg.alert("⚠️ لم يتم العثور على نتائج للبحث.\nتأكد من وجود العناصر المطلوبة في اللعبة.")
        return
    end

    gg.getResults(15) -- Limit to 6 results as per original logic

    for i = 1, #arr do
        gg.editAll(arr[i], gg.TYPE_DWORD)
        gg.toast("👉 يرجى السحب الآن (محاولة " .. i .. ")")
        if i < #arr then -- Wait only if there are more steps
            wait_with_countdown(sleep_ms, "المحاولة التالية (" .. (i+1) .. ")")
        end
    end
    
    gg.alert("✅ اكتمل تنفيذ جميع المحاولات (15 محاولة).\nمبروك عليك الدنانير! 🎉")
    gg.clearResults()
end
    

function modified_features_menu()
    local menu = {
        "💵 شراء 86 دينار (تكرار)",
        "🔓 ديكورات وحروف",
        "🌳 أشجار بالكوبون ",
        "🚜 حيوانات وآلات بالكوبون",
        "حروف المزرعة🇪🇬",
        "🔭 طلاء وتلسكوب ",
        "🎉 فاعليات تلقائي ",
        "⚡ مطورات خارقة ",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end
    
    if choice == 1 then buy_86_dinars_loop() end
    
    if choice == 2 then -- Decorations & Letters (Limit Unlock)
        gg.clearResults()
        gg.searchNumber("Q'limit_config_new", gg.TYPE_BYTE)
        local revert = gg.getResults(100000)
        gg.editAll("0", gg.TYPE_BYTE)
        gg.clearResults()
        gg.toast("تم فتح حدود الديكورات والحروف")
    end
    
    if choice == 3 then -- Trees with Coupons
        local boom = {
            "2044;2051;2054;2055;2056;2057", "2058;2059;2060;2062;2089;2090",
            "2092;2094;2095;2096;2097;2098", "2099;2100;2101;2102;2103;2104",
            "2105;2106;2107;2108;2109;2110", "2111;2112;2054;2056;2058;2060"
        }
        process_coupon_loop(boom, "أشجار بالكوبون")
    end
    
    if choice == 4 then -- Animals/Machines with Coupons
        local kkk = {
            "55000;55001;55002;55003;55004;55005",
            "55006;55007;55008;55009;55010;55043"
        }
        process_coupon_loop(kkk, "حيوانات وآلات بالكوبون")
    end
    
    if choice == 5 then -- Farm Letters
        local fo = { "20171", "20174", "20220", "20221", "20222", "20223", "20226", "30077", "30078", "30080", "30103", "200264", "200553", "200554", "200555", "200556", "200557", "200558", "300211", "590082", "590083", "590084", "590126", "200402", "590087", "30079"}
        gg.alert("🔥 ستجد الحروف في قسم الأعلام 🔥")
        gg.setVisible(false)
        local ins = 590094
        for i = 1, #fo do
            gg.searchNumber(fo[i], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
            local results = gg.getResults(12000)
            if #results > 0 then
                gg.editAll(ins, gg.TYPE_DWORD)
            end
            gg.clearResults()
            ins = ins + 1
        end
        gg.toast("تم تحويل الأعلام إلى حروف")
    end
    
    if choice == 6 then -- Paint & Telescope
        gg.alert("🚀 يرجى التوجه إلى متجر الآلات - قسم المواد 🚀") 
        gg.setVisible(false)
        gg.searchNumber("101002", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        gg.getResults(12000)
        gg.editAll("1577", gg.TYPE_DWORD)
        gg.clearResults()
        
        gg.searchNumber("1631", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        gg.getResults(12000)
        gg.editAll("1576", gg.TYPE_DWORD)
        gg.clearResults()
        
        gg.searchNumber("101003", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        gg.getResults(12000)
        gg.editAll("1600", gg.TYPE_DWORD)
        gg.clearResults()
        gg.toast("تم التعديل")
    end
    
    if choice == 7 then -- Auto Events
        local fo2 = { "20171", "20174", "20220", "20221", "20222", "20223", "20226", "30077", "30078", "30080", "30103", "200264", "200553", "200554", "200555", "200556", "200557", "200558", "300211", "590082", "590083", "590084", "590126", "200402", "590087", "30079", "200403", "200442", "200443"}
        local edd = { "13101", "13103", "13105", "13113", "13117", "30001", "13501", "500488", "501490", "590400", "590449", "590483", "590485", "590513", "590544", "590569", "500104", "500140", "500169", "590323", "500200", "500224", "500242", "500303", "500369", "500402", "500442", "590317", "590432"}
        
        gg.alert("🔥 ستجد الفاعليات في قسم الأعلام 🔥")
        gg.setVisible(false)
        for i = 1, #fo2 do
            gg.searchNumber(fo2[i], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
            local results = gg.getResults(100)
            if #results > 0 then
                gg.editAll(edd[i], gg.TYPE_DWORD)
            end
            gg.clearResults()
        end
        gg.toast("تم تفعيل الفاعليات")
    end
    
    if choice == 8 then -- Super Upgrades
        local fo3 = { "20171", "20174", "20220", "20221", "20222", "20223", "20226", "30077", "30078", "30080", "30103", "200264", "200553", "200554", "200555", "200556", "200557", "200558"}
        local edd2 = { "80003", "80103", "80203", "80303", "80403", "80503", "80603", "80622", "80642", "80662", "80682", "80702", "80722", "80742", "204500", "203700", "205200", "204400"}
        
        gg.alert("🔥 ستجد المطورات الخارقة في قسم الأعلام 🔥")
        gg.setVisible(false)
        for i = 1, #fo3 do
            gg.searchNumber(fo3[i], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
            local results = gg.getResults(100)
            if #results > 0 then
                gg.editAll(edd2[i], gg.TYPE_DWORD)
            end
            gg.clearResults()
        end
        gg.toast("تم تفعيل المطورات")
    end
    
    if choice == 9 then return end
    
    return modified_features_menu()
end

function process_coupon_loop(codes_array, feature_name)
    gg.setVisible(false)
    -- Initial search to set the scope
    gg.searchNumber("7000;55000~55043;6000~6205;2000~2112;5562~5600;10050~10130", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
    if gg.getResultsCount() == 0 then
         gg.searchNumber("7000;55000~55043;6000~6205;2000~2112;5562~5600;1000~1131", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
    end
    if gg.getResultsCount() == 0 then
        gg.alert("لم يتم العثور على نتائج للبحث الأولي")
        return
    end
    gg.getResults(6)
    
    for i = 1, #codes_array do
        gg.editAll(codes_array[i], gg.TYPE_DWORD)
        gg.toast(feature_name .. " - مجموعة " .. i .. "/" .. #codes_array .. "\nيرجى السحب الآن")
        
        -- Wait loop
        for k = 15, 1, -1 do
            gg.toast(feature_name .. "\nالمحاولة التالية في: " .. k .. " ثانية")
            gg.sleep(1000)
        end
    end
    gg.clearResults()
    gg.alert(feature_name .. " - تم الانتهاء")
end

function farm_activations_menu()
    local menu = {
        "🏠 بيت الزوار ",
        "🙋 بيت خالد ",
        "🎟️ زيادة تذاكر التنظيف ",
        "📝 انجاز المهام اليومية",
        " رفع مستوى 🆙",
        "🎂 كعكة عيد الميلاد 10800 -> 80",
        "📉 تقليل كعكة الحب 10800 -> 1",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end
    
    if choice == 1 then -- Visitor House
        SMART_ENGINE("467;1::5", 64, "1", "0", 1, 1, 1, 1) -- 467D;1E::5 -> 1 -> 0
        SMART_ENGINE("36;162;1095", 64, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("1;3;2;20;4;5;6;14::999", 64, "1", "0", 1, 1, 1, 1)
        gg.toast("تم تفعيل بيت الزوار")
    end
    
    if choice == 2 then -- Khaled House
        SMART_ENGINE("50000;5;1", 4, "1", "1000", 1, 1, 1, 1)
        SMART_ENGINE("Q'size_x'", 1, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("Q'size_y'", 1, nil, "0", 1, 0, 1, 1)
        gg.alert("تم تفعيل بيت خالد. اشتري السجادة وخزنها في مستودع الاثاث.")
    end
    
    if choice == 3 then -- Cleaning Tickets
        gg.alert("افتح قايمة الجيران واختار تذاكر التنظيف")
        SMART_ENGINE("20;300", 64, "20", "300", 1, 1, 1, 1)
        gg.toast("تم زيادة تذاكر التنظيف")
    end
    
    if choice == 4 then -- Daily Missions
        gg.clearResults()
        gg.searchNumber("27000~27099;1~2000", 64) -- Double
        local r = gg.getResults(100000)
        local ref = {1, 2, 3, 5, 6, 10, 12, 20, 30, 2000}
        for _, v in ipairs(ref) do
            gg.loadResults(r)
            gg.refineNumber(tostring(v), 64)
            local res = gg.getResults(100000)
            gg.editAll("0", 64)
        end
        gg.clearResults()
        gg.toast("تم انجاز المهام اليومية")
    end
    
    if choice == 5 then -- Level Up
        SMART_ENGINE("Q'tree_spacing'", 1, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("Q'size_x'", 1, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("Q'size_y'", 1, nil, "0", 1, 0, 1, 1)
    end
    
    if choice == 6 then -- Birthday Cake
        gg.alert("لازم الكعكه تكون في وضع السحب")
        gg.clearResults()
        gg.searchNumber("43997644991024", 32) -- QWORD
        if gg.getResultsCount() == 0 then
            gg.clearResults()
            gg.searchNumber("10800", 4) -- DWORD
            if gg.getResultsCount() > 0 then
                gg.editAll("80", 4)
            else
                gg.alert("لم يتم العثور على نتائج!")
            end
        else
            gg.editAll("43997644980284", 32)
        end
        gg.clearResults()
        gg.unrandomizer(7, 0, 0.0, 0.0)
        gg.toast("تم تفعيل كعكة عيد الميلاد")
    end

    if choice == 7 then -- Reduce Love Cake (New)
        gg.alert("يجب أن تكون الكعكة في وضع السحب!")
        SMART_ENGINE("10800", 4, nil, "1", 1, 0, 1, 1)
        gg.alert("تم تقليل كعكة الحب الى 1")
    end
    
    if choice == 8 then return end
    
    return farm_activations_menu()
end

function island_activations_menu()
    local menu = {
        "🚢 الغواصة ",
        "⛲ زيادة طاقة النافورة ",
        "⚡ تثبيت النافورة ",
        "🔧 النافورة ديناميكي ",
        "⭐⭐⭐ فتح نجوم الالات ",
        "🎲 تخطي نقاط الجزيرة وتشغيل الحظ ",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end
    
    if choice == 1 then -- Submarine
        SMART_ENGINE("1800;5", 64, "5", "999999", 1, 1, 1, 1)
        gg.toast("تم تفعيل نقاط الغواصه")
        SMART_ENGINE("5;10;25::99", 64, "5", "999", 1, 1, 1, 1)
        SMART_ENGINE("3;25::222", 64, "25", "100", 1, 1, 1, 1)
        SMART_ENGINE("1;6;7;8;9", 64, "1", "10", 1, 1, 1, 1)
        gg.unrandomizer(888888888, 0, 1.0, 0.0)
        gg.alert("تم تفعيل الغواصة والحظ")
    end
    
    if choice == 2 then -- Increase Fountain Energy (1000)
        gg.alert("تأكد أن النافورة مفتوحة")
        gg.setVisible(false)
        -- Step 1: Error Fix
        gg.searchNumber("8245935277855761735", gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local qres = gg.getResults(100)
        if #qres > 0 then
            gg.editAll("0", gg.TYPE_QWORD)
        end
        gg.clearResults()

        -- Step 2: Search Time;Energy
        gg.searchNumber("90;75", gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local res_check = gg.getResults(100)
        if #res_check == 0 then
            gg.alert("عفواً، لم يتم العثور على القيم (90 وقت، 75 طاقة).\nتأكد أن النافورة مفتوحة والقيم مطابقة.")
            gg.clearResults()
            return
        end
        
        -- Refine Max Energy (75) and edit to 1000
        gg.refineNumber("75", gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        safe_batch_edit(100, "1000") -- Use safe batch for 100 results
        gg.clearResults()
        
        gg.alert("تم زيادة نقاط الطاقة إلى 1000 بنجاح")
    end

    if choice == 3 then -- Fix Fountain (From red fox.lua)
        gg.setVisible(false)
        -- Step 1: Try Magic Code
        gg.searchNumber("8245935277855761735", gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local qres = gg.getResults(100)
        if #qres > 0 then gg.editAll("0", gg.TYPE_QWORD) end
        gg.clearResults()
    
        -- Step 2: Search Time;Energy
        gg.searchNumber("90;75", gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local res_check = gg.getResults(100)
        if #res_check == 0 then
            gg.alert("عفواً، لم يتم العثور على القيم (90 وقت، 75 طاقة).\nتأكد أن النافورة مفتوحة والقيم مطابقة.")
            gg.clearResults()
            return
        end
        
        gg.refineNumber("75", gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        
        -- Prompt
        local num = gg.prompt({"أدخل القيمة الجديدة للطاقة (أقل من الحالية):"}, {""}, {"number"})
        if num == nil or num[1] == "" then return end
    
        gg.setVisible(false)
        safe_batch_edit(100, num[1]) -- Safe batch edit
        gg.clearResults()
        
        -- Step 3: Search Time;NewEnergy
        gg.searchNumber("90;"..num[1], gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        gg.refineNumber("90", gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        safe_batch_edit(100, "1") -- Safe batch edit
        gg.clearResults()
        
        gg.alert("تم تثبيت النافورة بنجاح.")
    end

    if choice == 4 then -- Dynamic Fountain
        gg.alert("أدخل القيم الحالية للوقت والطاقة للبحث عنها، ثم أدخل القيمة الجديدة التي تريد تثبيتها.")
        local prompt = gg.prompt(
            {"⏳ الوقت الحالي (مثال: 90)", "⚡ الطاقة الحالية (مثال: 75)", "✨ الطاقة الجديدة المطلوبة"},
            {"90", "75", "1000"},
            {"number", "number", "number"}
        )
        if prompt == nil then return end
        
        local curr_time = prompt[1]
        local curr_energy = prompt[2]
        local new_energy = prompt[3]
        
        gg.setVisible(false)
        -- Step 1: Error Fix (Restored & Optimized)
        -- This step is crucial to prevent Game Error 1030006
        gg.clearResults()
        gg.setRanges(gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS) -- Safe regions
        gg.searchNumber("8245935277855761735", gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local err_res = gg.getResults(200) -- Limit 200 to prevent crash but ensure fix
        if #err_res > 0 then
            gg.editAll("0", gg.TYPE_QWORD)
            gg.toast("تم معالجة حماية اللعبة")
        end
        gg.clearResults()
        gg.sleep(200)

        -- Step 2: Search Current Time;Energy
        -- Using C_ALLOC | ANONYMOUS to find values safely
        gg.setRanges(gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS)
        local search_str = curr_time .. ";" .. curr_energy
        gg.searchNumber(search_str, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local res_check = gg.getResults(100) -- Safe limit
        if #res_check == 0 then
            gg.alert("عفواً، لم يتم العثور على القيم (" .. curr_time .. " وقت، " .. curr_energy .. " طاقة).\nتأكد من صحة الأرقام.")
            gg.clearResults()
            gg.setRanges(-1) -- Restore all ranges
            return
        end
        
        gg.refineNumber(curr_energy, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local res_edit = gg.getResults(100)
        if #res_edit > 0 then
            gg.editAll(new_energy, gg.TYPE_DOUBLE)
            gg.toast("تم تغيير الطاقة إلى " .. new_energy)
        end
        gg.clearResults()
        
        -- Step 3: Fix Time (Lock to 1)
        gg.sleep(500)
        local fix_search_str = curr_time .. ";" .. new_energy
        gg.searchNumber(fix_search_str, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        gg.refineNumber(curr_time, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local res_time = gg.getResults(100)
        if #res_time > 0 then
             gg.editAll("1", gg.TYPE_DOUBLE)
        end
        gg.clearResults()
        gg.setRanges(-1) -- Restore ranges to default (All)
        
        gg.alert("تم تثبيت النافورة ديناميكياً بنجاح")
    end
    
    if choice == 5 then -- Unlock Machine Stars
        SMART_ENGINE("80;600;1800", 4, nil, "80", 1, 0, 1, 1) -- Set all to 80
        gg.alert("تم فتح الثلاث نجوم للآلات")
    end
    
    if choice == 6 then -- Skip Island Points & Luck
        SMART_ENGINE("1400", 64, nil, "0", 1, 0, 1, 1)
        gg.unrandomizer(1, 0, 1.0 ,0.0)
        gg.alert("تم تخطي نقاط الجزيره وفتح الخرده وتشغيل الحظ")
    end
    
    if choice == 7 then return end
    
    return island_activations_menu()
end

function decorations_list_menu()
    local choices = {
        'منتج كعكة الحب', 'آله علكه مدعلبة', 'الصدفة الغامضة', 'المنطاد الزاهي', 'بابا نويل', 
        'بيت الإمبراطور', 'ثلاجة صغيرة', 'خيمة', 'دراجة الأقحوان', 'دراجة بالون', 
        'دولفين', 'سبورة المدرسة', 'سفينة بخارية', 'سلم اليقطين', 'شتلة نابضة بالحياة', 
        'شجرة خريف قيقب الحريق', 'شجرة رأس سنة ثلجية', 'شجيرة 4', 'صندوق رسائل خشبي', 
        'صندوق فواكه مثلجة', 'فطر عملاق', 'قارب صيد خشبي', 'قاعدة الجمباز', 
        'قاعدة الرماية', 'قلعة الجليد', 'قيثارة الحالم', 'كرة الريشة', 'كشك المثلجات', 
        'كوخ الإسكيمو', 'مسطرة فرانكشتاين', 'منزل الدجاج', 'منزل مسكون',
        '⬅️ رجوع'
    }
    
    local a3lam = { 
        20171, 20174, 20220, 20221, 20222, 20223, 20224, 20225, 20226, 30077, 30078, 30079, 
        30080, 30103, 200264, 200402, 200403, 200442, 200443, 200463, 200464, 200553, 
        200554, 200555, 200556, 200557, 200558, 300211, 590082, 590083, 590084, 590085, 590086 
    }
    
    local fa3lyat = { 
        590323, 590317, 590485, 590645, 500224, 500402, 590569, 500169, 500104, 590432, 
        501490, 13117, 500200, 30001, 590483, 590513, 500488, 13113, 590544, 13501, 
        590449, 590400, 13101, 13103, 500242, 590625, 13105, 500369, 590516, 500140, 
        500178, 500303, 500442 
    }
    
    local choice = gg.choice(choices, nil, "قائمة الديكورات والفعاليات (Decorations & Events)")
    if choice == nil or choice == #choices then 
        modified_features_menu()
        return 
    end
    
    -- Execute selected decoration swap
    -- Search for flag (a3lam) and replace with event (fa3lyat)
    SMART_ENGINE(tostring(a3lam[choice]), 4, nil, tostring(fa3lyat[choice]), 1, 0, 1, 1)
    gg.toast("تم تفعيل: " .. choices[choice])
    
    return decorations_list_menu()
end

function luck_speed_menu()
    local menu = {
        "🐟 حظ الأسماك ",
        "🎣 تثبيت صنارة الصيد في المنتصف ",
        "🍀 تفعيل الحظ ",
        "❌ إيقاف الحظ ",
        "⏩ تسريع اللعبة ",
        "⏹️ إيقاف السرعة ",
        "🍔 حظ بيت الطعام ",
        " تفعيل شامل للحظ ",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end
    
    if choice == 1 then -- Fishing Luck
        fishing_luck_action()
    end

    if choice == 2 then -- Fix Rod Center (New)
        gg.alert("سوف يتم تثبيت الصنارة في المنطقه الحمراء لسرعه الصيد")
        SMART_ENGINE("Q'fish_jump_power'", 1, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("Q'fish_stamina_growth'", 1, nil, "0", 1, 0, 1, 1)
        -- Map Lv1/Lv2 to Lv3 for perfect center catch
        SMART_ENGINE("Q'fish_lv1'", 1, nil, "Q'fish_lv3'", 1, 0, 1, 1)
        SMART_ENGINE("Q'fish_lv2'", 1, nil, "Q'fish_lv3'", 1, 0, 1, 1)
        gg.alert("تم تثبيت الصنارة")
    end
    
    if choice == 3 then -- Activate Luck
        gg.unrandomizer(1, 0, 1.0, 0.0)
        gg.toast("تم تفعيل الحظ")
    end
    
    if choice == 4 then -- Stop Luck
        gg.unrandomizer(nil, nil, nil, nil)
        gg.toast("تم إيقاف الحظ")
    end
    
    if choice == 5 then -- Speed Up
        local input = gg.prompt({"أدخل قيمة السرعة (مثال: 3):"}, {"3"}, {"number"})
        if input then
            gg.setSpeed(tonumber(input[1]))
            gg.toast("تم تسريع اللعبة")
        end
    end
    
    if choice == 6 then -- Stop Speed
        gg.setSpeed(1.0)
        gg.toast("تم إيقاف السرعة")
    end
    
    if choice == 7 then -- Food House Luck
        gg.unrandomizer(0, 1, 0, 0.01)
        gg.toast("تم تفعيل حظ بيت الطعام")
    end
    
    if choice == 8 then -- Comprehensive Luck
        gg.unrandomizer(1, nil, 1, nil)
        gg.toast("تم التفعيل الشامل للحظ")
    end
    
    if choice == 9 then return end
    
    return luck_speed_menu()
end

function featured_menu()
    local menu = {
        "🗑️ تخلص من الخطأ ",
        "🎁 دنانير وهمي من الهدايا",
        "🎙️ الاستديو ",
        "🔥 إنتاج سريع عادي ",
        "🚀 إنتاج سريع جميع الآلات والحيوانات",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil,"✪⊷⊷⊷《  ♥️👑 مــحــمــد رأفــت 👑♥️  》⊷⊶⊷✪")
    if choice == nil then return end
    
    if choice == 1 then -- Destroy Error
        gg.clearResults()
        gg.searchNumber("8245935277855761735", gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local revert = gg.getResults(100000, nil, nil, nil, nil, nil, nil, nil, nil)
        gg.editAll("0", gg.TYPE_QWORD)
        gg.processResume()
        gg.clearResults()
        gg.toast("تم تخلص من الخطأ بنجاح")
        gg.sleep(500)
    end
    
    if choice == 2 then -- Fake RC Lucky Wheel
       gg.clearResults()
    gg.toast("جاري التفعيل...")
    
    gg.searchNumber("8245935277855761735", gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
revert = gg.getResults(1000, nil, nil, nil, nil, nil, nil, nil, nil)
gg.editAll("0", gg.TYPE_QWORD)

    gg.searchNumber(":600027", gg.TYPE_BYTE)
    local r = gg.getResults(100000)

    if #r == 0 then
        gg.alert("❌ لم يتم العثور على القيم")
        return
    end

    gg.editAll(":400009", gg.TYPE_BYTE)
    gg.clearResults()

    gg.toast("✅ تم تفعيل ")
end
    
    
    if choice == 3 then -- Studio
        gg.alert("لا تفتح الاستديو الآن. انتظر حتى تظهر رسالة 'تم'.")
        gg.searchNumber("8245935277855761735", gg.TYPE_QWORD)
        gg.getResults(100000)
        gg.editAll("0", gg.TYPE_QWORD)
        gg.clearResults()
        
        gg.searchNumber("120;100", gg.TYPE_DOUBLE)
        local t = gg.getResults(100000)
        gg.loadResults(t)
        gg.refineNumber("100", gg.TYPE_DOUBLE)
        local revert = gg.getResults(100000)
        gg.editAll("99999", gg.TYPE_DOUBLE)
        
        gg.loadResults(t)
        t = nil
        gg.refineNumber("120", gg.TYPE_DOUBLE)
        revert = gg.getResults(100000)
        gg.editAll("0.5", gg.TYPE_DOUBLE)
        gg.clearResults()
        gg.alert("تم! يمكنك الآن فتح الاستديو.")
    end
    
    if choice == 4 then -- Normal Fast Production
        gg.clearResults()
        gg.searchNumber("10D;2049D;50~180D", gg.TYPE_DWORD)
        local results1 = gg.getResults(gg.getResultsCount())
 
