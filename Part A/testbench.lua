function test()
    local survivors = {}
    local m = 1000
    local n = 100
    local survive_every = 100
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

test()