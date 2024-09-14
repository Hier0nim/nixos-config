local M = {}

M.is_windows = package.config:sub(1, 1) == "\\"

return M
