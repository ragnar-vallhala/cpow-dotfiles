require('gitsigns').setup {
  on_attach = function(bufnr)
    local gs = require('gitsigns')

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    -- ]c / [c are vim's own "next change" motion, but only inside a diff
    -- buffer. Fall through to them when the buffer IS a diff so :Gdiffsplit
    -- and friends keep working, and use gitsigns otherwise -- same keys, same
    -- meaning, whichever context you are in.
    map('n', ']c', function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gs.nav_hunk('next') end)
      return '<Ignore>'
    end, 'next git hunk')

    map('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gs.nav_hunk('prev') end)
      return '<Ignore>'
    end, 'previous git hunk')

    -- hunk actions
    map('n', '<leader>hp', gs.preview_hunk, 'preview hunk')
    map('n', '<leader>hs', gs.stage_hunk, 'stage hunk')
    map('n', '<leader>hr', gs.reset_hunk, 'reset hunk')
    map('n', '<leader>hu', gs.undo_stage_hunk, 'undo stage hunk')
    map('v', '<leader>hs', function()
      gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') }
    end, 'stage selected lines')
    map('v', '<leader>hr', function()
      gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') }
    end, 'reset selected lines')

    -- whole file / blame
    map('n', '<leader>hS', gs.stage_buffer, 'stage buffer')
    map('n', '<leader>hR', gs.reset_buffer, 'reset buffer')
    map('n', '<leader>hd', gs.diffthis, 'diff this file')
    map('n', '<leader>hb', function() gs.blame_line { full = true } end, 'blame line')
    map('n', '<leader>hB', gs.toggle_current_line_blame, 'toggle inline blame')

    -- every hunk in the repo into the quickfix list, so ]q / :cnext walks
    -- between CHANGED FILES -- ]c only moves within the current buffer.
    map('n', '<leader>hq', function() gs.setqflist('all') end, 'all hunks -> quickfix')

    -- text object: `dih` deletes a hunk, `vih` selects one
    vim.keymap.set({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>',
      { buffer = bufnr, desc = 'inner hunk' })
  end,
}
