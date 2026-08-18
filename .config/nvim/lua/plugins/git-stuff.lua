return {
  "f-person/git-blame.nvim",
  event = "VeryLazy",
  opts = {
    enabled = true,
    message_template = "<author> • <summary> • <date> • <<sha>>",
    date_format = "%d-%m-%Y",
    virtual_text_column = 1,
    -- The plugin defaults to `schedule_event = "CursorMoved"` (see
    -- gitblame/config.lua), which schedules a `git blame` subprocess on every
    -- single cursor movement, debounced only by `delay`. CursorHold fires once
    -- after `updatetime` (200ms) of idle instead, so blame resolves when you
    -- stop moving rather than competing with cursor motion.
    schedule_event = "CursorHold",
    clear_event = "CursorHoldI",
    delay = 250,
  },
}
