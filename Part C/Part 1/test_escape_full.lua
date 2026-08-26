-- TEST 1: NON-ESCAPING — purely local, no escape path
function test_safe()
    local t = {}
    t[1] = "hello"
    t[2] = 42
    local x = t[1]
end

-- TEST 2: ESCAPES — returned (Rule 1)
function test_return()
    local t = {}
    t[1] = "data"
    return t
end

-- TEST 3: ESCAPES — captured by closure (Rule 2)
function test_capture()
    local t = {}
    local function inner()
        print(t[1])
    end
end

-- TEST 4: ESCAPES — stored in global (Rule 3)
function test_store_global()
    local t = {}
    global_table = t
end

-- TEST 5: ESCAPES — passed to unknown function (Rule 4)
function test_call_unknown()
    local t = {}
    unknown_func(t)
end

-- TEST 6: NON-ESCAPING — only whitelisted calls
function test_whitelist()
    local t = {}
    print(t)
    local x = type(t)
end

-- TEST 7: NON-ESCAPING — table used only for local computation
function test_local_compute()
    local t = {}
    t[1] = 10
    t[2] = 20
    local sum = t[1] + t[2]
    local tp = type(t)
end

-- TEST 8: ESCAPES — stored into another local that is returned (Rule 3 chain)
function test_store_chain()
    local outer = {}
    local inner = {}
    outer[1] = inner
    return outer
end

-- TEST 9: ESCAPES — passed to table.insert (not whitelisted)
function test_table_insert()
    local t = {}
    local list = {}
    table.insert(list, t)
end

-- TEST 10: NON-ESCAPING — only length operator used
function test_length_only()
    local t = {1, 2, 3}
    local n = #t
end

-- TEST 11: ESCAPES — returned inside a new table (Rule 1)
function test_return_wrapped()
    local t = {}
    return {t}
end

-- TEST 12: NON-ESCAPING — multiple locals, none escape
function test_multi_local()
    local a = {}
    local b = {}
    a[1] = "x"
    b[1] = "y"
end

-- TEST 13: ESCAPES — one of two locals escapes via return
function test_one_escapes()
    local safe = {}
    local unsafe = {}
    safe[1] = "ok"
    return unsafe
end

-- TESTBENCH — the actual workload
function test_bench()
    local survivors = {}
    local m = 10
    local n = 10
    local survive_every = 10
    local count = 0
    for i = 1, m do
        for j = 1, n do
            count = count + 1
            local obj = {}
            obj[1] = "payload"
            obj[2] = {i, j}
            if count % survive_every == 0 then
                survivors[#survivors + 1] = obj
            end
        end
    end
    return survivors
end
