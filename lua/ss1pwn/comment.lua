local comment_col_max = 72
local comment_delim_col_start = 73
local comment_start = "/*"
local comment_end = "*/"
local note_comment = "* NOTE *"
local note_comment_indent = #comment_start + 1 + #note_comment

local M = {}

-- Checks if the current line is a ss1 style comment.
local function is_comment(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  -- Return true if the line begins with a comment. Otherwise false.
  return line:sub(1, #comment_start) == comment_start
end

-- Checks if the current line is a ss1 style note comment. ]]
local function is_note_comment(line)

  -- Return true if the line has the note prefix. Otherwise false.
  return string.find(line, note_comment, 1, true)
end

-- Checks if the current line of the current comment is malformatted.
local function is_bad_comment(line)
  -- Find the offset of the comment end
  local line_col = string.find(line, comment_end)

  if line_col > comment_delim_col_start or line_col < comment_delim_col_start then
    return true
  else
    return false
  end
end

-- Reflows the text.
local function reflow_text(line_start, line_end, text_width)

  -- Visually select all lines in the range.
  vim.api.nvim_feedkeys(string.format("%dGV%dG", line_start, line_end) , 'x', false)

  -- Save options.
  local textwidth  = vim.api.nvim_buf_get_option(0, "textwidth")
  local smartindent = vim.api.nvim_buf_get_option(0, "smartindent")
  local autoindent  = vim.api.nvim_buf_get_option(0, "autoindent")
  local cindent     = vim.api.nvim_buf_get_option(0, "cindent")
  local smarttab    = vim.api.nvim_get_option("smarttab")
  local indentexpr  = vim.api.nvim_buf_get_option(0, "indentexpr")

  -- Set options for reflowing text.
  vim.api.nvim_buf_set_option(0, "textwidth", text_width)
  vim.api.nvim_buf_set_option(0, "smartindent", false)
  vim.api.nvim_buf_set_option(0, "autoindent", false)
  vim.api.nvim_buf_set_option(0, "cindent", false)
  vim.api.nvim_set_option("smarttab", false)
  vim.api.nvim_buf_set_option(0, "indentexpr", "")

  -- Reflow the text.
  vim.api.nvim_feedkeys("gq", 'x', false)

  -- Restore options.
  vim.api.nvim_buf_set_option(0, "textwidth", textwidth)
  vim.api.nvim_buf_set_option(0, "smartindent", smartindent)
  vim.api.nvim_buf_set_option(0, "autoindent", autoindent)
  vim.api.nvim_buf_set_option(0, "cindent", cindent)
  vim.api.nvim_set_option("smarttab", smarttab)
  vim.api.nvim_buf_set_option(0, "indentexpr", indentexpr)

  -- Visually Select the all lines from the reflow. More lines may have been
  -- added, but we can quickly re-select them.
  vim.api.nvim_feedkeys("'[V']", 'x', false)

  -- If additional lines were added, then we need to update the last line of
  -- the section. This will be in ascending order order so we don't need to
  -- swap these.
  line_end = vim.fn.getcurpos()[2]

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), 'x', false)

  -- Return the section line end so the caller knows if it changed.
  return line_end
end

-- Formats an ss1 normal comment section.
local function format_normal_section(section)

  local new_line
  local padding

  -- Save the indent level from the  current line.
  local indent        = string.find(section.lines[1], "%S") - 1
  local indent_string = string.sub(section.lines[1], 1, indent)

  -- Remove indentation, comment delimiters, and trailing white space from all
  -- section lines.
  local new_line
  local line_list = {}
  for _, line in ipairs(section.lines) do

    -- Remove indent and trailing white space.
    new_line = vim.trim(line)

    -- Remove the comment prefix.
    new_line, _ = string.gsub(new_line, vim.pesc(comment_start) .. "%s?", "", 1)

    -- Remove the comment suffix.
    new_line, _ = string.sub(new_line, 1, -#comment_end - 1)

    -- Remove all trailing space now that delimeters
    -- have been removed
    new_line = vim.trim(new_line)

    -- Store the modified line.
    table.insert(line_list, new_line)
  end

  -- Update the lines in the buffer (API zero indexed).
  vim.api.nvim_buf_set_lines(0, section.line_start-1, section.line_end, false, line_list)

  -- Reflow the text block. This function will return the new section line end
  -- if additional lines were added to the section due to the reflowing of the
  -- text.
  section.line_end = reflow_text(section.line_start, section.line_end, comment_col_max - indent - #comment_start - 1)

  -- Get the lines from the selection (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, section.line_start-1, section.line_end, false)

  -- Add comment delimeters back to the lines and return the update lines to
  -- the caller.
  section.updated_lines = {}

  for _, line in ipairs(lines) do
    -- Calculate the padding till the end of line delimiter.
    padding = comment_col_max - indent - #comment_start - 1 - #line

    -- Format the line.
    new_line = indent_string .. comment_start .. ' ' .. line .. string.rep(' ', padding) .. comment_end

    -- Add the line to the list.
    table.insert(section.updated_lines, new_line)
  end

end

-- Formats an ss1 note comment section.
local function format_note_section(section)

  local new_line
  local padding

  -- Save the indent level from the  current line.
  local indent        = string.find(section.lines[1], "%S") - 1
  local indent_string = string.sub(section.lines[1], 1, indent)

  -- Remove indentation, comment delimiters, and trailing white space from all
  -- section lines.
  local line_list = {}
  for index, line in ipairs(section.lines) do

    -- Remove indent and trailing white space.
    new_line = vim.trim(line)

    -- Remove the comment prefix.
    new_line, _ = string.gsub(new_line, vim.pesc(comment_start) .. "%s?", "", 1)

    -- Remove the note prefix.
    if index == 1 then
      --Extra space after the note prefix will be stripped below.
      new_line, _ = string.gsub(new_line, vim.pesc(note_comment) .. "%s?", "", 1)
    end

    -- Remove the comment suffix.
    new_line, _ = string.sub(new_line, 1, -#comment_end - 1)

    -- Remove all trailing space now that delimeters
    -- have been removed
    new_line = vim.trim(new_line)

    -- Store the modified line.
    table.insert(line_list, new_line)
  end

  -- Update the lines in the buffer.
  vim.api.nvim_buf_set_lines(0, section.line_start-1, section.line_end, false, line_list)

  -- Reflow the text block. This function will return the new section line end
  -- if additional lines were added to the section due to the reflowing of the
  -- text.
  section.line_end = reflow_text(section.line_start, section.line_end, comment_col_max - indent - #comment_start - #note_comment - 1 - 1)

  -- Get the lines from the selection (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, section.line_start-1, section.line_end, false)

  -- Add comment delimeters back to the lines and return the update lines to
  -- the caller.
  section.updated_lines = {}

  for index, line in ipairs(lines) do

    -- Calculate the padding till the end of line delimiter.
    padding = comment_col_max - indent - #comment_start - 1 - #note_comment - 1 - #line

    -- If this is the first line, then we need to add back the note prefix.
    if index == 1 then

      -- Format the line.
      new_line = indent_string .. comment_start .. ' ' .. note_comment .. ' ' .. line .. string.rep(' ', padding) .. comment_end
    else

      -- Format the line.
      new_line = indent_string .. comment_start .. string.rep(' ', #note_comment + 1) .. ' ' .. line .. string.rep(' ', padding) .. comment_end
    end

    -- Add the line to the list.
    table.insert(section.updated_lines, new_line)
  end

end

-- Visually selects the next bad comment from the current line. If the current
-- line is a bad comment, then that comment will be visually selected.
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
    if is_comment(line) then

      --If this is a bad comment.
      if is_bad_comment(line) then
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
          if not is_comment(line) then
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
          if not is_comment(line) then
            line_end = line_end - 1
            break
          end

          line_end = line_end + 1;
        end

        -- Visually select the comment block
        vim.api.nvim_feedkeys(string.format("%dGV%dG", line_start, line_end) , 'n', false)

        break
      end
    end

    --Get next line.
    current_line_number = current_line_number + 1;

  end

end

-- Formats an ss1 comment.
function M.format_comment(selection)

  -- Check if the caller defined the visual selection.
  local next = next

  selection = selection or {}
  if next(selection) == nil then

    -- Get the visual selection.
    selection.line_start = vim.fn.getpos('v')[2]
    selection.line_end   = vim.fn.getcurpos()[2]

    -- Clear the visual selection.
    vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), 'x', false)

    -- If the visual selection start is not in order of
    -- increasing line order swap them. This may happen if
    -- the user explicitly made the visual selection.
    if selection.line_start > selection.line_end then
      selection.line_start, selection.line_end = selection.line_end, selection.line_start
    end

    -- Get the lines from the selection (API zero indexed).
    selection.comment            = {}
    selection.comment.line_start = selection.line_start
    selection.comment.line_end   = selection.line_end
    selection.comment.lines      = vim.api.nvim_buf_get_lines(0, selection.line_start-1, selection.line_end, false)
  end

  -- Initialize the normal section that is going to be formatted. The comment
  -- section line end will be updated for each line until we find the end of
  -- the normal section. Note sections may follow the normal section and will
  -- follow the same process.
  local section         = {}
  section.line_start    = selection.comment.line_start
  section.line_end      = section.line_start
  section.updated_lines = {}
  section.note_section  = false

  -- Process the comment.
  for index, line in ipairs(selection.comment.lines) do

    -- If the current line is a comment.
    if is_comment(line) then

      -- Determine if we have reached the end of a section.  This will be the
      -- case if the current line is the last line, the next line is the start
      -- of a note section.
      if index == #selection.comment.lines or is_note_comment(selection.comment.lines[index+1]) then

        -- Get the lines for the section (API zero indexed).
        section.lines = vim.api.nvim_buf_get_lines(0, section.line_start-1, section.line_end, false)

        -- Format the current section.
        if section.note_section then
          format_note_section(section)
        else
          format_normal_section(section)
        end

        -- Update the buffer with the formatted lines. Any additional lines
        -- that were added due to text reflow will be inserted before the start
        -- of the next section. The current section line end has also been
        -- updated to reflect the additional lines that were added to the
        -- section.
        vim.api.nvim_buf_set_lines(0, section.line_start-1, section.line_end, false, section.updated_lines)

        -- If this isn't the last line in the selection.
        if index ~= #selection.comment.lines then

          -- If we are still processing the normal section.
          if not section.note_section then

            -- If the next section is a note section.
            if is_note_comment(selection.comment.lines[index+1]) then

              -- Flag that additional sections are note sections.
              section.note_section = true
            end
          end

        end

        -- If this is not the last line of the selection, then update the line
        -- start and line end for the next section.
        if index ~= #selection.comment.lines then

          -- Process the next section in the selection. The format functions
          -- already updated the section line end if additional lines were
          -- added to the section.
          section.line_start = section.line_end + 1
          section.line_end   = section.line_start

        end

      else

        -- Process the next line as part of the current section.
        section.line_end = section.line_end + 1

      end

    else

      -- Found a line in the selection that is not a comment we will terminate
      -- and not process the current section.  Any previous sections that were
      -- formatted up to this point will remain formatted.
      break
    end

  end

  -- Make sure the caller knows if the end of the comment block has changed.
  selection.comment.line_end = section.line_end

end

-- Formats all ss1 comments in the selection.
function M.format_all_comments()

  -- Get the visual selection.
  selection            = {}
  selection.line_start = vim.fn.getpos('v')[2]
  selection.line_end   = vim.fn.getcurpos()[2]

  -- Get the lines from the selection (API zero indexed).
  selection.lines = vim.api.nvim_buf_get_lines(0, selection.line_start-1, selection.line_end, false)

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), 'x', false)

  -- If the visual selection start is not in order of
  -- increasing line order swap them. This may happen if
  -- the user explicitly made the visual selection.
  if selection.line_start > selection.line_end then
    selection.line_start, selection.line_end = selection.line_end, selection.line_start
  end

  -- If this function is called, then the selection is the only comment that
  -- will be formatted.
  selection.comment             = {}
  selection.comment.line_start  = selection.line_start
  selection.comment.line_end    = selection.line_start
  selection.comment.bad_comment = false

  -- Neovim Lua currently only supports Lua 5.1.
  table.unpack = table.unpack or unpack

  -- Process the comment.
  index = 1
  while index <= #selection.lines do

    -- Get the current line.
    line = selection.lines[index]

    -- If the current line is a comment, then this is the start of a comment
    -- block.
    if is_comment(line) then

      -- Flag that we have not found a bad comment for the current comment
      -- block.
      selection.comment.bad_comment = false

      -- If the current line is a bad comment
      if is_bad_comment(line) then
        selection.comment.bad_comment = true
      end

      -- If this is not the last line, then we need to find the end of the
      -- comment block.
      if index ~= #selection.lines then

        -- Start with the next line and find the last line of the comment
        -- block.
        local lines = {table.unpack(selection.lines, index + 1)}

        for index2, line2 in ipairs(lines) do

          -- If the current line is a comment, then we have not found the end
          -- of the comment block.
          if is_comment(lines[index2]) then

            -- If the current line is a bad comment, then we need to flag it, but
            -- this not the end of the comment block so we need to continue
            -- looking for the end of the comment block.
            if is_bad_comment(line2) then

              selection.comment.bad_comment = true
            end

            -- Update the end of the comment block.
            selection.comment.line_end = selection.comment.line_end + 1

          else

            -- Store the current line end so that if additional lines are added
            -- we can determine how many were added. The format_comment function
            -- will update the line of the comment block if it changes.
            local NewLineCount = selection.comment.line_end

            -- Only format the comment block if we determined that it contains
            -- a line that is a bad comment.
            if selection.comment.bad_comment then

              -- Get the lines from the selection (API zero indexed).
              selection.comment.lines = vim.api.nvim_buf_get_lines(0, selection.comment.line_start-1, selection.comment.line_end, false)

              M.format_comment(selection)

              -- Set the number of lines that were added after the comment
              -- block was formatted.
              NewLineCount = selection.comment.line_end - NewLineCount

            end

            -- Since we processed additional lines we need to update the main
            -- loop to skip over lines that we already processed in the inner
            -- loop.
            index = index + index2

            -- If there are more lines in the visual selection, then there may
            -- be another comment block that needs to be formatted.
            if index ~= #selection.lines then

              -- Next comment block should start after the current line
              -- (non-comment) that was just processed and marked the end of
              -- the current comment block.
              selection.comment.line_start = selection.comment.line_end + 2
              selection.comment.line_end   = selection.comment.line_start
            end

            -- Continue processing lines in the visual selection.
            break

          end
        end
      else

        -- The line end for the comment block has already been set to start for
        -- this case.

        -- Only format the comment block if we determined that it is a bad
        -- comment.
        if selection.comment.bad_comment then

          -- Get the lines from the selection (API zero indexed).
          selection.comment.lines = vim.api.nvim_buf_get_lines(0, selection.comment.line_start-1, selection.comment.line_end, false)

          M.format_comment(selection)
        end
      end

    else

      -- Keep incrementing the next line as the comment start until we find a
      -- comment.
      selection.comment.line_start = selection.comment.line_start + 1
      selection.comment.line_end   = selection.comment.line_start

    end

    -- Get the next line in the visual selection.
    index = index + 1
  end
end

return M
