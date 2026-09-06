-- This is a testbench. This file is to be used to benchmark Lua's GC.
function test()
    local survivors = {}

    -- Parameters.
    -- m, n        = m*n total allocations.
    -- survive_every = 1 out of every N objects is kept alive permanently;
    --                 the other N-1 are garbage the instant the iteration
    --                 ends. 
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
                -- Promoted: referenced from `survivors` for the rest of
                -- the run, so it outlives many collection cycles.
                survivors[#survivors + 1] = obj
            end
        end
    end

    return survivors
end

test()
