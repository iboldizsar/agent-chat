local M = assert(loadfile(assert(arg[1]) .. '/plugin/lib/connection.luau'))()
local now = 0
local c = M.new(function() return now end, function() return .5 end)
local token = assert(c.begin(true))
assert(not c.begin(true), 'connection attempts must not overlap')
assert(c.failure(token, true) and not c.valid(token), 'failed attempt callbacks must become stale immediately')
assert(not c.due()); now = 1000; assert(c.due())
token = c.begin(false); assert(c.state.attempt == 2)
assert(c.failure(token, true)); assert(c.state.nextRetryAt == 3000)
for i = 3, 8 do
    now = c.state.nextRetryAt
    token = c.begin(false); c.failure(token, true)
end
assert(c.state.phase == 'offline' and not c.due(), 'automatic retries must be bounded')
token = c.begin(true); assert(c.state.attempt == 1)
assert(c.success(token) and c.state.phase == 'connected')
c.close(); assert(not c.success(token), 'closed connection callbacks must be stale')
token = c.begin(true); now = now + 20001; assert(c.expired())
print('Connection guards, capped backoff, exhaustion, timeout and manual retry: passed')
