-- TypeScript code-action keymaps for `tsc` (see `plugins/lsp.lua` for the
-- server itself).
--
-- The TypeScript 7 language server (`tsc --lsp`, formerly the `tsgo` preview)
-- does NOT implement the same code-action kinds as vtsls/tsserver. As of
-- 7.0.2 it advertises only:
--
--   quickfix, source.organizeImports, source.removeUnusedImports,
--   source.sortImports, source.fixAll
--
-- Notably there is no `source.addMissingImports[.ts]`, and the `quickfix`
-- provider returns nothing for a TS2304 "Cannot find name" diagnostic — so
-- neither `<leader>cM` nor `<leader>ca` can add an import via the LSP.
--
-- The completion path *does* support auto-import: candidates come back with
-- `labelDetails.description` set to the module, and `completionItem/resolve`
-- returns the `import { … } from "…"` edit in `additionalTextEdits`. So
-- `add_missing_imports()` below reimplements the missing action on top of it.

--- TS diagnostic codes that mean "this identifier isn't in scope".
local MISSING_NAME_CODES = {
  [2304] = true, -- Cannot find name 'X'.
  [2503] = true, -- Cannot find namespace 'X'.
  [2552] = true, -- Cannot find name 'X'. Did you mean 'Y'?
  [18004] = true, -- No value exists in scope for the shorthand property 'X'.
}

--- Byte column -> LSP character offset in the client's encoding.
local function lsp_position(buf, row, byte_col, encoding)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  byte_col = math.min(byte_col, #line)
  local character = byte_col
  if encoding == "utf-16" or encoding == "utf-32" then
    character = vim.str_utfindex(line, encoding, byte_col, false)
  end
  return { line = row, character = character }
end

--- Pick the best auto-import completion item for `name`, or nil.
local function pick_import_item(items, name)
  local candidates = {}
  for _, item in ipairs(items) do
    -- An auto-import candidate is labelled exactly like the missing name and
    -- carries the source module in labelDetails.description.
    if item.label == name and vim.tbl_get(item, "labelDetails", "description") then
      candidates[#candidates + 1] = item
    end
  end
  table.sort(candidates, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)
  return candidates[1], #candidates
end

--- tsc replacement for `source.addMissingImports.ts`.
---
--- Resolves every in-scope-missing identifier through the completion API and
--- applies the resulting import edits, one diagnostic at a time so tsc always
--- computes against the up-to-date document.
local function add_missing_imports()
  local buf = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = buf, name = "tsc" })[1]
  if not client then
    return vim.notify("tsc is not attached to this buffer", vim.log.levels.WARN)
  end

  local ns = vim.api.nvim_create_namespace("tsc_add_missing_imports")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Anchor each missing identifier to an extmark: applying an import shifts
  -- every line below it, so raw diagnostic positions go stale immediately.
  local targets, seen = {}, {}
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    local end_lnum, end_col = d.end_lnum or d.lnum, d.end_col or d.col
    if MISSING_NAME_CODES[d.code] and end_lnum == d.lnum then
      local name = vim.api.nvim_buf_get_text(buf, d.lnum, d.col, end_lnum, end_col, {})[1] or ""
      -- Request completion at the end of the identifier so the whole word is
      -- the prefix; a bare `{` from shorthand-property errors is not a name.
      if not seen[name] and name:match("^[%a_$][%w_$]*$") then
        seen[name] = true
        targets[#targets + 1] = {
          name = name,
          mark = vim.api.nvim_buf_set_extmark(buf, ns, end_lnum, end_col, {}),
        }
      end
    end
  end

  if #targets == 0 then
    return vim.notify("No missing imports found", vim.log.levels.INFO)
  end

  local added, failed, ambiguous = {}, {}, {}
  local index = 0

  local function finish()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    if #added == 0 then
      return vim.notify("No import found for: " .. table.concat(failed, ", "), vim.log.levels.WARN)
    end
    local msg = ("Added %d import%s: %s"):format(#added, #added == 1 and "" or "s", table.concat(added, ", "))
    if #ambiguous > 0 then
      msg = msg .. "\nMultiple sources, picked best match for: " .. table.concat(ambiguous, ", ")
    end
    if #failed > 0 then
      msg = msg .. "\nNo import found for: " .. table.concat(failed, ", ")
    end
    vim.notify(msg, #failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
  end

  local step
  -- Let the pending didChange flush before asking tsc for the next position.
  local function next_step()
    vim.defer_fn(step, 200)
  end

  step = function()
    index = index + 1
    local target = targets[index]
    if not target then
      return finish()
    end

    local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, target.mark, {})
    if not mark or #mark == 0 then
      return step()
    end

    client:request("textDocument/completion", {
      textDocument = vim.lsp.util.make_text_document_params(buf),
      position = lsp_position(buf, mark[1], mark[2], client.offset_encoding),
    }, function(err, result)
      if err or not result then
        failed[#failed + 1] = target.name
        return next_step()
      end

      local item, count = pick_import_item(result.items or result, target.name)
      if not item then
        failed[#failed + 1] = target.name
        return next_step()
      end
      if count > 1 then
        ambiguous[#ambiguous + 1] = target.name
      end

      -- The import edit only exists after resolve.
      client:request("completionItem/resolve", item, function(resolve_err, resolved)
        local edits = resolved and resolved.additionalTextEdits
        if resolve_err or not edits or #edits == 0 then
          failed[#failed + 1] = target.name
          return next_step()
        end
        vim.lsp.util.apply_text_edits(edits, buf, client.offset_encoding)
        added[#added + 1] = target.name
        next_step()
      end, buf)
    end, buf)
  end

  step()
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsc = {
          keys = {
            {
              "<leader>cM",
              add_missing_imports,
              desc = "Add missing imports",
            },
            {
              -- tsc's kind is `source.removeUnusedImports`, not vtsls'
              -- `source.removeUnused.ts`.
              "<leader>cu",
              LazyVim.lsp.action["source.removeUnusedImports"],
              desc = "Remove unused imports",
            },
            {
              "<leader>co",
              LazyVim.lsp.action["source.organizeImports"],
              desc = "Organize imports",
            },
            {
              "<leader>cS",
              LazyVim.lsp.action["source.sortImports"],
              desc = "Sort imports",
            },
          },
        },
      },
    },
  },
}
