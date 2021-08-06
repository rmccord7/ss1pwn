local max_text_end = 71
local comment_col_end = 73
local max_end_col = 81
local comment_start = "/*"
local comment_end = "*/"

local M = {}

--[Checks if the current line is a ss1 style comment. ]]
function M.test()
  print('test string')
end

--[Checks if the current line is a ss1 style comment. ]]
function M.is_comment(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  -- Return true if the line begins with a comment. Otherwise false.
  return line:sub(1, #comment_start) == comment_start
end

--[Checks if :he]]
function M.is_bad_comment(line)
  -- Find the offset of the comment end
  local line_col = string.find(line, comment_end)

  if line_col > comment_col_end then
    return true
  else
    return false
  end
end

--[Updates cursor position to next comment that needs to be formatted. ]]
function M.next_bad_comment()
  local line_count                                = vim.api.nvim_buf_line_count(0)

  --Save the current cursor position.
  local previous_line_number, previous_col_number = unpack(vim.api.nvim_win_get_cursor(0))
  local current_line_number                       = previous_line_number

  -- If we have not reached eof.
  while current_line_number ~= line_count do

    --Get current line (API zero indexed).
    local line = vim.api.nvim_buf_get_lines(0, current_line_number-1, current_line_number, false)[1]

    --If the current line is a comment.
    if M.is_comment(line) then

      --If this is a bad comment.
      if M.is_bad_comment(line) then
        -- Find the offset of the comment start. This offset is
        -- the actual comment string not the delimiter.
        local line_col = string.find(line, comment_start, 1, true) + #comment_start

        -- Update the cursor position at beginning of the comment text.
        vim.api.nvim_win_set_cursor(0, {current_line_number, line_col})

        -- Set starting and end line numbers for visually selecting
        -- the comment block.
        local line_start = current_line_number - 1
        local line_end   = current_line_number + 1

        -- Find the start of the comment block.
        while line_start ~= 0 do
          -- Get the current line.
          line = vim.api.nvim_buf_get_lines(0, line_start-1, line_start, false)[1]

          -- If this line is not a comment, then the next line
          -- is the start of the comment block.
          if not M.is_comment(line) then
            line_start = line_start + 1
            break
          end

          line_start = line_start - 1;
        end

        -- Find the end of the comment block.
        while line_end ~= line_count do
          -- Get the current line.
          line = vim.api.nvim_buf_get_lines(0, line_end-1, line_end, false)[1]

          -- If this line is not a comment, then the previous line
          -- is the end of the comment block.
          if not M.is_comment(line) then
            line_end = line_end - 1
            break
          end

          line_end = line_end + 1;
        end

        local key_string = string.format("%dGV%dG", line_start, line_end)

        -- Visually select the comment block
        vim.api.nvim_feedkeys(key_string, 'n', false)

        break
      end
    end

    --Get next line.
    current_line_number = current_line_number + 1;
  end
end

--[Formats the comment. ]]
function M.format_comment()
  result = {}

  -- Get the visual selection
  line_number_start = vim.fn.getpos('v')[2]
  line_number_end   = vim.fn.getcurpos()[2]

  -- If the visual selection start is not in order of
  -- increasing line order swap them. This may happen if
  -- the user explicitly make the visual selection.
  if line_number_start > line_number_end then
    line_number_start, line_number_end = line_number_end, line_number_start
  end

  -- Get the lines from the selection (API zero indexed).
  local lines = vim.api.nvim_buf_get_lines(0, line_number_start-1, line_number_end, false)

  -- Save the indent level.
  local indent        = string.find(lines[1], "%S") - 1
  local indent_string = string.sub(lines[1], 1, indent)

  -- Remove comment delimeters
  local new_line
  for _, line in ipairs(lines) do

    -- Remove indent and trailing white space.
    new_line    = vim.trim(line)

    -- Remove the comment prefix.
    new_line, _ = string.gsub(new_line, vim.pesc(comment_start) .. "%s?", "", 1)

    -- Remove the comment suffix.
    new_line, _ = string.sub(new_line, 1, -#comment_end - 1)

    table.insert(result, new_line)
  end

  -- Update the lines.
  vim.api.nvim_buf_set_lines(0, line_number_start-1, line_number_end, false, result)

  -- Save the current text width.
  local textwidth = vim.api.nvim_buf_get_option(0, "textwidth")

  -- Reflow the text and account for the current indentation that
  -- was removed
  vim.api.nvim_buf_set_option(0, "textwidth", max_text_end - indent)

  vim.api.nvim_feedkeys("gq", 'x', false)

  -- Restore the text width.
  vim.api.nvim_buf_set_option(0, "textwidth", textwidth)

  do return end

  -- Select the text from the previous format.
  vim.api.nvim_feedkeys("'[V']", 'x', false)

  -- Get the visual selection. This will be in the correct
  -- order so we don't need to swap these.
  line_number_start = vim.fn.getpos('v')[2]
  line_number_end   = vim.fn.getcurpos()[2]

  -- Get the lines from the selection (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, line_number_start-1, line_number_end, false)

  -- Add the indentation and comment delimeters
  result = {}
  local padding
  for _, line in ipairs(lines) do
    -- Calculate the padding till the end of line delimiter.
    padding = max_text_end - #indent_string - #comment_start - 1 - #line + 1

    -- Format the line.
    new_line = indent_string .. comment_start .. ' ' .. line .. string.rep(' ', padding) .. comment_end

    table.insert(result, new_line)
  end

  -- Update the lines.
  vim.api.nvim_buf_set_lines(0, line_number_start-1, line_number_end, false, result)
end

return M
