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
        "🔓 ديكورات وحروف (فتح الحدود)",
        "🌳 أشجار بالكوبون ",
        "🚜 حيوانات وآلات بالكوبون",
        "🅰️ حروف المزرعة (تبديل أعلام)",
        "🔭 طلاء وتلسكوب ",
        "🎉 فاعليات تلقائي ",
        "⚡ مطورات خارقة ",
        "⬅️ رجوع"
    }
    
    local choice = gg.choice(menu, nil, "♥️👑 مــحــمــد رأفــت 👑♥️")
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
-- ================1تحمييل1=============
function HOME()
    local actions = {
        [1] = modified_features_menu,
    }

    local menu = {
        "🛠️ 『المميزات المعدلة 』",
        "❌ خروج"
    }

    while true do
        local choice = gg.choice(menu, nil, "♥️👑 مــحــمــد رأفــت 👑♥️")
        if choice == nil then
            return
        end

        if choice == 2 then
    local confirm_exit = gg.alert("هل تريد إنهاء السكربت بالكامل؟", "✅ نعم، إنهاء", "↩️ لا")
    if confirm_exit == 1 then
        RF_RUNNING = false

        print ('დ ❤️لا تنسي الصلاة والسلام على رسول الله ❤️დ')
        print ('დ ❤️ مــحــمــد رأفــت❤️ დ')

        gg.skipRestoreState()
        gg.setVisible(true)

        os.exit()
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
        gg.sleep(100)
    end
    gg.clearResults()
end

RF_BOOTSTRAP()