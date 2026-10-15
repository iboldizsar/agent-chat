local root = assert(arg[1])
local M = assert(loadfile(root .. '/plugin/lib/transcript.luau'))()
local messages = {
    { id = 'u', role = 'You', text = 'Question' },
    { id = 'empty', role = 'Assistant', text = '' },
    { id = 'one', role = 'Tool', text = 'commandExecution · completed', details = 'private command', activityKind = 'commandExecution', activityStatus = 'completed' },
    { id = 'two', role = 'Tool', text = 'commandExecution · inProgress', details = 'private result', activityKind = 'commandExecution', activityStatus = 'inProgress' },
    { id = 'a', role = 'Assistant', text = 'Answer' },
    { id = 'oc', role = 'Assistant', text = '', details = 'tool output', activityStatus = 'failed' },
}
local rows = M.rows(messages)
assert(#rows == 4 and rows[2].role == 'Activity' and #rows[2].items == 2 and rows[3].text == 'Answer')
assert(M.summary(rows[2]) == 'Activity · 2 commands · running')
local text, failed = M.summary(rows[4]); assert(failed and text:find('1 failed', 1, true))
assert(#messages == 6 and messages[3].text == 'commandExecution · completed', 'presentation must not modify backend/export records')
messages[4].activityStatus = 'completed'
assert(M.summary(M.rows(messages)[2]) == 'Activity · 2 commands')
print('Tool grouping, live/failure summaries and transcript/export preservation: passed')
