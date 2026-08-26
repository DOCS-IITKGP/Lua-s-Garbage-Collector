function test_safe()
    local t = {}
    t[1] = "hello"
    t[2] = 42
    local x = t[1]
end

function test_return()
    local t = {}
    return t
end

function test_capture()
    local t = {}
    local function inner()
        print(t[1])
    end
end

function test_store()
    local t = {}
    global_table = t
end

function test_call()
    local t = {}
    unknown_func(t)
end

function test_whitelist()
    local t = {}
    print(t)
    local x = type(t)
    local n = #t
end
