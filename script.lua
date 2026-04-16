
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
    
    -- Add Special Options
    table.insert(names, "✏️ إدخال يدوي (5 أكواد)")
    table.insert(names, "🛍️ شراء تلقائي (Auto Buy)")
    if allow_back_to_search then
        table.insert(names, "🔙 رجوع للبحث")
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
        elseif name == "✏️ إدخال يدوي (5 أكواد)" then special_action = "manual"
        elseif name == "🛍️ شراء تلقائي (Auto Buy)" then special_action = "auto"
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
               name ~= "✏️ إدخال يدوي (5 أكواد)" and name ~= "🛍️ شراء تلقائي (Auto Buy)" and 
               name ~= "⭐ المفضلة" and name ~= "🔙 رجوع للبحث" then
                table.insert(selected_codes, codes[name])
                table.insert(selected_names, name)
            end
        end
    end

    if #selected_codes == 0 and special_action == "auto" then
        -- Auto Buy Manual Entry
        continuous_buying_action()
        return
    end

    if #selected_codes == 0 then return end

    -- If Auto Buy Tool was selected
    if special_action == "auto" then
        local time_prompt = gg.prompt({"⏱️ أدخل الوقت الفاصل بين كل مجموعة (بالدقيقة):"}, {"10"}, {"number"})
        if time_prompt and time_prompt[1] then
            run_autobuy_logic(selected_codes, tonumber(time_prompt[1]))
        end
        return
    end

    -- CASE 1: Single Selection -> Standard Search & Replace (Old Behavior)
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
        -- logic: search code, refine last part, edit to 100
        -- code e.g.: "5011;500017;07;05"
        -- refine e.g.: -5 chars -> "07;05" (Wait, string.sub with negative index)
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
    -- Part 1: Fish Food (from load_arabic.lua)
    -- Search 200;1000 (DWORD), Refine 1000, Edit 999M
    gg.setVisible(false)
    gg.toast("جاري تفعيل طعام السمك...")
    SMART_ENGINE("200;1000", 4, "1000", "8000000", 1, 1, 1, 1)

    -- Part 2: Green Coupons (from New.lua)
    -- Search Byte Strings and set to 0
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
        "🎣 『كوبونات خضراء + زيادة طعام الاسماك』 (مدمج)",
        "🍀 『حظ الصيد (Fishing Luck)』",
        " 『حظ المأكولات البحرية (Sea Food Luck)』",
        "⬅️ 『 رجوع 』"
    }
    
    local choice = gg.choice(menu, nil, "قائمة الصيد (Fishing)")
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
        "🌱 تصفير وقت الزرع (Sahaab Crops)",
        "🌳 تصفير وقت الشجر (Sahaab Trees)",
        "🚜 تصفير وقت الآلات (Sahaab Machines)",
        "⚡ تثبيت طاقة السحاب (Fixed Power)",
        "⏳ تثبيت طاقة الصيد",
        "⬅️ رجوع"
    }
    local choice = gg.choice(menu, nil, "مزرعة السحاب (Cloud Haven)")
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

    gg.getResults(6) -- Limit to 6 results as per original logic

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

function coins_store_action_rf()
    gg.alert("يرجى فتح المتجر قبل التنفيذ")
    local vals = {{'14017','14016','14020','14019','14015','11001'},{'11001','14034','14030','14031','14032','14033'}}
    SMART_ENGINE('11001~11045;12001~12719;14001~14055;15001~15054;5555~5575', 4, nil, nil, 1, 0, 0, 0)
    for i, v in ipairs(vals) do
        local r = gg.getResults(6)
        local e = {}
        for k, val in ipairs(r) do if v[k] then val.value=v[k] val.freeze=true table.insert(e,val) end end
        gg.setValues(e)
        gg.addListItems(e)
        gg.toast("اشتر المجموعة "..i)
        gg.sleep(2000)
    end
    gg.clearResults()
end

function modified_features_menu()
    local menu = {
        "💵 شراء 86 دينار (تكرار) (Buy 86 RC Loop)",
        "💰 الدنانير بالعملات (Dinars in Coins)",
        "🐠 شراء سمك بـ0 عملات (Buy Fish 0 Coins)",
        "🔓 ديكورات وحروف (فتح الحدود) (Decorations & Letters - Unlock)",
        "🦚 تنزيل آلات وحيوانات (طاووس) (Download Machines/Animals)",
        "🌳 أشجار بالكوبون (Trees with Coupons)",
        "🚜 حيوانات وآلات بالكوبون (Animals/Machines Coupons)",
        "🅰️ حروف المزرعة (تبديل أعلام) (Farm Letters)",
        "🔭 طلاء وتلسكوب (Paint & Telescope)",
        "🎉 فاعليات تلقائي (Auto Events)",
        "⚡ مطورات خارقة (Super Upgrades)",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "المميزات المعدلة (Modified Features)")
    if choice == nil then return end
    
    if choice == 1 then buy_86_dinars_loop() end
    
    if choice == 2 then coins_store_action_rf() end
    
    if choice == 3 then
        SMART_ENGINE("150", 64, nil, "0", 1, 0, 1, 1)
        gg.toast("تم شراء السمك بـ0")
    end
    
    if choice == 4 then -- Decorations & Letters (Limit Unlock)
        gg.clearResults()
        gg.searchNumber("Q'limit_config_new", gg.TYPE_BYTE)
        local revert = gg.getResults(100000)
        gg.editAll("0", gg.TYPE_BYTE)
        gg.clearResults()
        gg.toast("تم فتح حدود الديكورات والحروف")
    end
    
    if choice == 5 then -- Download Machines/Animals (Peacock)
        gg.alert("تحذير: يجب أن يكون الطاووس (كود 6001) في المستودع.\nافتح المستودع وانتظر.")
        gg.sleep(1000)
        local input = gg.prompt({"أدخل كود الطاووس (عادة 6001):"}, {"6001"}, {"number"})
        if input == nil then return end
        
        gg.sleep(100)
        gg.searchNumber(input[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local revert = gg.getResults(100000)
        
        local input1 = gg.prompt({"أدخل كود الآلة أو الحيوان الجديد:"}, {nil}, {"number"})
        if input1 == nil then return end
        
        gg.editAll(input1[1], gg.TYPE_DWORD)
        gg.sleep(100)
        gg.clearResults()
        gg.alert("تم! أخرج الطاووس من المستودع لتجد العنصر الجديد.")
    end
    
    if choice == 6 then -- Trees with Coupons
        local boom = {
            "2044;2051;2054;2055;2056;2057", "2058;2059;2060;2062;2089;2090",
            "2092;2094;2095;2096;2097;2098", "2099;2100;2101;2102;2103;2104",
            "2105;2106;2107;2108;2109;2110", "2111;2112;2054;2056;2058;2060"
        }
        process_coupon_loop(boom, "أشجار بالكوبون")
    end
    
    if choice == 7 then -- Animals/Machines with Coupons
        local kkk = {
            "55000;55001;55002;55003;55004;55005",
            "55006;55007;55008;55009;55010;55043"
        }
        process_coupon_loop(kkk, "حيوانات وآلات بالكوبون")
    end
    
    if choice == 8 then -- Farm Letters
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
    
    if choice == 9 then -- Paint & Telescope
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
    
    if choice == 10 then -- Auto Events
        local fo2 = { "20171", "20174", "20220", "20221", "20222", "20223", "20226", "30077", "30078", "30080", "30103", "200264", "200553", "200554", "200555", "200556", "200557", "200558", "300211", "590082", "590083", "590084", "590126", "200402", "590087", "30079", "200403", "200442", "200443"}
        local edd = { "13101", "13103", "13105", "13113", "13117", "30001", "13501", "500488", "501490", "590400", "590449", "590483", "590485", "590513", "590544", "590569", "500104", "500140", "500169", "500178", "500200", "500224", "500242", "500303", "500369", "500402", "500442", "590317", "590432"}
        
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
    
    if choice == 11 then -- Super Upgrades
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
    
    if choice == 12 then return end
    
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
        "🏠 بيت الزوار (Visitor House)",
        "🙋 بيت خالد (Khaled House)",
        "🎟️ زيادة تذاكر التنظيف (Cleaning Tickets)",
        "🐈 اختيار جنس الحيوان (Select Gender)",
        "🐕 تكبير الحيوانات الاليفة (Enlarge Pets)",
        "🔓 اخراج جميع الحيوانات (Release Animals)",
        "📝 انجاز المهام اليومية (Daily Missions)",
        " رفع مستوى (Level Up)🆙",
        "🎂 كعكة عيد الميلاد (Birthday Cake) [10800 -> 80]",
        "📉 تقليل كعكة الحب (Reduce Love Cake) [10800 -> 1]",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "تفعيلات المزرعة (Farm Activations)")
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
    
    if choice == 4 then -- Select Animal Gender
        gg.alert("اختيار الحيوان ذكر او انثي")
        SMART_ENGINE("81001~81033;1::60", 64, "1", "0", 1, 1, 1, 1)
        gg.toast("تم التفعيل")
    end
    
    if choice == 5 then -- Enlarge Pets
        gg.alert("لازم يكون معاك طعام خارق للحيوانات كتير")
        SMART_ENGINE("161;50", 64, "50", "0", 1, 1, 1, 1)
        gg.toast("تم تفعيل تكبير الحيوانات الاليفه")
    end
    
    if choice == 6 then -- Release All Animals
        gg.alert("تحذير: لا تستخرج حيوانات اقل من مستوى 20")
        SMART_ENGINE("1;1072693248;3;1175::17", 64, "1", "2", 1, 1, 1, 1)
        gg.toast("تم اخراج الحيوانات")
    end
    
    if choice == 7 then -- Daily Missions
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
    
    if choice == 8 then -- Level Up
        SMART_ENGINE("Q'tree_spacing'", 1, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("Q'size_x'", 1, nil, "0", 1, 0, 1, 1)
        SMART_ENGINE("Q'size_y'", 1, nil, "0", 1, 0, 1, 1)
        gg.alert("تم تفعيل رفع المستوي. لا تشتري اكثر من 500 خلية نحل.")
    end
    
    if choice == 9 then -- Birthday Cake
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

    if choice == 10 then -- Reduce Love Cake (New)
        gg.alert("يجب أن تكون الكعكة في وضع السحب!")
        SMART_ENGINE("10800", 4, nil, "1", 1, 0, 1, 1)
        gg.alert("تم تقليل كعكة الحب الى 1")
    end
    
    if choice == 11 then return end
    
    return farm_activations_menu()
end

function island_activations_menu()
    local menu = {
        "🚢 الغواصة (Submarine)",
        "🏥 المستشفى (Hospital)",
        "⛲ زيادة طاقة النافورة (Increase Fountain Energy)",
        "⚡ تثبيت النافورة (Fix Fountain)",
        "🔧 النافورة ديناميكي (Dynamic Fountain)",
        "⭐⭐⭐ فتح نجوم الالات (Unlock Machine Stars)",
        "🎲 تخطي نقاط الجزيرة وتشغيل الحظ (Skip Island Points & Luck)",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "تفعيلات الجزيرة (Island Activations)")
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
    
    if choice == 2 then -- Hospital
        gg.alert("يجب أن تكون في المزرعة وتفتح المستشفى")
        SMART_ENGINE("3;49285::13", 64, "3", "4", 1, 1, 1, 1) -- 3E;49285D::13 -> 3 -> 4
        gg.alert("تم تفعيل المستشفى. يمكنك الآن تأكيل الحيوانات.")
    end
    
    if choice == 3 then -- Increase Fountain Energy (1000)
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

    if choice == 4 then -- Fix Fountain (From red fox.lua)
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

    if choice == 5 then -- Dynamic Fountain
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
    
    if choice == 6 then -- Unlock Machine Stars
        SMART_ENGINE("80;600;1800", 4, nil, "80", 1, 0, 1, 1) -- Set all to 80
        gg.alert("تم فتح الثلاث نجوم للآلات")
    end
    
    if choice == 7 then -- Skip Island Points & Luck
        SMART_ENGINE("1400", 64, nil, "0", 1, 0, 1, 1)
        gg.unrandomizer(1, 0, 1.0 ,0.0)
        gg.alert("تم تخطي نقاط الجزيره وفتح الخرده وتشغيل الحظ")
    end
    
    if choice == 8 then return end
    
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
        "🐟 حظ الأسماك (Fishing Luck)",
        "🎣 تثبيت صنارة الصيد في المنتصف (Fix Rod Center)",
        "🍀 تفعيل الحظ (Activate Luck)",
        "❌ إيقاف الحظ (Stop Luck)",
        "⏩ تسريع اللعبة (Game Speed)",
        "⏹️ إيقاف السرعة (Stop Speed)",
        "🍔 حظ بيت الطعام (Food House Luck)",
        "🌟 تفعيل شامل للحظ (Comprehensive Luck)",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "الحظ والسرعة (Luck & Speed)")
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
    
    if choice == 5 then -- Stop Speed
        gg.setSpeed(1.0)
        gg.toast("تم إيقاف السرعة")
    end
    
    if choice == 6 then -- Food House Luck
        gg.unrandomizer(0, 1, 0, 0.01)
        gg.toast("تم تفعيل حظ بيت الطعام")
    end
    
    if choice == 7 then -- Comprehensive Luck
        gg.unrandomizer(1, nil, 1, nil)
        gg.toast("تم التفعيل الشامل للحظ")
    end
    
    if choice == 8 then return end
    
    return luck_speed_menu()
end

function featured_menu()
    local menu = {
        "🗑️ تخلص من الخطأ (Destroy Error)",
        "🎡 دنانير وهمي دولاب الحظ (Fake RC Lucky Wheel)",
        "🎙️ الاستديو (Studio)",
        "🔥 إنتاج سريع عادي (Normal Fast Production)",
        "🚀 إنتاج سريع جميع الآلات والحيوانات (Fast Prod All)",
        "🔓 فتح الكشك بعد غلقة (Open Stall)",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "المميزات (Featured)")
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
        gg.alert("أولاً: افتح دولاب الفيش والعب دور (5 فيش).\nاختر صندوقاً واترك الآخر، وانظر لسعره.\nاكتب السعر هنا، وبعد انتهاء العد اشتري المنتج، وستزيد الدنانير.")
        local input = gg.prompt({"أدخل الرقم (السعر):"}, {nil}, {"number"})
        if input == nil then return end
        
        gg.sleep(100)
        gg.searchNumber(input[1], gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local revert = gg.getResults(100000)
        gg.editAll("-9999999", gg.TYPE_DOUBLE)
        gg.clearResults()
        gg.sleep(100)
        gg.alert("تم! اشتري المنتج الآن وتفقد دنانيرك.")
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
        local refineValues1 = {50, 55, 60, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 130, 150, 180}
        for i, value in ipairs(refineValues1) do
            gg.clearResults()
            gg.loadResults(results1)
            gg.refineNumber(value, gg.TYPE_DWORD)
            local refinedResults1 = gg.getResults(gg.getResultsCount())
            for j, res in ipairs(refinedResults1) do
                res.value = 0
                res.freeze = false
            end
            gg.setValues(refinedResults1)
        end
        gg.clearResults()
        
        gg.searchNumber("42885248450602", gg.TYPE_QWORD)
        local qwordResults2 = gg.getResults(gg.getResultsCount())
        for i, res in ipairs(qwordResults2) do
            res.value = 0
            res.freeze = false
        end
        gg.setValues(qwordResults2)
        gg.alert("تم تفعيل إنتاج سريع عادي")
    end
    
    if choice == 5 then -- Fast Production All Machines & Animals
        gg.clearResults()
        gg.searchNumber("47300474830928", gg.TYPE_QWORD)
        local t = gg.getResults(gg.getResultsCount())
        gg.editAll(0, gg.TYPE_QWORD)
        gg.clearResults()
        
        gg.searchNumber("30D;2049D;45~900D", gg.TYPE_DWORD)
        local all_results = gg.getResults(gg.getResultsCount())
        
        local function change_value(value, new_value)
            gg.clearResults()
            gg.loadResults(all_results)
            gg.refineNumber(value, gg.TYPE_DWORD)
            local t = gg.getResults(gg.getResultsCount())
            gg.editAll(new_value, gg.TYPE_DWORD)
        end
        
        local values_to_zero = {45, 50, 60, 70, 75, 80, 90, 100, 110, 120, 900}
        for _, v in ipairs(values_to_zero) do change_value(v, 0) end
        
        gg.clearResults()
        gg.searchNumber("10D;2049D;50~600D", gg.TYPE_DWORD)
        all_results = gg.getResults(gg.getResultsCount())
        
        local values_to_zero_2 = {50, 55, 60, 70, 72, 75, 80, 90, 100, 105, 110, 120, 150, 180, 600}
        for _, v in ipairs(values_to_zero_2) do change_value(v, 0) end
        
        gg.clearResults()
        gg.searchNumber("42885248450602", gg.TYPE_QWORD)
        local t = gg.getResults(gg.getResultsCount())
        gg.editAll(0, gg.TYPE_QWORD)
        gg.alert("تم تفعيل إنتاج سريع لكل الآلات والحيوانات")
    end
    
    if choice == 6 then -- Open Stall
        gg.alert("تنبيه: يجب أن يكون الكشك مقفولاً.\nأدخل عدد المنتجات (وليس العملات).")
        local input = gg.prompt({"أدخل عدد المنتجات:"}, {nil}, {"number"})
        if input == nil then return end
        
        gg.sleep(100)
        gg.searchNumber(input[1], gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        local revert = gg.getResults(100000)
        gg.editAll("0", gg.TYPE_DOUBLE)
        gg.clearResults()
        gg.sleep(100)
        gg.alert("تم فتح الكشك")
    end
    
    if choice == 7 then return end
    
    return featured_menu()
end

function lab_crops_menu()
    local menu = {
        "🍀 اوراق البرسيم الاربعه (Four Leaf Clover) [200422 -> 5101]",
        "🌽 جواهر الذره (Gem Corn) [200422 -> 5103]",
        "🍅 يقطين وطماطم (Pumpkin Tomato) [200422 -> 5105]",
        "🌶️ فلفل هاينان (Hainan Pepper) [200422 -> 5107]",
        "🍏 تفاح سوري (Syrian Apple) [200422 -> 5109]",
        "🍒 كرز سورياني (Syrian Cherry) [200422 -> 5111]",
        "🍇 رامبوتان (Rambutan) [200422 -> 5113]",
        "🍋 ليمون ماسي (Diamond Lemon) [200422 -> 5115]",
        "🫘 فول محمص (Roasted Beans) [200422 -> 5117]",
        "🍄 فطر مارشميلو (Marshmallow Mushroom) [200422 -> 5119]",
        "🍉 بطيخ المحبه (Love Watermelon) [200422 -> 5121]",
        "🍑 بذور خوخ (Peach Seeds) [200422 -> 5123]",
        "🍐 اجاص اسيوي (Asian Pear) [200422 -> 5125]",
        "🫒 زيتون كريستالي (Crystal Olive) [200422 -> 5127]",
        "🌿 بوط (Boot?) [200422 -> 7046]",
        "🍅🌿 بندوره (Tomato?) [7024 -> 7048]",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "مزروعات المختبر (Laboratory Crops)")
    if choice == nil then return end
    
    if choice == 16 then -- Special case: Replaces Alfalfa (7024)
        gg.alert("افتح الزرع الأول واختار برسيم حجازي (Alfalfa 7024) وانتظر انتهاء العد.")
        gg.searchNumber("7024", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local results = gg.getResults(100000)
        if #results > 0 then
            gg.editAll("7048", gg.TYPE_DWORD)
            gg.clearResults()
            gg.toast("تم! ازرع الآن.")
        else
            gg.alert("لم يتم العثور على البرسيم الحجازي (7024)")
        end
        return lab_crops_menu()
    end
    
    if choice == 17 then return end
    
    -- Common Logic for Oats (200422) replacement
    local codes = {
        5101, 5103, 5105, 5107, 5109, 5111, 5113, 5115, 
        5117, 5119, 5121, 5123, 5125, 5127, 7046
    }
    
    local target_code = codes[choice]
    
    if target_code then
        gg.alert("افتح الزرع الأول واختار الشوفان (Oats 200422) وانتظر انتهاء العد.")
        gg.searchNumber("200422", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
        local results = gg.getResults(100000)
        if #results > 0 then
            gg.editAll(tostring(target_code), gg.TYPE_DWORD)
            gg.clearResults()
            gg.toast("تم! ازرع الآن (كود " .. target_code .. ")")
        else
            gg.alert("لم يتم العثور على الشوفان (200422)")
        end
    end
    
    return lab_crops_menu()
end

function neighbor_requests_menu()
    local menu = {
        "⚡ اختيار الكل (Select All)",
        "🐮 مطور البقره (Cow) [1536]",
        "🐰 مطور الارنب (Rabbit) [1614]",
        "🐔 مطور قن الدجاج (Chicken Coop) [1561]",
        "🦚 مطور طاووس (Peacock) [1832]",
        "🐑 مطور خروف (Sheep) [1783]",
        "🦌 مطور الغزال (Deer) [1658]",
        "🐦 مطور نعامه (Ostrich) [1852]",
        "🐂 مطور ثور فرنسي (French Bull) [1760]",
        "🦃 مطور ديك رومي (Turkey) [1854]",
        "🍞 مطور مخبز (Bakery) [1696]",
        "🧀 مطور معمل الجبن (Cheese Lab) [1537]",
        "🌾 مطور الطاحونه (Mill) [1559]",
        "🥣 مطور الصلصه (Sauce) [1654]",
        "🍹 مطور الة العصير (Juice Machine) [1612]",
        "🍯 مطور الة المربي (Jam Machine) [1571]",
        "🍬 مطور الة الحلوي (Candy Machine) [1660]",
        "🍭 مطور الة السكر (Sugar Machine) [1656]",
        "🥤 مطور العصاره (Squeezer) [1646]",
        "🌸 مطور الة الزهور (Flower Machine) [1762]",
        "🍔 مطور آلة البرغر (Burger Machine) [1644]",
        "🧸 مطور الة دمي الدببه (Teddy Bear Machine) [1874]",
        "🍖 مطور الة البسطرمه (Pastrami Machine) [1876]",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "طلب مطورات من الجيران (Request Upgrades)")
    if choice == nil then return end
    
    local function request_upgrade(id_code)
        gg.clearResults()
        gg.searchNumber(tostring(id_code), gg.TYPE_DOUBLE)
        local results = gg.getResults(100000)
        if #results > 0 then
            gg.editAll("15", gg.TYPE_DOUBLE)
        end
    end
    
    if choice == 1 then -- Select All
        local all_ids = {
            1536, 1614, 1561, 1832, 1783, 1658, 1852, 1760, 1854, 1696, 
            1537, 1559, 1654, 1612, 1571, 1660, 1656, 1646, 1762, 1644, 
            1874, 1876
        }
        for _, id in ipairs(all_ids) do
            request_upgrade(id)
        end
        gg.toast("تم تفعيل الكل")
    elseif choice == 24 then
        return
    else
        -- Map choice index to ID (choice 2 is index 1 in our list, etc.)
        local ids = {
            1536, 1614, 1561, 1832, 1783, 1658, 1852, 1760, 1854, 1696, 
            1537, 1559, 1654, 1612, 1571, 1660, 1656, 1646, 1762, 1644, 
            1874, 1876
        }
        local selected_id = ids[choice - 1]
        if selected_id then
            request_upgrade(selected_id)
            gg.toast("تم الطلب: " .. menu[choice])
        end
    end
    
    return neighbor_requests_menu()
end
-- إعلان مسبق للجدول حتى تكون كل دوال البحث مرتبطة بنفس المرجع المحلي.
local all_codes_db


function yellow_repository_search()
    local search_input = gg.prompt(
        {"\n🔍 مستودع الأكواد (الشراء بالأصفر)\nأدخل اسم المنتج (أو جزء منه) للبحث وإضافته للشراء بالأصفر:"}, 
        {""}, 
        {"text"}
    )
    if not search_input or search_input[1] == "" then return end
    
    local query = search_input[1]:match("^%s*(.-)%s*$")
    if query == "" then
        gg.alert("الرجاء إدخال كلمة للبحث!")
        return yellow_repository_search()
    end
    
    local results = {}
    local count = 0
    for name, code in pairs(all_codes_db) do
        if string.find(name, query, 1, true) or string.find(code, query, 1, true) then
            results[name .. " [" .. code .. "]"] = code
            count = count + 1
        end
    end
    
    if count == 0 then
        local try_again = gg.choice({"🔄 حاول مرة أخرى", "🔙 رجوع"}, nil, "❌ لم يتم العثور على أي عنصر يحتوي على: " .. query)
        if try_again == 1 then return yellow_repository_search() end
    else
        gg.toast("✅ تم العثور على " .. count .. " نتائج! جاري التحويل لقائمة الشراء...")
        action(results, {allow_back_to_search = true})
    end
end

function yellow_menu()
    local menu = {
        "📂 『تحصيل (Collection)』",
        "📂 『اسماك (Fishes)』",
        "📂 『خشب ومتفجرات (Wood & Exp)』",
        "📂 『شحن (Cargo)』",
        "📂 『مطورات (Upgrades)』",
        "📂 『منوعات (Misc/Others)』",
        "📂 『تجميل (Beauty)』",
        "🔍 『مستودع الأكواد (Codes)』",
        "⬅️ 『 رجوع 』"
    }

    local choice = gg.choice(menu, nil, "الشراء بالأصفر ")
    if choice == nil then return end

    if choice == 1 then action(th) end
    if choice == 2 then action(fishes) end
    if choice == 3 then action(khshb) end
    if choice == 4 then action(shhn) end
    if choice == 5 then action(mtwer) end
    if choice == 6 then action(gthera) end
    if choice == 7 then action(tgmil) end
    if choice == 8 then yellow_repository_search() end
    if choice == 9 then return end
    
    return yellow_menu()
end

all_codes_db = {
     ["ذرة"] = "13",
    ["طماطم"] = "14",
    ["برسيم"] = "15",
    ["قمح"] = "16",
    ["حليب"] = "17",
    ["طحين"] = "18",
    ["كاتشب"] = "19",
    ["جبن الشيدر"] = "20",
    ["بيض"] = "21",
    ["جزر"] = "33",
    ["فرو أنغورا"] = "35",
    ["صوف"] = "37",
    ["عنب"] = "42",
    ["عصير عنب معتق"] = "44",
    ["عسل"] = "46",
    ["تفاح"] = "49",
    ["برتقال"] = "58",
    ["الكرز"] = "60",
    ["مربى عنب"] = "62",
    ["مربى تفاح"] = "63",
    ["مربى برتقال"] = "64",
    ["مربى كرز"] = "65",
    ["خبز"] = "71",
    ["ملابس صوفية"] = "79",
    ["سترة انغورا"] = "80",
    ["موز"] = "82",
    ["عنّاب"] = "84",
    ["التوت الشامي"] = "86",
    ["توت بري"] = "88",
    ["مربى عنّاب"] = "89",
    ["مربى التوت الشامي"] = "90",
    ["مربى توت بري"] = "91",
    ["فراولة"] = "133",
    ["مربى الفراولة"] = "134",
    ["بطاطا"] = "148",
    ["خس"] = "150",
    ["فلفل أحمر"] = "152",
    ["يقطين"] = "154",
    ["جزر مغلف"] = "156",
    ["خس مغلف"] = "157",
    ["فلفل مغلف"] = "158",
    ["بطاطا مغلفة"] = "159",
    ["حجر طيني"] = "1901",
    ["كوارتز"] = "1902",
    ["خام نحاسي"] = "1903",
    ["خام حديد"] = "1904",
    ["خام فضي"] = "1905",
    ["خام ذهبي"] = "1907",
    ["الألماس الهائج"] = "1908",
    ["ملح البارود"] = "1909",
    ["تاج ذهبي"] = "3034",
    ["مربى البطيخ"] = "4008",
    ["مربى اناناس"] = "4009",
    ["بطيخ"] = "4010",
    ["اناناس"] = "4011",
    ["زنبق"] = "5002",
    ["توليب"] = "5004",
    ["ورد احمر"] = "5006",
    ["ورد ازرق"] = "5008",
    ["ورد ابيض"] = "5010",
    ["ريش الطاووس"] = "6002",
    ["أرز"] = "6004",
    ["طحين الأرز"] = "6005",
    ["عنبية حادة"] = "7001",
    ["كوسا"] = "7003",
    ["غرسة الشاي"] = "7013",
    ["أناناولة"] = "7015",
    ["قمح بري"] = "7017",
    ["الكاسافا"] = "7019",
    ["بابونج"] = "7021",
    ["زهر العسل"] = "7023",
    ["برسيم حجازي"] = "7025",
    ["كتان"] = "7027",
    ["زهرة البنفسج"] = "7029",
    ["صبار"] = "7031",
    ["شمام"] = "7033",
    ["نبات الكريمة"] = "7035",
    ["طحالب حمراء"] = "7037",
    ["ورق الزنبق"] = "7039",
    ["حشيش البحر"] = "7041",
    ["زهرة ندفه الثلج"] = "7043",
    ["زهرة الفقاعات"] = "7045",
    ["بوط"] = "7047",
    ["بندورة"] = "7049",
    ["نبات عشبي"] = "7053",
    ["باشن فروت"] = "7055",
    ["الهندباء"] = "7057",
    ["زهرة البالون"] = "7059",
    ["بسكويت أوريو"] = "7061",
    ["فطر الشبح"] = "7063",
    ["قصبة الخيزران الصغيرة"] = "7065",
    ["ريشة الديك"] = "7067",
    ["رجل الثلج"] = "7069",
    ["جرس الكريسماس"] = "7071",
    ["خردل"] = "7073",
    ["الفجل"] = "7075",
    ["زنجبيل"] = "7077",
    ["بامية"] = "7079",
    ["كرفس"] = "7081",
    ["حلوى الهيكل العظمي"] = "7083",
    ["توفي التفاح"] = "7085",
    ["نجمة الحظ"] = "7087",
    ["مفرقع المهرجان"] = "7089",
    ["ورقة حلوة"] = "7091",
    ["الكيوي الذهبي"] = "7093",
    ["صبارة"] = "7095",
    ["الكراث"] = "7097",
    ["كريمة الذكرى السنوية التاسعة"] = "7099",
    ["فاكهة الشر"] = "7101",
    ["فاكهة فرانكشتاين"] = "7103",
    ["ألوي فيرا"] = "7105",
    ["ندفة الثلج"] = "7107",
    ["فلفل جالابينو"] = "7109",
    ["حبوب الكاكاو"] = "7111",
    ["فاكهة التنين الصفراء"] = "7113",
    ["كركديه"] = "7115",
    ["زيليتول"] = "7117",
    ["توت عرعر خارق"] = "7119",
    ["سلة حلوى الهالوين"] = "7121",
    ["زهرة الأشباح المقدسة"] = "7123",
    ["زنبق النهار"] = "7125",
    ["زنبق الوادي"] = "7127",
    ["التين الشوكي"] = "7129",
    ["إجاص الأرض"] = "7131",
    ["يقطين الشبح اللطيف"] = "7133",
    ["هندباء الشبيه بالخفاش"] = "7135",
    ["برعم العقدة"] = "7137",
    ["لوبياء العين السوداء"] = "7139",
    ["خبز الموتشي"] = "7141",
    ["الشمام الإجاصي"] = "7143",
    ["زهرة شمعة السنة الجديدة"] = "7145",
    ["ثروة البرتقال"] = "7147",
    ["كستناء"] = "8003",
    ["قصبة الخيزران"] = "8005",
    ["اوراق شجرة الشاي"] = "8007",
    ["اوراق التوت"] = "8009",
    ["خشب البلوط"] = "8013",
    ["خشب الأَرز"] = "8017",
    ["خشب ساندرز"] = "8021",
    ["مطاط"] = "8023",
    ["فاكهة دوريان"] = "8025",
    ["الويفر"] = "8029",
    ["مانغوستين"] = "8031",
    ["بشملة"] = "8033",
    ["جرعة الساحرة"] = "8035",
    ["مصابيح الإضاءة"] = "8037",
    ["واكسبيري"] = "8039",
    ["حلوى اليقطين"] = "8041",
    ["رقائق الشوكولاتة"] = "8043",
    ["كأس زبدة فول السوداني"] = "8045",
    ["حليب البروبيوتيك"] = "8047",
    ["براوني"] = "8049",
    ["الكريستال السحري"] = "8051",
    ["نوتة موسيقية"] = "8053",
    ["عنب الثعلب الهندي"] = "8055",
    ["الكرة الكريستالية"] = "8057",
    ["عملة النجوم"] = "8059",
    ["فاكهة الأبيو"] = "8061",
    ["فاكهة أمنية قوس قزح"] = "8063",
    ["فاكهة زفيزف"] = "8065",
    ["فطيرة التفاح"] = "9002",
    ["فطيرة العناب"] = "9003",
    ["فطيرة فراولة"] = "9004",
    ["إجاص"] = "9006",
    ["خوخ"] = "9008",
    ["جوز الهند"] = "9102",
    ["فطيرة موز"] = "9103",
    ["فطيرة اليقطين"] = "9104",
    ["باقة ورود زرقاء"] = "9106",
    ["باقة ورود حمراء"] = "9107",
    ["باقة ورود بيضاء"] = "9108",
    ["باقة توليب"] = "9109",
    ["باقة زنبق"] = "9110",
    ["فطر"] = "9116",
    ["اقحوان"] = "9118",
    ["بصل"] = "9120",
    ["عباد الشمس"] = "9122",
    ["بطاطا حلوة"] = "9124",
    ["فطيرة عنيبة حادة"] = "9125",
    ["الشوكولاتة"] = "9410",
    ["ثمرة الحب"] = "9412",
    ["لحم الخنزير"] = "9503",
    ["فطيرة اجاص"] = "9700",
    ["فطيرة خوخ"] = "9701",
    ["فطيرة ثمرة الحب"] = "9702",
    ["فطيرة الشوكولاتة"] = "9703",
    ["باقة اقحوان"] = "9704",
    ["باقة عباد الشمس"] = "9705",
    ["فطر مغلف"] = "9706",
    ["بصل مغلف"] = "9707",
    ["باقة الهندباء"] = "9708",
    ["باقة حلوى الهيكل العظمي"] = "9709",
    ["باقة الأشباح المقدسة"] = "9710",
    ["طحين دابُوق"] = "11001",
    ["طحين شعير"] = "11002",
    ["طحين الكاسافا"] = "11003",
    ["طحين الكستناء"] = "11004",
    ["خبز الزبيب"] = "11101",
    ["خبز الثوم"] = "11103",
    ["خبز الكوسا"] = "11104",
    ["خبز عنبية حادة"] = "11105",
    ["خبز بالقرفة"] = "11106",
    ["خبز الفراولة"] = "11107",
    ["خبز الكيوي"] = "11108",
    ["خبز أناناولة"] = "11109",
    ["خبز الكاكايا"] = "11110",
    ["خبز غرسة الشاي"] = "11111",
    ["زيت شاي مركز"] = "11201",
    ["زيت اللافندر مركز"] = "11202",
    ["زيت اقحوان مركز"] = "11203",
    ["زيت بابونج مركز"] = "11204",
    ["زيت ورد احمر مركز"] = "11205",
    ["زيت ورد أزرق مركز"] = "11206",
    ["زيت زهرة العسل مركز"] = "11207",
    ["زيت توليب مركز"] = "11208",
    ["زيت زنبق مركز"] = "11209",
    ["زيت زهرة البنفسج مركز"] = "11210",
    ["زيت زهرة عباد الشمس مركز"] = "11211",
    ["زيت النرجس البري المركز"] = "11212",
    ["زيت زهرة السوسن المركز"] = "11213",
    ["شاي بالليمون"] = "11402",
    ["شاي بالعنبية الحادة"] = "11404",
    ["شاي بابونج"] = "11405",
    ["شاي البيلسان"] = "11406",
    ["شاي مثلج"] = "11407",
    ["شاي زهرة العسل"] = "11408",
    ["عنبية حادة مجففة"] = "11501",
    ["زبيب مجفف"] = "11502",
    ["كوسا مجففة"] = "11503",
    ["كاكايا مجفف"] = "11504",
    ["كيوي مجفف"] = "11505",
    ["ليمون مجفف"] = "11506",
    ["أناناولة مجففة"] = "11507",
    ["فراولة مجففة"] = "11508",
    ["موز مجفف"] = "11509",
    ["غزل موهير"] = "11601",
    ["غزل فرو أنغورا"] = "11602",
    ["غزل صوف"] = "11603",
    ["غزل صوف ألبكة"] = "11604",
    ["غزل شعر حصان"] = "11605",
    ["غزل وبر الجمل"] = "11606",
    ["قماش الكتّان"] = "11701",
    ["حرير"] = "11702",
    ["لباس قطني"] = "11703",
    ["قماش صوف الأنغورا"] = "11704",
    ["قماش صوف الألبكة"] = "11705",
    ["سلة بابونج"] = "11801",
    ["سلة زنبق"] = "11802",
    ["سلة ورد ابيض"] = "11803",
    ["سلة زهرة العسل"] = "11804",
    ["سلة الياسمين"] = "11805",
    ["سلة زهرة البنفسج"] = "11806",
    ["سلة الوردة الوردية"] = "11807",
    ["فول"] = "20001",
    ["لحم غزال"] = "20004",
    ["فول سوداني"] = "20006",
    ["زيتون"] = "20008",
    ["زيت فول سوداني"] = "20010",
    ["زيت الزيتون"] = "20011",
    ["زيت الفول"] = "20012",
    ["سجق لحم غزال"] = "20015",
    ["باذنجان"] = "20021",
    ["كرات القطن"] = "20023",
    ["قرنبيط"] = "20025",
    ["حبوب القهوة"] = "20027",
    ["عشب"] = "20029",
    ["شرحات خنزير"] = "20033",
    ["شرحات غزال"] = "20034",
    ["حليب ماعز"] = "20040",
    ["قهوة موكا"] = "20046",
    ["وبر الجمل"] = "20064",
    ["لبن بالفراولة"] = "20069",
    ["لبن بالخوخ"] = "20070",
    ["لبن بالأناناس"] = "20071",
    ["لبن بالتوت الشامي"] = "20073",
    ["لبن بالعناب"] = "20074",
    ["لبن الشوكولاتة"] = "20077",
    ["لبن بالبطيخ"] = "20078",
    ["جبن ماعز"] = "20082",
    ["جبن جمل"] = "20083",
    ["سترة الجمل"] = "20084",
    ["بيتزا الباذنجان"] = "20091",
    ["بيتزا البصل"] = "20092",
    ["بيتزا الفطر"] = "20093",
    ["بيتزا الفلفل الاحمر"] = "20094",
    ["بيتزا بالكوسا"] = "20095",
    ["بيتزا بالاناناس"] = "20096",
    ["تمر"] = "20103",
    ["زيت التمر"] = "20104",
    ["شعير"] = "20106",
    ["حشيشة الدينار"] = "20108",
    ["شراب ميونيخ"] = "20110",
    ["برلين"] = "20111",
    ["لحم"] = "20115",
    ["لحم مشوي"] = "20116",
    ["قصب السكر"] = "20122",
    ["سكر"] = "20124",
    ["مسحوق ستيفيا"] = "20125",
    ["صوف ألبكة"] = "20127",
    ["كريستال زيليتول"] = "20128",
    ["همبرغر لحم بقر"] = "20138",
    ["ريش النعام"] = "20144",
    ["ديك رومي"] = "20145",
    ["اللوز"] = "20152",
    ["ليمون"] = "20154",
    ["مانجا"] = "20156",
    ["سترة صوف ألبكة"] = "20162",
    ["ديك رومي مشوي"] = "20163",
    ["جمبري مشوي"] = "20166",
    ["ثوم مشوي"] = "20167",
    ["فطر مشوي"] = "20168",
    ["بطاطا مشوية"] = "20169",
    ["باذنجان مشوي"] = "20170",
    ["حلوى العنب"] = "20191",
    ["حلوى الفراولة"] = "20192",
    ["حلوى التفاح"] = "20194",
    ["حليب بودرة"] = "22001",
    ["جبن زرقاء"] = "22002",
    ["حليب قليل الدسم"] = "22003",
    ["حليب معقم"] = "22004",
    ["جبن قليله الدسم"] = "22005",
    ["الموزاريلا"] = "22006",
    ["جبن الخفاش"] = "22007",
    ["طحين فاصوليا خضراء"] = "22009",
    ["طحين اللوز"] = "22010",
    ["بيض ابيض"] = "22021",
    ["بيض عربي"] = "22022",
    ["بيض احمر"] = "22023",
    ["علف"] = "22024",
    ["ريش دجاج"] = "22025",
    ["مربى فاكهة الحب"] = "22026",
    ["مربى القرفة"] = "22027",
    ["مربى رامبوتان"] = "22028",
    ["مهلبية شامية"] = "22029",
    ["مربى تفاح سوري"] = "22030",
    ["عصير البطيخ"] = "22031",
    ["عصير جوز الهند"] = "22032",
    ["عصير كرز سوريناني"] = "22033",
    ["طبق فواكه"] = "22034",
    ["فرو أنغورا بني"] = "22035",
    ["كرة فرو أنغورا"] = "22036",
    ["فرو انغورا مخمل"] = "22037",
    ["جزر بلاستيك"] = "22038",
    ["برغر لحم غزال"] = "22039",
    ["برغر المفلطحة"] = "22040",
    ["برغر صغير"] = "22042",
    ["عصير الورد"] = "22043",
    ["كوكتيل قوس قزح"] = "22044",
    ["عصير فرنسي"] = "22046",
    ["صلصة البصل"] = "22047",
    ["صلصة الفول"] = "22048",
    ["صلصه ميكس"] = "22050",
    ["سكر تمر"] = "22051",
    ["مالتوز"] = "22052",
    ["دبس سكر"] = "22054",
    ["شعر الغزال"] = "22055",
    ["القرون الناعمة"] = "22056",
    ["لحم غزال اللهب"] = "22057",
    ["دمية الغزال"] = "22058",
    ["حلوى الشوكولاتة"] = "22059",
    ["حلوى الماتشا"] = "22060",
    ["حلوى بذور الخوخ"] = "22061",
    ["مصاصة"] = "22062",
    ["خبز جوز الهند"] = "22063",
    ["خبز التوت البري"] = "22064",
    ["خبز الأناناس"] = "22065",
    ["خبز فرنسي"] = "22066",
    ["لحم مجفف"] = "22067",
    ["شرائح لحم فرنسي"] = "22068",
    ["الفيليه الفرنسي"] = "22069",
    ["جلد ثور فرنسي"] = "22070",
    ["باقة زهرة السوسن"] = "22071",
    ["باقة زهرة دمية دب"] = "22072",
    ["باقة السرخس"] = "22073",
    ["باقة زهور مجففة"] = "22074",
    ["لباد الصوف"] = "22075",
    ["دهن الصوف"] = "22076",
    ["صوف ناعم"] = "22077",
    ["جلد رقيق"] = "22078",
    ["إكسسوار شعر ريشة الطاووس"] = "22079",
    ["صبغ أزرق"] = "22080",
    ["ريشة طاووس أبيض"] = "22081",
    ["ريشة طاووس أسود"] = "22082",
    ["مربى كركديه"] = "22083",
    ["عصير فاكهة التنين الصفراء"] = "22084",
    ["لحم نعامة سوداء"] = "22085",
    ["زيت النعامة"] = "22086",
    ["قفازات نعامة سوداء"] = "22087",
    ["جلد نعامة سوداء"] = "22088",
    ["قفازات ديك رومي أبيض"] = "22089",
    ["وشاح ريشة ديك رومي أبيض"] = "22090",
    ["لفافة ديك رومي أبيض"] = "22091",
    ["ديك رومي أبيض مقدد"] = "22092",
    ["مربى التين الشوكي"] = "22093",
    ["دمية الإوزة"] = "22094",
    ["دمية النعامة السوداء"] = "22095",
    ["دمية ديك رومي أبيض"] = "22096",
    ["دمية خالد"] = "22097",
    ["بسطرمة بالذرة"] = "22098",
    ["بسطرمة الحبار"] = "22099",
    ["بسطرمة نباتية"] = "22100",
    ["بسطرمة لحم"] = "22101",
    ["كعكة خبز الموتشي"] = "22110",
    ["خبز الشمام الإجاصي"] = "22111",
    ["كيس حلوى"] = "30026",
    ["اللافندر"] = "30073",
    ["سجق البقر"] = "30095",
    ["كعكة الشوكلاته بالكرز"] = "30097",
    ["كعكة اللوز"] = "30098",
    ["كعكة الليمون"] = "30099",
    ["كعكة جوز الهند"] = "30100",
    ["كرز شامي"] = "30102",
    ["عسل فرنسي"] = "30109",
    ["خيار"] = "30128",
    ["حليب جاموس"] = "30130",
    ["جبن الجاموس"] = "30131",
    ["ريش إوز"] = "30134",
    ["لحم هوت دوج"] = "30142",
    ["زهرة لوتس"] = "30146",
    ["عطر زهرة السوسن"] = "30190",
    ["عطر الزهرة الوردية"] = "30191",
    ["بالونات"] = "30202",
    ["خيام صغيرة"] = "30203",
    ["قبعة تخييم"] = "30204",
    ["دولاب سباحة"] = "30205",
    ["شبكة صيد فراشات"] = "30206",
    ["مزمار"] = "30207",
    ["دليل التخييم"] = "30208",
    ["تذكرة"] = "30209",
    ["صافرات"] = "30210",
    ["ذكرى"] = "30211",
    ["التعليقات"] = "30212",
    ["لعبة منفوخة"] = "30213",
    ["كرت"] = "30214",
    ["بخاخ البنادق"] = "30215",
    ["كريم للشمس"] = "30216",
    ["قبعة"] = "30217",
    ["شبشب"] = "30218",
    ["خل ابيض"] = "30221",
    ["ملفوف الكيمتشي"] = "30223",
    ["الكيمتشي الخيار"] = "30224",
    ["كيمتشي لوبياء العين السوداء"] = "30231",
    ["كيمتشي قصبة الخيزران الصغيرة"] = "30232",
    ["كيمتشي الكرفس"] = "30233",
    ["ملح"] = "30302",
    ["اللوت الصفراء المدخن"] = "30303",
    ["ريبونفيش المدخن"] = "30304",
    ["البلطى المدخن"] = "30305",
    ["المفلطحة المدخن"] = "30306",
    ["سمك الزبيدي المدخن"] = "30307",
    ["الرنكة المدخنة"] = "30308",
    ["سمكة الاسد المدخنة"] = "30309",
    ["السردين المدخن"] = "30310",
    ["السلمون المدخن"] = "30311",
    ["الماكريل المدخن"] = "30312",
    ["سمك الصوري مدخن"] = "30313",
    ["سمك قد مدخن"] = "30314",
    ["تونا مدخن"] = "30315",
    ["الإسكالوب المجفف"] = "31005",
    ["القوقع"] = "31006",
    ["حلزون البحر"] = "31007",
    ["لحم جمبرى"] = "31008",
    ["جمبري السرعوف على البخار"] = "31009",
    ["جمبري ابوسوم على البخار"] = "31010",
    ["سلطعون الطين على البخار"] = "31011",
    ["سلطعون على البخار"] = "31012",
    ["سلطعون الضفدع الأحمر المطبوخ"] = "31013",
    ["بودر المرجان"] = "31014",
    ["نجم البحر المجفف"] = "31015",
    ["قنديل البحر المملح"] = "31016",
    ["لحم الأخطبوط"] = "31017",
    ["مسحوق الطحالب"] = "31018",
    ["اعشاب بحرية مطبوخة"] = "31019",
    ["طحالب بحرية جافة"] = "31020",
    ["خس البحر المطبوخ"] = "31021",
    ["لؤلؤ"] = "31022",
    ["قوقعة حلزون البحر"] = "31023",
    ["كرات الجمبري"] = "31024",
    ["ستيك سلطعون"] = "31025",
    ["بطارخ سلطعون"] = "31026",
    ["غصن مرجان"] = "31027",
    ["بيض نجم البحر"] = "31028",
    ["رأس قنديل البحر"] = "31029",
    ["مفرقعة الحبر"] = "31030",
    ["صلصال الطحالب"] = "31031",
    ["شرائح مرجان"] = "31032",
    ["صدف أذن البحر"] = "31033",
    ["جمبري ضخم على البخار"] = "31034",
    ["سلطعون مثلج على البخار"] = "31035",
    ["سلطعون لازق"] = "31036",
    ["قلادة حمراء"] = "32010",
    ["قلادة القوقع"] = "32011",
    ["قلادة اللؤلؤ"] = "32012",
    ["قرط الآذن القوقع"] = "32013",
    ["قرط الآذن ريشة الطاووس"] = "32014",
    ["قرط الآذن ريشة الإوز"] = "32015",
    ["قناع الوجه بالطين"] = "32016",
    ["قناع الوجه بالأعشاب البحرية"] = "32017",
    ["قناع الوجه بالشوفان"] = "32018",
    ["قناع الوجه بالورد"] = "32019",
    ["قناع الوجه بالحليب"] = "32020",
    ["قناع الوجه بالمايونيز"] = "32021",
    ["قناع الوجه بالليمون"] = "32022",
    ["قناع الوجه المرجاني"] = "32023",
    ["قناع الوجه بالموز"] = "32024",
    ["مرآة على شكل قنديل البحر"] = "32025",
    ["مرآة ورد مرجاني"] = "32026",
    ["مرآة اللؤلؤ"] = "32027",
    ["زجاجة أرِيج شجرة الشاي"] = "32028",
    ["زجاجة أرِيج لافندر"] = "32029",
    ["زجاجة أريج بابونج"] = "32030",
    ["زجاجة أرِيج  زهرة العسل"] = "32031",
    ["زجاجة أرِيج الزنبق"] = "32032",
    ["زجاجة أريج زهرة البنفسج"] = "32033",
    ["زجاج"] = "32901",
    ["ماء مقطر"] = "32902",
    ["قرط آذن على شكل خطاف"] = "32903",
    ["بيض البط"] = "40009",
    ["لبن بالزبيب"] = "40068",
    ["لبن الكيوي"] = "40069",
    ["لبن عنبية حادة"] = "40080",
    ["فرو الرنة"] = "41001",
    ["موهير"] = "41025",
    ["سلة الخيزران"] = "41029",
    ["حرير طبيعي"] = "41031",
    ["شعر سنجاب"] = "41033",
    ["ريش ببغاء"] = "41035",
    ["بيض طائر السمان"] = "41037",
    ["صلصال"] = "41039",
    ["جوز الهند اليافع"] = "41041",
    ["قنفذ البحر"] = "41045",
    ["ريش نورس ميو"] = "41047",
    ["الحبار"] = "41049",
    ["العملاق الازرق"] = "41051",
    ["لحم ضأن"] = "41053",
    ["بيضة القرن"] = "41055",
    ["ريش مهرجان النحام الوردي"] = "41057",
    ["شعر كابياء"] = "41059",
    ["قصبة الخيزران النظيفة"] = "41061",
    ["عصير الكافور"] = "41063",
    ["حليب الكركدن"] = "41069",
    ["شعر ماشية الهايلاند"] = "41071",
    ["حليب غزال المحظوظ"] = "41073",
    ["طبعة حمار الوحش"] = "41075",
    ["ريشة البجعة"] = "41077",
    ["قدم ديك الرومي"] = "41079",
    ["ريشة يونيكورن"] = "41081",
    ["ريشة فينكس"] = "41083",
    ["مخمل رنة الاحتفال"] = "41085",
    ["شعر حصان عيد الحب"] = "41087",
    ["زيت سمك أعماق البحار"] = "41091",
    ["ذيل ثعلب الحظ"] = "41093",
    ["صوف ألبكة الوردية"] = "41095",
    ["سمكة مجمدة"] = "41097",
    ["وسادة الباندا الحمراء"] = "41099",
    ["نقشة نمر روح ساكورا"] = "41101",
    ["وسادة قضاعة البحر"] = "41103",
    ["الكركدن المنحوت"] = "41105",
    ["وسادة رقبة الفيل"] = "41107",
    ["حقيبة هدية الكريسماس"] = "41109",
    ["حلوى قصب الكريسماس"] = "41111",
    ["ريشة على شكل قلب"] = "41113",
    ["صوف متعدد الألوان"] = "41115",
    ["الريشة الملكية الجليدية"] = "41117",
    ["زهرة قلب زهري"] = "41119",
    ["فرو كابيبارا"] = "41121",
    ["جيلي حليب ملح البحر"] = "41123",
    ["ريشة بومة الساحرة"] = "41125",
    ["قلب كريستالي مزخرف بالريش"] = "41127",
    ["شعر الحصان"] = "52002",
    ["سجق لحم الخنزير"] = "52003",
    ["فطيرة التوت البري"] = "52004",
    ["شاي معبأ"] = "52005",
    ["هوت دوج لحم خنزير"] = "52006",
    ["علبة فول"] = "52007",
    ["علبة كرز"] = "52008",
    ["علبة عنب"] = "52009",
    ["علبة مانجا"] = "52010",
    ["علبة زيتون"] = "52011",
    ["علبة برتقال"] = "52012",
    ["علبة خوخ"] = "52013",
    ["علبة أناناس"] = "52014",
    ["علبة بطاطا"] = "52015",
    ["بيتزا السجق الإيطالية"] = "52016",
    ["بيتزا الفطر الإيطالية"] = "52017",
    ["بيتزا الفلفل الإيطالية"] = "52018",
    ["بيتزا الباذنجان الإيطالية"] = "52019",
    ["بيتزا الزيتون الإيطالية "] = "52020",
    ["بيتزا الأناناس الإيطالية"] = "52021",
    ["بيتزا البصل الإيطالية"] = "52022",
    ["بيتزا الذرة الإيطالية "] = "52023",
    ["زبدة الأناناس"] = "52024",
    ["زبدة العناب"] = "52025",
    ["زبدة التوت الشامي"] = "52026",
    ["زبدة الفراولة"] = "52027",
    ["ليتشي"] = "55006",
    ["نخالة"] = "65003",
    ["طحين النخالة"] = "65004",
    ["خبز النخالة"] = "65005",
    ["خبز الذرة"] = "65006",
    ["شجاع"] = "65007",
    ["شوكولاتة بيضاء"] = "65009",
    ["موكا بيضاء"] = "65010",
    ["قهوة بالكريمة"] = "65011",
    ["حلوى ليتشي"] = "65012",
    ["هوت دوج تركي"] = "65013",
    ["بسطرمة الديك الرومي"] = "65014",
    ["زبدة فول السوداني"] = "65015",
    ["حلوى التيراميسو"] = "65016",
    ["كعكة الحب"] = "65017",
    ["قميص بولو"] = "65018",
    ["كعكة أوريو"] = "65019",
    ["لحم غزال هوت دوغ"] = "65021",
    ["قهوة قيقب"] = "65022",
    ["قهوة هاواي"] = "65023",
    ["قهوة الكرز"] = "65024",
    ["كعكة فرانكشتاين"] = "65025",
    ["كعكة ندفة الثلج"] = "65026",
    ["كعكة مخملية حمراء"] = "65027",
    ["كعكة إجاص الأرض"] = "65028",
    ["كعكة القهوة بالقرفة"] = "65029",
    ["بوظة بنكهة التفاح"] = "100258",
    ["بوظة بنكهة العنب"] = "100259",
    ["بوظة بنكهة الموز"] = "100260",
    ["بوظة بنكهة الفراولة"] = "100261",
    ["بوظة بنكهة الليمون"] = "100262",
    ["بوظة بنكهة المانجا"] = "100263",
    ["بوظة بنكهة المشمش"] = "100264",
    ["بوظة بنكهة البرقوق"] = "100265",
    ["بوظة بنكهة جوز الهند"] = "100266",
    ["بوظة بنكهة الخوخ"] = "100267",
    ["بوظة بنكهة اجاص"] = "100268",
    ["قشطة"] = "101114",
    ["العنب الأخضر"] = "200002",
    ["عصير العنب الأخضر"] = "200003",
    ["فاكهة تنين"] = "200008",
    ["مربى فاكهة التنين"] = "200009",
    ["غيتار"] = "200012",
    ["كمان"] = "200013",
    ["الطنبور آلة موسيقية"] = "200014",
    ["قاروس"] = "200015",
    ["طبل"] = "200016",
    ["البانجو"] = "200017",
    ["بطاقة"] = "200018",
    ["كأس"] = "200020",
    ["صندوق الكعك"] = "200022",
    ["محرمة"] = "200023",
    ["كاميرا"] = "200024",
    ["مشبك الشعر"] = "200025",
    ["حزم معدنية"] = "200026",
    ["فانوس"] = "200100",
    ["أرومة الشجرة"] = "200102",
    ["طبق"] = "200103",
    ["كرسي"] = "200104",
    ["أدوات المائدة"] = "200105",
    ["مغرفة الحساء"] = "200106",
    ["اكواب"] = "200107",
    ["ملقعة"] = "200108",
    ["شوكة"] = "200109",
    ["وردة وردية"] = "200228",
    ["باقة وردة وردية"] = "200231",
    ["قرفة"] = "200234",
    ["نعناع"] = "200236",
    ["شاي بالقرفة"] = "200237",
    ["شاي مغربي بالنعناع"] = "200238",
    ["شاي محلى"] = "200239",
    ["شاي بالعسل"] = "200240",
    ["شاي بالحليب"] = "200241",
    ["سترة مُجَعَّدة"] = "200247",
    ["قرنفل"] = "200301",
    ["معطف مطري"] = "200317",
    ["مصباح يدوي"] = "200318",
    ["منديل ورقي"] = "200320",
    ["قبعة ريش الطاووس"] = "200328",
    ["قبعة ريش الإوز"] = "200329",
    ["قبعة ريش النعام"] = "200330",
    ["قبعة طفل"] = "200331",
    ["قبّعة"] = "200332",
    ["اللهاية"] = "200333",
    ["إبريق الشاي"] = "200334",
    ["نكاشة اسنان"] = "200335",
    ["قبعة القرصان"] = "200336",
    ["باقة اللافندر"] = "200338",
    ["كعكة الموز"] = "200339",
    ["فاكهة الكيوي"] = "200342",
    ["مربى الكيوي"] = "200343",
    ["المشمش"] = "200346",
    ["فطيرة المشمش"] = "200347",
    ["فانيلا"] = "200356",
    ["فوشار بنكهة الشوكولاتة"] = "200359",
    ["فوشار بالسكر"] = "200360",
    ["طعام سمك خارق"] = "200361",
    ["بوظة الفانيلا"] = "200365",
    ["زيت عباد الشمس"] = "200405",
    ["الشوفان"] = "200423",
    ["بسكويت بالشوكولاتة البيضاء"] = "200427",
    ["بسكويت بالشوفان"] = "200428",
    ["بسكويت بالزبيب"] = "200429",
    ["باقة القرنفل"] = "200436",
    ["المايونيز"] = "200437",
    ["صلصة حارة"] = "200438",
    ["طحين الشوفان"] = "200444",
    ["خبز الشوفان"] = "200445",
    ["بطاطا مقلية بالكاتشب"] = "200449",
    ["بطاطا مقلية بالمايونيز"] = "200450",
    ["بطاطا مقلية بالفلفل الحار"] = "200451",
    ["مشروب الجن"] = "200454",
    ["مشروب آكاف"] = "200455",
    ["مربى صبارة"] = "200456",
    ["عنب لبناني"] = "200458",
    ["عصير عنب لبناني"] = "200459",
    ["مشروب الكيوي الذهبي"] = "200460",
    ["عصير العنب"] = "200466",
    ["عصير تفاح"] = "200467",
    ["عصير برتقال"] = "200468",
    ["عصير مانجا"] = "200469",
    ["حاوية الفواكه"] = "200470",
    ["وعاء السلطة"] = "200471",
    ["بهلواني"] = "200472",
    ["كرة قدم"] = "200473",
    ["قالب"] = "200474",
    ["صندوق القبعة"] = "200475",
    ["سترة"] = "200476",
    ["عصير عنب حلوى الهالوين"] = "200477",
    ["بطاقات أونو"] = "200485",
    ["عصير الكرز"] = "200488",
    ["عصير فراولة"] = "200489",
    ["عصير الكرفس"] = "200490",
    ["عصير فاكهة الشر"] = "200491",
    ["عصير ألوي فيرا"] = "200492",
    ["ثوم"] = "200521",
    ["زبدة الثوم"] = "200523",
    ["شاي بالزنجبيل"] = "200526",
    ["شمندر سكري"] = "200528",
    ["كراميل"] = "200529",
    ["فوشار كراميل"] = "200530",
    ["فوشار زبدة فول سوداني"] = "200531",
    ["شراب القيقب"] = "200534",
    ["سكر القيقب"] = "200535",
    ["شاي القيقب"] = "200536",
    ["سلطة خضراء"] = "200543",
    ["سلطة فول سوداني"] = "200544",
    ["سلطة الفول"] = "200545",
    ["سلطة السويسرية"] = "200546",
    ["سلطة فلفل أحمر"] = "200548",
    ["سلطة البصل"] = "200549",
    ["سلطة العربية"] = "200550",
    ["سلطة البطاطا"] = "200551",
    ["شوكولاتة الزبيب"] = "200570",
    ["شوكولاتة اللوز"] = "200571",
    ["شوكولاتة بالفول سوداني"] = "200572",
    ["شوكولاتة بالكرز"] = "200573",
    ["شوكولاتة بالموز"] = "200574",
    ["شوكولاتة بالتين"] = "200575",
    ["شوكولاتة بالمشمش"] = "200576",
    ["سوشي البيض"] = "200588",
    ["صلصة فول سوداني"] = "200652",
    ["صلصة اليقطين"] = "200653",
    ["صلصة خردل"] = "200654",
    ["صلصة البامية"] = "200655",
    ["صلصة فطر الشبح"] = "200656",
    ["صلصة الكراث"] = "200657",
    ["برغر اللحم"] = "200709",
    ["برغر الديك الرومي"] = "200710",
    ["برجر حار"] = "200711",
    ["كاجو"] = "200954",
    ["خبز اليقطين"] = "201101",
    ["باقة هندباء الشبيه بالخفاش"] = "201102",
    ["قهوة مارشميلو"] = "203001",
    ["مارشميلو بالاناناس"] = "203002",
    ["مارشميلو عناب"] = "203003",
    ["مارشميلو بالخوخ"] = "203004",
    ["مارشميلو توت بري"] = "203005",
    ["مارشميلو بالنعناع"] = "203006",
    ["مارشميلو قوس قزح"] = "203007",
    ["صابون غار"] = "203101",
    ["صابون بابونج"] = "203102",
    ["صابون ورد احمر"] = "203104",
    ["صابون بالعسل"] = "203105",
    ["صابون توليب"] = "203106",
    ["صابون عباد الشمس"] = "203107",
    ["صابون بنفسج"] = "203108",
    ["شبشب الببغاء"] = "203201",
    ["شبشب الفراشة"] = "203202",
    ["شبشب النرجس"] = "203203",
    ["شبشب الألبكة"] = "203205",
    ["شبشب فرو أنغورا"] = "203206",
    ["شبشب عباد الشمس"] = "203207",
    ["مصاصة شمام"] = "203301",
    ["مصاصة جوز الهند"] = "203302",
    ["مصاصة دوريان"] = "203303",
    ["مصاصة فانيليا"] = "203304",
    ["مصاصة الازوكي"] = "203305",
    ["مصاصة أناناولة"] = "203306",
    ["مصاصة ماتشا"] = "203307",
    ["مصاصة شوكلاته"] = "203308",
    ["سرخس ضوئي"] = "203401",
    ["لوتس ضوئي"] = "203402",
    ["مصباح وردة وردية"] = "203403",
    ["زهرة بيضاء ضوئية"] = "203404",
    ["نرجس ضوئي"] = "203405",
    ["زهر العسل ضوئي"] = "203406",
    ["بابونج ضوئي"] = "203407",
    ["ساشيمي سلمون"] = "203501",
    ["ساشيمي سكلوب"] = "203502",
    ["ساشيمي الأخطبوط"] = "203503",
    ["ساشيمي حبار"] = "203504",
    ["ساشيمي سلطعون"] = "203505",
    ["ساشيمي الماكريل"] = "203506",
    ["ساشيمي أورشين"] = "203507",
    ["ساشيمي قريدس"] = "203508",
    ["قارب الاوزة"] = "203601",
    ["قارب نعامة"] = "203602",
    ["قارب الطاووس"] = "203603",
    ["قارب الببغاء"] = "203604",
    ["قارب النورس ميو"] = "203605",
    ["قارب بط اصفر"] = "203606",
    ["فخار لافندر"] = "203701",
    ["فخار ورد احمر"] = "203702",
    ["فخار نرجس برّي"] = "203703",
    ["فخار زهرة ساكورا"] = "203704",
    ["فخار زهرة زيزفون"] = "203705",
    ["فخار توليب"] = "203706",
    ["جيلي جوز الهند"] = "203801",
    ["جيلي فراولة جوز الهند"] = "203802",
    ["جيلي فول سوداني جوز الهند"] = "203803",
    ["جيلي أناناولة جوز الهند"] = "203804",
    ["جيلي الازوكي بجوز الهند"] = "203805",
    ["جيلي ماتشا بجوز الهند"] = "203806",
    ["قميص الوردة الوردية"] = "203901",
    ["قميص الزهور الزرقاء"] = "203902",
    ["قميص الدب"] = "203903",
    ["قميص عباد الشمس"] = "203904",
    ["قميص الطحالب الحمراء"] = "203905",
    ["قميص زهرة الفقاعات"] = "203906",
    ["قميص الحبار"] = "203907",
    ["مظلة الكيوي"] = "204001",
    ["مظلة الشمام"] = "204002",
    ["مظلة البطيخ"] = "204003",
    ["مظلة فاكهة قوس قزح"] = "204004",
    ["مظلة المحار العملاقة"] = "204005",
    ["مظلة ندفة المياه"] = "204006",
    ["مظلة عشب الماء"] = "204007",
    ["مظلة قنفذ البحر"] = "204008",
    ["شطيرة لحم صاج"] = "204101",
    ["شطيرة دجاج صاج"] = "204102",
    ["شطيرة خضروات صاج"] = "204103",
    ["شطيرة جبن صاج"] = "204104",
    ["شطيرة لحم غزال صاج"] = "204105",
    ["شطيرة لحم ضأن صاج"] = "204106",
    ["أناناس معلب"] = "204201",
    ["فصوليا خضراء معلبة"] = "204202",
    ["ذرة حلو معلب"] = "204203",
    ["فراولة معلبة"] = "204204",
    ["باشن فروت معلبة"] = "204205",
    ["كرز معلب"] = "204206",
    ["خوخ معلب"] = "204207",
    ["مشمش معلب"] = "204208",
    ["بالون الثعلب"] = "204301",
    ["بالون البط"] = "204302",
    ["بالون الضفدع"] = "204303",
    ["بالون القط"] = "204304",
    ["بالون البطيخ"] = "204305",
    ["بالون المخيف"] = "204306",
    ["ديك رومي مشوي تقليدي"] = "204401",
    ["لحم ضأن مشوي تقليدي"] = "204402",
    ["لحم غزال مشوي تقليدي"] = "204403",
    ["يقطين مشوي تقليدي"] = "204404",
    ["قبعة الكريسماس"] = "204501",
    ["جوارب الكريسماس"] = "204502",
    ["أحذية الكريسماس"] = "204503",
    ["قفازات بدون أصابع الكريسماس"] = "204504",
    ["وشاح الكريسماس"] = "204505",
    ["أجنحة دجاج مقلية"] = "204601",
    ["بطاطس مقلية"] = "204602",
    ["بصل مقلي"] = "204603",
    ["كرات لحم مقلية"] = "204604",
    ["سمك بان كيك مقلي"] = "204605",
    ["ستيك موزاريلا"] = "204606",
    ["كولا"] = "204701",
    ["صودا الليمون"] = "204702",
    ["صودا برتقال"] = "204703",
    ["شراب زنجبيل"] = "204704",
    ["بان كيك كراميل"] = "204801",
    ["بان كيك جبن"] = "204802",
    ["بان كيك شوكولاتة"] = "204803",
    ["بان كيك التوت"] = "204804",
    ["بان كيك عنبية"] = "204805",
    ["بان كيك قوس قزح"] = "204806",
    ["رقائق البطاطس"] = "204901",
    ["رقائق البطاطس الحلوة"] = "204902",
    ["رقائق البطاطس بطعم الموز"] = "204903",
    ["رقائق البطاطس بطعم الجمبري"] = "204904",
    ["رقائق البطاطس بطعم الباذنجان"] = "204905",
    ["دونات شكولاتة سادة"] = "205001",
    ["دونات شوكولاتة بيضاء"] = "205002",
    ["دونات أوريو"] = "205003",
    ["دونات الفراولة"] = "205004",
    ["دونات ساكورا"] = "205005",
    ["دونات قوس قزح"] = "205006",
    ["دولاب سباحة البطيخ"] = "205101",
    ["دولاب سباحة افوكادو"] = "205102",
    ["دولاب سباحة الإوزة"] = "205103",
    ["دولاب سباحة البطة"] = "205104",
    ["دولاب سباحة الأناناس"] = "205105",
    ["زي يقطين الهالوين"] = "205201",
    ["زي أفوكادو الهالوين"] = "205202",
    ["زي طاووس الهالوين"] = "205203",
    ["زي هيكل عظمي الهالوين"] = "205204",
    ["زي أرنب الهالوين"] = "205205",
    ["حلوى الدب بطعم الفراولة"] = "205301",
    ["حلوى الدب بطعم المانجو"] = "205302",
    ["حلوى الدب بطعم العناب"] = "205303",
    ["حلوى الدب بطعم العرقسوس"] = "205304",
    ["حلوى الدب بطعم العنب"] = "205305",
    ["حلوى الدب بطعم الأناناس"] = "205306",
    ["ماكرون بالكراميل"] = "205401",
    ["ماكرون بالليمون"] = "205402",
    ["ماكرون برالين"] = "205403",
    ["ماكرون بالتوت البري"] = "205404",
    ["ماكرون بالفستق"] = "205405",
    ["ماكرون قوس قزح"] = "205406",
    ["بتلة الوردة الحمراء"] = "205501",
    ["بتلة الوردة الزرقاء"] = "205502",
    ["بتلة الزنبق"] = "205503",
    ["بتلة زهرة السوسن"] = "205504",
    ["بتلة بلوميريا"] = "205505",
    ["بتلة زهرة ماغنوليا"] = "205506",
    ["معكرونة سريعة التحضير حارة"] = "205601",
    ["معكرونة سريعة التحضير بطعم ديك الرومي"] = "205602",
    ["معكرونة سريعة التحضير بطعم اللحم"] = "205603",
    ["معكرونة سريعة التحضير بطعم لحم الخنزير"] = "205604",
    ["معكرونة سريعة التحضير بطعم الكيمتشي"] = "205605",
    ["معكرونة سريعة التحضير بطعم الجمبري"] = "205606",
    ["صنداي بالفراولة"] = "205701",
    ["صنداي أوريو"] = "205702",
    ["صنداي بالجوز الهند"] = "205703",
    ["صنداي ماتشا"] = "205704",
    ["صنداي وايفر"] = "205705",
    ["صنداي رقائق البطاطا"] = "205706",
    ["برسيم الرمل"] = "205801",
    ["أناناس الرمل"] = "205802",
    ["برغر رمل"] = "205803",
    ["ألبكة رمل"] = "205804",
    ["كابياء رمل"] = "205805",
    ["سلطعون رمل"] = "205806",
    ["منحوتة رملية على شكل نجمة الحظ"] = "205808",
    ["تاكو بالخضروات"] = "205901",
    ["تاكو بالافوكادو"] = "205902",
    ["تاكو بالبقوليات"] = "205903",
    ["تاكو بالدجاج المشوي"] = "205904",
    ["تاكو ستيك مشوي"] = "205905",
    ["تاكو بالسمك"] = "205906",
    ["شمعة معطرة بالليمون"] = "206001",
    ["شمعة معطرة بجوز الهند"] = "206002",
    ["شمعة معطرة بالمانجو"] = "206003",
    ["شمعة معطرة بالورد"] = "206004",
    ["شمعة معطرة باللافندر"] = "206005",
    ["شمعة معطرة بالفانيليا"] = "206006",
    ["أومليت بالفطر"] = "206101",
    ["أومليت بالجبن"] = "206102",
    ["أومليت بالقيقب"] = "206103",
    ["أومليت بالموز"] = "206104",
    ["أومليت بالسجق"] = "206105",
    ["أومليت بالجمبري"] = "206106",
    ["وشاح فرو أنغورا"] = "206201",
    ["كنزة صوف"] = "206202",
    ["قبعة من ريش النعامة"] = "206203",
    ["وسادة كابياء"] = "206204",
    ["معطف شتوي"] = "206205",
    ["لحاف"] = "206206",
    ["زبادي مثلج بالأناناس"] = "206301",
    ["زبادي مثلج بالفانيلا"] = "206302",
    ["زبادي مثلج بالكرز"] = "206303",
    ["زبادي مثلج بالشوكولاتة"] = "206304",
    ["زبادي مثلج مع باشن فروت"] = "206305",
    ["زبادي مثلج بالقهوة"] = "206306",
    ["حبوب الذرة"] = "206401",
    ["حبوب الشوفان"] = "206402",
    ["حبوب أوريو"] = "206403",
    ["حبوب حنطة سوداء"] = "206404",
    ["حبوب بالعسل"] = "206405",
    ["حبوب الكينوا"] = "206406",
    ["سندويشة خضار"] = "206501",
    ["سندويشة افوكادو"] = "206502",
    ["سندويشة ديك رومي"] = "206503",
    ["سندويشة جبن مشوي"] = "206504",
    ["سندويشة ستيك"] = "206505",
    ["سندويشة تونا"] = "206506",
    ["الكب كيك بالتوت البري"] = "206601",
    ["الكب كيك بالقرفة"] = "206602",
    ["الكب كيك بالفراولة"] = "206603",
    ["الكب كيك بالشوكولاتة البيضاء"] = "206604",
    ["الكب كيك بالكيوي"] = "206605",
    ["الكب كيك بالرمان"] = "206606",
    ["علكة بالفراولة"] = "206701",
    ["علكة بالهيل"] = "206702",
    ["علكة بالباشن فروت"] = "206703",
    ["علكة بالبرتقال"] = "206704",
    ["علكة بالليمون"] = "206705",
    ["علكة بالبطيخ"] = "206706",
    ["وافل بالقيقب"] = "206801",
    ["وافل باليقطين"] = "206802",
    ["وافل بالأناناس"] = "206803",
    ["وافل بالآيس كريم"] = "206804",
    ["وافل دقيق الذرة"] = "206805",
    ["وافل بالشوكولاتة"] = "206806",
    ["نودلز سيتشوان الحار"] = "206901",
    ["نودلز رامن"] = "206902",
    ["نودلز بالفاصولياء سوداء"] = "206903",
    ["نودلز الفيتنامي"] = "206904",
    ["فيتوتشيني بالكريمة"] = "206905",
    ["فوزيلي بالخردل"] = "206906",
    ["ثلج مجروش بالجبن والبطيخ"] = "207001",
    ["ثلج مجروش بالجبن والعنب"] = "207002",
    ["ثلج مجروش بالجبن وعنب الثور"] = "207003",
    ["ثلج مجروش بالجبن والكيوي"] = "207004",
    ["ثلج مجروش بالجبن والملح الصخري"] = "207005",
    ["ثلج مجروش بالجبن والشوكولاتة"] = "207006",
    ["كعكة سويسرية بمربى الفراولة"] = "207101",
    ["كعكة سويسرية بالتوت الشامي والليمون"] = "207102",
    ["كعكة سويسرية بشوكولاتة الكرز"] = "207103",
    ["كعكة سويسرية بجبن وردة حمراء"] = "207104",
    ["كعكة سويسرية بكراميل اللوز"] = "207105",
    ["كعكة سويسرية بكريمة قوس قزح"] = "207106",
    ["قناع يقطين الهالوين"] = "207201",
    ["قناع فرانكشتاين"] = "207202",
    ["قناع العين المخيف"] = "207203",
    ["قناع الفضائي المبتسم"] = "207204",
    ["قناع ريش الطاووس"] = "207205",
    ["قناع الوردة الحمراء"] = "207206",
    ["سميط دوغ"] = "207301",
    ["سميط بالقرفة والسكر"] = "207302",
    ["سميط زبدة فول سوداني"] = "207303",
    ["سميط بالسمسم"] = "207304",
    ["سميط باللوز اللذيذ"] = "207305",
    ["سميط بالشوكولاتة البيضاء"] = "207306",
    ["خبز الزنجبيل شجرة الكريسماس"] = "207401",
    ["خبز الزنجبيل جورب الكريسماس"] = "207402",
    ["حلوى خبز الزنجبيل بقصب السكر"] = "207403",
    ["خبز الزنجبيل رجل الثلج"] = "207404",
    ["خبز الزنجبيل بندفة الثلج"] = "207405",
    ["خبز الزنجبيل كوخ الكريسماس"] = "207406",
    ["منحوت صبارة جليدية"] = "207501",
    ["منحوت جبن جليدي"] = "207502",
    ["منحوت وردة جليدية"] = "207503",
    ["منحوت رنة جليدية"] = "207504",
    ["منحوت السلعطون الجليدي"] = "207505",
    ["منحوت القلب الجليدي"] = "207506",
    ["حساء إندومي دجاج"] = "207601",
    ["حساء اللحم والخضروات"] = "207602",
    ["حساء البطاطا والكرات"] = "207603",
    ["حساء فلفل محشي"] = "207604",
    ["حساء الزفاف"] = "207605",
    ["حساء البروكلي والجبن"] = "207606",
    ["تشيرو بالقرفة"] = "207701",
    ["تشيرو بالجبن"] = "207702",
    ["تشيرو بالفراولة"] = "207703",
    ["تشيرو بالشوكولاتة"] = "207704",
    ["تشيرو بالكراميل"] = "207705",
    ["تشيرو بالبطيخ الحامض"] = "207706",
    ["كعكة الفطائر المنفوخة الزهرة الزرقاء"] = "207801",
    ["كعكة الفطائر المنفوخة الزهرة الحمراء"] = "207802",
    ["كعكة الفطائر المنفوخة بالصبارة"] = "207803",
    ["كعكة الفطائر المنفوخة بالزنبق"] = "207804",
    ["كعكة الفطائر المنفوخة بزهرة السوسن"] = "207805",
    ["كعكة الفطائر المنفوخة بلوميريا"] = "207806",
    ["لوح القيقب"] = "207901",
    ["لوح الأناناس"] = "207902",
    ["لوح زبدة فول سوداني"] = "207903",
    ["لوح الليمون الحامض"] = "207904",
    ["لوح اليقطين"] = "207905",
    ["لوح ماتشا موشي"] = "207906",
    ["شامبو بالزنجبيل"] = "208001",
    ["شامبو بالساكورا"] = "208002",
    ["شامبو بالخوخ"] = "208003",
    ["شامبو أكليل الجبل"] = "208004",
    ["شامبو بالجوز الهند"] = "208005",
    ["شامبو شجر شاي"] = "208006",
    ["عصير الفراولة المعتق"] = "208101",
    ["عصير باشن فروت المعتق"] = "208102",
    ["عصير إجاص المعتق"] = "208103",
    ["عصير جوز الهند المعتق"] = "208104",
    ["عصير العناب المعتق"] = "208105",
    ["عصير البرقوق المعتق"] = "208106",
    ["مشروب الطاقة بنكهة البرتقال"] = "208201",
    ["مشروب الطاقة بنكهة الأناناس"] = "208202",
    ["مشروب الطاقة بنكهة البطيخ"] = "208203",
    ["مشروب الطاقة بنكهة الفواكه"] = "208204",
    ["مشروب الطاقة بنكهة القهوة"] = "208205",
    ["مشروب الطاقة بنكهة نيتروجين"] = "208206",
    ["الأقحوانات الخالدة"] = "208301",
    ["اللوتس الخالد"] = "208302",
    ["زهرة البنفسج الخالدة"] = "208303",
    ["الوردة الوردية الخالدة"] = "208304",
    ["الياسمين الخالد"] = "208305",
    ["النرجس الخالد"] = "208306",
    ["مادلين بالحليب"] = "208401",
    ["مادلين بالليمون"] = "208402",
    ["مادلين باللوز"] = "208403",
    ["مادلين بالشوكولاتة"] = "208404",
    ["مادلين بالعناب"] = "208405",
    ["مادلين بالمكسرات البرازيلية"] = "208406",
    ["كرواسون بالتوت الشامي"] = "208501",
    ["كرواسون بالتوت البري"] = "208502",
    ["كرواسون بالفستق الحلبي"] = "208503",
    ["كرواسون بشوكولاتة اللوز"] = "208504",
    ["كرواسون بشوكولاتة الفول السوداني"] = "208505",
    ["كرواسون بالماتشا"] = "208506",
    ["حلوى الكريسماس بالحليب"] = "208701",
    ["حلوى الكريسماس بالفستق"] = "208702",
    ["حلوى الكريسماس بالكاكاو"] = "208703",
    ["حلوى الكريسماس بشراب زنجبيل"] = "208704",
    ["حلوى الكريسماس بثمرة الحب"] = "208705",
    ["حلوى الكريسماس شوكولاتة سادة"] = "208706",
    ["قفازات بدون أصابع من ريش الطاووس"] = "208801",
    ["قفازات بدون أصابع من صوف ألبكة"] = "208802",
    ["قفازات بدون أصابع من شعر الحصان"] = "208803",
    ["قفازات بدون أصابع من فرو الرنة"] = "208804",
    ["قفازات بدون أصابع من وبر الجمل"] = "208805",
    ["قفازات ريشة البجعة"] = "208806",
    ["مهلبية بالكراميل"] = "208901",
    ["مهلبية باليقطين"] = "208902",
    ["مهلبية بالفراولة"] = "208903",
    ["مهلبية باليوسفي"] = "208904",
    ["مهلبية بالياسمين"] = "208905",
    ["مهلبية بالشوكولاته"] = "208906",
    ["شاي ورد أحمر"] = "209001",
    ["شاي باشن فروت"] = "209002",
    ["شاي الأقحوان"] = "209003",
    ["شاي ساكورا"] = "209004",
    ["شاي الزنبق"] = "209005",
    ["شاي بذور المريمية الإسبانية"] = "209006",
    ["توست بالجبن"] = "209101",
    ["توست بالعناب"] = "209102",
    ["توست بالفراولة"] = "209103",
    ["توست بالأفوكادو"] = "209104",
    ["توست سلطة البيض"] = "209105",
    ["توست شوكلاته سادة"] = "209106",
    ["العصا السحرية ريش الطاووس"] = "209201",
    ["العصا السحرية ريش الإوز"] = "209202",
    ["العصا السحرية نجمة الحظ"] = "209203",
    ["العصا السحرية ريشة فينكس"] = "209204",
    ["العصا السحرية البيلسان"] = "209205",
    ["العصا السحرية العيون المخيفة"] = "209206",
    ["كويساديلا بالطماطم"] = "209301",
    ["كويساديلا بالدجاج"] = "209302",
    ["كويساديلا ستيك"] = "209303",
    ["كويساديلا بالموز"] = "209304",
    ["كويساديلا بالسلطعون"] = "209305",
    ["كويساديلا بالهليون"] = "209306",
    ["حلوى غزل البنات بنكهة أوريو"] = "209401",
    ["حلوى غزل البنات بنكهة الفراولة"] = "209402",
    ["حلوى غزل البنات بنكهة حلوى اليقطين"] = "209403",
    ["حلوى غزل البنات بنكهة كأس زبدة الفستق"] = "209404",
    ["حلوى غزل البنات بنكهة الماتشا"] = "209405",
    ["حلوى غزل البنات بنكهة شراب المجرة"] = "209406",
    ["حلوى الأرز المقرمش الأصلي"] = "209501",
    ["حلوى الأرز المقرمش بالمارشميلو"] = "209502",
    ["حلوى الأرز المقرمش بزبدة الفستق"] = "209503",
    ["حلوى الأرز المقرمش بالشوكولاتة"] = "209504",
    ["حلوى الأرز المقرمش بالكراميل"] = "209505",
    ["حلوى الأرز المقرمش قوس قزح"] = "209506",
    ["البارفيه بنكهة الأناناس"] = "209601",
    ["البارفيه بنكهة التوت البري"] = "209602",
    ["البارفيه بنكهة مربى العناب"] = "209603",
    ["البارفيه بنكهة الشوكولاتة"] = "209604",
    ["بارفيه السكر السحري"] = "209605",
    ["بارفيه الجيلي السحري"] = "209606",
    ["دمية الشبح الصغير"] = "209701",
    ["دمية فرانكشتاين"] = "209702",
    ["دمية وحش اليقطين"] = "209703",
    ["دمية شجرة مخيفة"] = "209704",
    ["دمية الهيكل العظمي"] = "209705",
    ["دمية مصاص الدماء"] = "209706",
    ["كريم باف بنكهة المانجو"] = "209801",
    ["كريم باف بنكهة الفراولة"] = "209802",
    ["كريم باف بنكهة الأفوكادو"] = "209803",
    ["كريم باف بنكهة كريم زبدة"] = "209804",
    ["كريم باف بنكهة مانغوستين"] = "209805",
    ["كريم باف بنكهة الكيوي الذهبي"] = "209806",
    ["كرة الثلج على شكل نجمة الحظ"] = "210001",
    ["كرة الثلج على شكل مفرقع المهرجان"] = "210002",
    ["كرة الثلج على شكل المصباح المضيء"] = "210003",
    ["كرة الثلج على شكل نوتة موسيقية"] = "210004",
    ["كرة الثلج على شكل لعبة الرنة"] = "210005",
    ["كرة الثلج على شكل قطرة النيتروجين"] = "210006",
    ["دوراياكي بنكهة قهوة موكا"] = "210101",
    ["دوراياكي بنكهة أناناولة"] = "210102",
    ["دوراياكي بنكهة مهلبية جوز الهند"] = "210103",
    ["دوراياكي بنكهة الازوكي"] = "210104",
    ["دوراياكي بنكهة جبن مالح"] = "210105",
    ["دوراياكي بنكهة بوميلو"] = "210106",
    ["معجون أسنان بزيت البابونج المركز"] = "210201",
    ["معجون أسنان بالنعناع"] = "210202",
    ["معجون أسنان بالخوخ"] = "210203",
    ["معجون أسنان بزهرة السوسن"] = "210204",
    ["معجون أسنان ساكورا"] = "210205",
    ["معجون أسنان بالياسمين"] = "210206",
    ["سوشي بالخيار"] = "210301",
    ["سوشي بالبيض وأعشاب البحر"] = "210302",
    ["سوشي باللحم"] = "210303",
    ["سوشي بالسلطعون"] = "210304",
    ["سوشي بالسلمون"] = "210305",
    ["سوشي بالتونا"] = "210306",
    ["سوشي بالجمبري"] = "210307",
    ["فطيرة الشوكولاتة بالكرز"] = "210401",
    ["فطيرة الشوكولاتة بالتوت البري"] = "210402",
    ["فطيرة الشوكولاتة لاتيه"] = "210403",
    ["فطيرة الشوكولاتة باشن فروت"] = "210404",
    ["فطيرة الشوكولاتة سوداء"] = "210405",
    ["فطيرة الشوكولاتة بالبطيخ"] = "210406",
    ["قبعة الساحر الشبح"] = "210501",
    ["قبعة الساحر الكريستالية"] = "210502",
    ["قبعة ساحر النعام"] = "210503",
    ["قبعة الساحر الطاووس"] = "210504",
    ["قبعة الساحر السنجاب"] = "210505",
    ["قبعة الساحر البعجة"] = "210506",
    ["وافل الفقاعة ثروة البرتقال"] = "210601",
    ["وافل الفقاعة بطاطا حلوة"] = "210602",
    ["وافل الفقاعة ليتشي"] = "210603",
    ["وافل الفقاعة النعناع"] = "210604",
    ["وافل الفقاعة ماكرون بالكراميل"] = "210605",
    ["وافل الفقاعة جيلي سحري"] = "210606",
    ["نشا البطاطا الحلوة"] = "210701",
    ["طحين الفاصوليا"] = "210702",
    ["مسحوق اليقطين"] = "210703",
    ["فراولة مُسكَّرة"] = "210801",
    ["أناناس مُسكَّر"] = "210802",
    ["كيوي مُسكَّر"] = "210803",
    ["أرز لزج مُسكَّر"] = "210804",
    ["زعرور مُسكَّر"] = "210805",
    ["دوريان مُسكَّر"] = "210806",
    ["حليب بنكهة التوت البري"] = "210901",
    ["قهوة بالحليب"] = "210902",
    ["حليب بنكهة الشمام"] = "210903",
    ["حليب بنكهة مربى الفراولة"] = "210904",
    ["حليب بنكهة الشوكولاتة"] = "210905",
    ["حليب بنكهة الموز"] = "210906",
}

function codes_repository_menu()
    while true do
        local search_input = gg.prompt(
            {"🔍 مستودع الأكواد\nأدخل اسم المنتج (أو جزء منه) أو كود العنصر للبحث عنه:"}, 
            {""}, 
            {"text"}
        )
        if not search_input or search_input[1] == "" then
            return
        end
        
        local query = search_input[1]:match("^%s*(.-)%s*$")
        if query == "" then
            gg.alert("الرجاء إدخال كلمة للبحث!")
        else
            local results = {}
            local count = 0
            local results_keys = {}
            local results_display = {}
            
            for name, code in pairs(all_codes_db) do
                if string.find(name, query, 1, true) or string.find(code, query, 1, true) then
                    local display_name = name .. " [" .. code .. "]"
                    table.insert(results_display, display_name)
                    table.insert(results_keys, code)
                    count = count + 1
                end
            end
            
            if count == 0 then
                gg.alert("❌ لم يتم العثور على أي عنصر يحتوي على '" .. query .. "'\nتأكد من كتابة الكلمة صحيحة أو استخدم الأرقام.")
            else
                table.insert(results_display, "🔙 رجوع للبحث")
                local choice = gg.choice(results_display, nil, "✅ نتائج البحث (" .. count .. " عنصر):")
                if choice and choice < #results_display then
                    local selected_code = results_keys[choice]
                    gg.toast("تم تحديد الكود: " .. selected_code)
                    gg.copyText(selected_code)
                    gg.toast("📋 تم نسخ الكود: " .. selected_code)
                end
            end
        end
    end
end


function event_activity_menu()
    while true do
        local menu = {
            "🚀 تفعيل الفاعلية (بحث، تعديل، وتجميد)",
            "🧹 تنظيف وفك التجميد (لجولة جديدة)",
            "⬅️ رجوع للقائمة الرئيسية"
        }
        
        local choice = gg.choice(menu, nil, "🎈 قائمة الفاعلية (Event)")
        if choice == nil then return end

        if choice == 1 then
            run_activity_event()
            -- العودة للقائمة الرئيسية بعد التنفيذ أو الإلغاء
            return 
        elseif choice == 2 then
            gg.clearList()
            gg.clearResults()
            gg.toast("✅ تم فك التجميد وتنظيف الذاكرة.\nأنت الآن جاهز لجولة فاعلية جديدة بدون أخطاء!")
        elseif choice == 3 then
            return
        end
    end
end

function run_activity_event()
    gg.clearResults()

    -- 1. سؤال اللاعب عن القيمة الحالية 
    local current_val = nil
    while true do
        current_val = gg.prompt(
            {"أدخل القيمة الحالية للفعالية (مثال: 5, 15, 20):"}, 
            {[1]=""}, 
            {"number"}
        )
        if current_val then 
            break 
        end
        gg.toast("🚫 تم إلغاء بدء الفاعلية.")
        return 
    end

    local start_val = tostring(tonumber(current_val[1]))
    
    -- إخفاء واجهة السكربت كلياً أثناء البحث
    gg.setVisible(false)
    gg.toast("🔍 جاري البحث في الخلفية...")
    
    gg.searchNumber(start_val, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)

    -- 2. حلقة التصفية الذكية
    while true do
        local current_count = gg.getResultCount()
        
        if current_count <= 20 then
            break -- الخروج من الحلقة التكرارية إذا كانت النتائج قليلة كفاية
        end
        
        gg.alert("النتائج الحالية: " .. current_count .. "\n\n1. سيتم إخفاء السكربت مؤقتاً.\n2. ارجع للعبة واربح فاعلية إضافية لتغيير الرقم.\n3. اضغط على أيقونة GG مرة أخرى لترشيح الرقم الجديد.")
        
        -- استئناف اللعبة 
        gg.processResume()
        
        -- إخفاء والانتظار
        gg.setVisible(false)
        while not gg.isVisible() do
            gg.sleep(100)
        end
        
        -- بمجرد فتحه مجدداً نعيد إخفاءه لإخفاء الأكواد
        gg.setVisible(false)
        
        local new_val = nil
        while true do
            new_val = gg.prompt(
                {"العدد الحالي (" .. current_count .. ")\nأدخل القيمة الجديدة بعد أن تغيرت في اللعبة:"}, 
                {[1]=""}, 
                {"number"}
            )
            if new_val then 
                break 
            end
            gg.toast("👁️‍🗨️ تم إخفاء السكربت مؤقتاً.\nالعب ثم اضغط على الأيقونة عندما تتغير القيمة.")
            gg.setVisible(false)
            while not gg.isVisible() do
                gg.sleep(100)
            end
            gg.setVisible(false)
        end
        
        local refined_value = tostring(tonumber(new_val[1]))
        
        -- إخفاء واجهة السكربت كلياً أثناء التصفية
        gg.setVisible(false)
        gg.toast("🔍 جاري التصفية في الخلفية...")
        gg.refineNumber(refined_value, gg.TYPE_DOUBLE, false, gg.SIGN_EQUAL, 0, -1, 0)
        
        if gg.getResultCount() == 0 then
            gg.alert("⚠️ النتائج صفر!\nيبدو أن اللعبة غيرت مكان الذاكرة أو أن الرقم غير دقيق.\n\nنصيحة: تأكد من كتابة الرقم الجديد بدقة. سيتم الإلغاء للبدء من جديد.")
            gg.clearResults()
            return
        end
    end

    -- 3. جلب وتعديل وتجميد النتائج
    local revert = gg.getResults(gg.getResultCount(), nil, nil, nil, nil, nil, nil, nil, nil)
    if not revert or #revert == 0 then
        gg.alert("خطأ: تعذر جلب النتائج. حاول مجدداً الثبات في قيم اللعبة.")
        gg.clearResults()
        return
    end

    -- سؤال المستخدم عن القيمة التي يريد التعديل إليها وجعل 750 هي الافتراضية
    local edit_val_request = gg.prompt({"أدخل الرقم المراد التعديل والتجميد عليه:"}, {"750"}, {"number"})
    if not edit_val_request then
        gg.toast("🚫 تم الإلغاء في الخطوة الأخيرة (لم يتم التعديل).")
        gg.clearResults()
        return
    end
    
    local final_target_val = tostring(tonumber(edit_val_request[1]))

    -- إخفاء وتطبيق التجميد في الخلفية بدون اظهار النتائج
    gg.setVisible(false)
    gg.toast("⚙️ جاري التعديل والتجميد...")

    local items = {}
    for i, v in ipairs(revert) do
        items[i] = {address = v.address, flags = v.flags, value = final_target_val, freeze = true}
    end

    -- تطبيق التجميد
    gg.addListItems(items)
    
    -- مسح واجهة النتائج المتبقية لضمان عدم رؤيتها بالخلف
    gg.clearResults()

    gg.toast("🔥 مبروك! تم التعديل إلى " .. final_target_val .. " وتجميد القيمة!\nيمكنك إغلاق النافذة واللعب براحة..")
    gg.processResume()

    -- الإخفاء التلقائي ليعود اللعب بشاشة نظيفة كلياً
    gg.setVisible(false)
    while gg.isVisible() do
        gg.sleep(100)
    end
end

function HOME()
    local actions = {
        [1] = yellow_menu,
        [2] = fishing_menu,
        [3] = cloud_haven_action,
        [4] = modified_features_menu,
        [5] = farm_activations_menu,
        [6] = island_activations_menu,
        [7] = luck_speed_menu,
        [8] = featured_menu,
        [9] = lab_crops_menu,
        [10] = neighbor_requests_menu,
        [11] = codes_repository_menu,
        [12] = event_activity_menu
    }

    local menu = {
        "💛 『الشراء بالأصفر 』",
        "🎣 『قائمة الصيد 』",
        "☁️ 『مزرعة السحاب 』",
        "🛠️ 『المميزات المعدلة 』",
        "🌾 『تفعيلات المزرعة 』",
        "🏝️ 『تفعيلات الجزيرة 』",
        "🎲 『الحظ والسرعة 』",
        "🌟 『 مميز 』",
        " 『مزروعات المختبر 』",
        "🏘️ 『طلب مطورات من الجيران』",
        "📦 『مستودع الأكواد 』",
        "🎈 『الفاعلية』",
        "❌ خروج"
    }

    while true do
        local choice = gg.choice(menu, nil, "سكربت محمد رأفت")
        if choice == nil then
            return
        end

        if choice == 13 then
            local confirm_exit = gg.alert("هل تريد إنهاء السكربت بالكامل؟", "✅ نعم، إنهاء", "↩️ لا")
            if confirm_exit == 1 then
                RF_RUNNING = false
                gg.toast("🛑 تم إنهاء السكربت.")
                return
            end
        end

        local fn = actions[choice]
        if fn then
            local ok, err = xpcall(fn, debug.traceback)
            if not ok then
                gg.alert("⚠️ حدث خطأ أثناء تنفيذ: " .. menu[choice] .. "\n\n" .. tostring(err) .. "\n\nتم منع إنهاء السكربت. يمكنك المتابعة.")
            end
        end
    end
end

local function RF_BOOTSTRAP()
    gg.setVisible(false)
    HOME()
    while RF_RUNNING do
        if gg.isVisible(true) then
            gg.setVisible(false)
            HOME()
        end
        gg.sleep(120)
    end
    gg.clearResults()
end

RF_BOOTSTRAP()