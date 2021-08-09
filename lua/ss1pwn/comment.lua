local max_text_end = 72
local comment_col_end = 73
local max_end_col = 81
local comment_start = "/*"
local comment_end = "*/"
local note_comment = "* NOTE *"
local note_comment_indent = #comment_start + 1 + #note_comment

local M = {}

-- Checks if the current line is a ss1 style comment.
function M.is_comment(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  -- Return true if the line begins with a comment. Otherwise false.
  return line:sub(1, #comment_start) == comment_start
end

-- Checks if the current line is a ss1 style note comment. ]]
function M.is_note_comment(line)

  -- Return true if the line has the note prefix. Otherwise false.
  return string.find(line, note_comment, 1, true)
end

-- Checks if the current line of the current comment is malformatted.
function M.is_bad_comment(line)
  -- Find the offset of the comment end
  local line_col = string.find(line, comment_end)

  if line_col > comment_col_end or line_col < comment_col_end then
    return true
  else
    return false
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

-- Formats an ss1 normal comment section.
function M.format_normal_section(section_line_start, section_line_end)

  -- Get the lines for the comment section (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, section_line_start-1, section_line_end, false)

  -- Save the indent level from the  current line.
  local indent        = string.find(lines[1], "%S") - 1
  local indent_string = string.sub(lines[1], 1, indent)

  -- Remove indentation, comment delimiters, and trailing white space from all
  -- section lines.
  local new_line
  local line_list = {}
  for _, line in ipairs(lines) do

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

  -- Update the lines in the buffer.
  vim.api.nvim_buf_set_lines(0, section_line_start-1, section_line_end, false, line_list)

  -- Save the current text width option.
  local textwidth = vim.api.nvim_buf_get_option(0, "textwidth")

  -- Visually select all lines in the comment section.
  vim.api.nvim_feedkeys(string.format("%dGV%dG", section_line_start, section_line_end) , 'n', false)

  -- Reflow the text and account for the current indentation that
  -- was removed. Also account for the mandatory space after the
  -- first delimeter.
  vim.api.nvim_buf_set_option(0, "textwidth", max_text_end - indent - #comment_start - 1)

  vim.api.nvim_feedkeys("gq", 'x', false)

  -- Restore the text width option.
  vim.api.nvim_buf_set_option(0, "textwidth", textwidth)

  -- Visually Select the all lines from the reflow. More lines may have been
  -- added, but we can quickly re-select them.
  vim.api.nvim_feedkeys("'[V']", 'x', false)

  -- Get the visual selection. This will be in ascending order order so we
  -- don't need to swap these.
  section_line_start = vim.fn.getpos('v')[2]
  section_line_end   = vim.fn.getcurpos()[2]

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), 'x', false)

  -- Get the lines from the selection (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, section_line_start-1, section_line_end, false)

  -- Add comment delimeters back to the lines.
  updated_lines = {}
  local padding

  for _, line in ipairs(lines) do
    -- Calculate the padding till the end of line delimiter.
    padding = max_text_end - indent - #comment_start - 1 - #line

    -- Format the line.
    new_line = indent_string .. comment_start .. ' ' .. line .. string.rep(' ', padding) .. comment_end

    -- Add the line to the list.
    table.insert(updated_lines, new_line)
  end

  -- Replace the lines in the buffer. This will insert any new lines before the
  -- lines that follow the current section end.
  vim.api.nvim_buf_set_lines(0, section_line_start-1, section_line_end, false, updated_lines)

  -- Section line end may have changed due to re-flowing the text, we will
  -- return the current value.
  return section_line_end
end

-- Formats an ss1 note comment section.
function M.format_note_section(section_line_start, section_line_end)

  -- Get the lines for the comment section (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, section_line_start-1, section_line_end, false)

  -- Save the indent level from the  current line.
  local indent        = string.find(lines[1], "%S") - 1
  local indent_string = string.sub(lines[1], 1, indent)

  -- Remove indentation, comment delimiters, and trailing white space from all
  -- section lines.
  local new_line
  local line_list = {}
  for index, line in ipairs(lines) do

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
  vim.api.nvim_buf_set_lines(0, section_line_start-1, section_line_end, false, line_list)

  -- Save the current text width option.
  local textwidth = vim.api.nvim_buf_get_option(0, "textwidth")

  -- Visually select all lines in the section.
  vim.api.nvim_feedkeys(string.format("%dGV%dG", section_line_start, section_line_end) , 'n', false)

  -- Reflow the text and account for the current indentation that
  -- was removed. Also account for the mandatory space after the
  -- first delimeter and the space after the note prefix.
  vim.api.nvim_buf_set_option(0, "textwidth", max_text_end - indent - #comment_start - #note_comment - 1 - 1)

  vim.api.nvim_feedkeys("gq", 'x', false)

  -- Restore the text width option.
  vim.api.nvim_buf_set_option(0, "textwidth", textwidth)

  -- Visually Select the all lines from the reflow. More lines may have been
  -- added, but we can quickly re-select them.
  vim.api.nvim_feedkeys("'[V']", 'x', false)

  -- Get the visual selection. This will be in ascending order order so we
  -- don't need to swap these.
  section_line_start = vim.fn.getpos('v')[2]
  section_line_end   = vim.fn.getcurpos()[2]

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), 'x', false)

  -- Get the lines from the selection (API zero indexed).
  lines = vim.api.nvim_buf_get_lines(0, section_line_start-1, section_line_end, false)

  -- Add comment delimeters back to the lines.
  updated_lines = {}
  local padding

  for index, line in ipairs(lines) do

    -- If this is the first line, then we need to add back the note prefix.
    if index == 1 then

      -- Calculate the padding till the end of line delimiter.
      padding = max_text_end - indent - #comment_start - 1 - #note_comment - 1 - #line

      -- Format the line.
      new_line = indent_string .. comment_start .. ' ' .. note_comment .. ' ' .. line .. string.rep(' ', padding) .. comment_end
    else

      -- Calculate the padding till the end of line delimiter.
      padding = max_text_end - indent - #comment_start - 1 - #note_comment - 1 - #line

      -- Format the line.
      new_line = indent_string .. comment_start .. string.rep(' ', #note_comment + 1) .. ' ' .. line .. string.rep(' ', padding) .. comment_end
    end

    -- Add the line to the list.
    table.insert(updated_lines, new_line)
  end

  -- Replace the lines in the buffer. This will insert any new lines before the
  -- lines that follow the current section end.
  vim.api.nvim_buf_set_lines(0, section_line_start-1, section_line_end, false, updated_lines)

  -- Section line end may have changed due to re-flowing the text, we will
  -- return the current value.
  return section_line_end
end

-- Formats an ss1 comment.
function M.format_comment()

  -- Get the visual selection.
  local line_number_start = vim.fn.getpos('v')[2]
  local line_number_end   = vim.fn.getcurpos()[2]

  -- Get the lines from the selection (API zero indexed).
  local lines = vim.api.nvim_buf_get_lines(0, line_number_start-1, line_number_end, false)

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), 'x', false)

  -- If the visual selection start is not in order of
  -- increasing line order swap them. This may happen if
  -- the user explicitly make the visual selection.
  if line_number_start > line_number_end then
    line_number_start, line_number_end = line_number_end, line_number_start
  end

  -- Store the current comment section that is going to
  -- be formatted.
  local section_line_start = line_number_start
  local section_line_end   = line_number_start

  -- Note comment sections follow a normal comment section. That is we will
  -- always have one normal comment section and 0 - N note comment sections
  -- after the normal comment section. Therefore, we will simply flag that we
  -- are starting with a normal comment section.
  local is_note_section = false

  -- Process all lines in the visual selection.
  local new_line
  local current_section_end
  for index, line in ipairs(lines) do

    -- Each line in the visual selection should be a comment. Terminate if this
    -- is not the case.
    if not M.is_comment(line) then
      -- This may occur if the user explicitly selected other lines besides the
      -- comment.
      return
    end

    -- If this is the last line from the visual selection, then the current
    -- line is the end of the current comment section.
    if index == #lines then

      -- Determine the current comment section is a note section or normal
      -- section.
      if is_note_section then
        M.format_note_section(section_line_start, section_line_end)
      else
        M.format_normal_section(section_line_start, section_line_end)
      end

    else

      -- If the current line is the start of a note section then we can process
      -- the previous section. Otherwise, we can continue processing lines
      -- since there are more lines to process.
      if M.is_note_comment(line) then

        -- If the current comment section is a note section
        if is_note_section then

          -- Format the note section.  If the current line is a note comment,
          -- then the previous line marks the end of the comment section.
          current_section_end = M.format_note_section(section_line_start, section_line_end - 1)

        else

          -- Format the normal section before the first note comment section.
          current_section_end = M.format_normal_section(section_line_start, section_line_end - 1)
        end

        -- The format may have added new lines after the text was reflowed. If
        -- this is the case, then the formatted section has been inserted
        -- before the current line. This means that in the buffer, the current
        -- line number has increased due to the inserted lines. Section line
        -- end is currently set to current line, which is the start of the new
        -- section.
        if current_section_end == section_line_end - 1 then
          section_line_start = section_line_end + 1
        else
          section_line_start = current_section_end + 1
          section_line_end   = section_line_start
        end

        -- Flag that we started processing a note section.
        is_note_section = true
      end
    end

    -- Update the last line of the section to the next line.
    section_line_end = section_line_end + 1

  end

end

return M
