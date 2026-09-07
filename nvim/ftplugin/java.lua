local jdtls = require 'jdtls'
local mason_path = vim.fn.stdpath 'data' .. '/mason'
local jdtls_path = mason_path .. '/packages/jdtls'
local launcher   = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')

local os_config
if vim.fn.has 'mac' == 1 then os_config = 'mac'
elseif vim.fn.has 'unix' == 1 then os_config = 'linux'
else os_config = 'win' end

-- your version's Java detection — keep all of it
local java_homes = {
  [17] = '/usr/lib/jvm/java-17-openjdk-amd64',
  [21] = '/usr/lib/jvm/java-21-openjdk-amd64',
  [25] = '/usr/lib/jvm/temurin-25-jdk-amd64',
}
local function get_spring_boot_default(pom)
  for line in io.lines(pom) do
    local version = line:match '<parent>.-<version>(%d+)%.'
    if version then
      local major = tonumber(version)
      if major >= 4 then return 21 end
      if major >= 3 then return 17 end
    end
  end
end
local function get_java_version()
  local pom = vim.fn.getcwd() .. '/pom.xml'
  if vim.fn.filereadable(pom) == 0 then return 21 end
  for line in io.lines(pom) do
    local v = line:match '<java%.version>(%d+)</java%.version>'
           or line:match '<java%.release>(%d+)</java%.release>'
           or line:match '<maven%.compiler%.source>(%d+)</maven%.compiler%.source>'
    if v then return tonumber(v) end
  end
  return get_spring_boot_default(pom) or 21
end

local java_version = get_java_version()
local java_home    = java_homes[java_version] or java_homes[21]
local root_dir     = jdtls.setup.find_root { 'pom.xml', 'build.gradle', '.git' }
local workspace    = vim.fn.stdpath 'data' .. '/jdtls-workspace/' .. vim.fn.fnamemodify(root_dir, ':t')

-- DAP bundles (only load if mason packages exist)
local bundles = {}
vim.list_extend(bundles, vim.split(
  vim.fn.glob(mason_path .. '/packages/java-debug-adapter/extension/server/*.jar'), '\n', { trimempty = true }
))
vim.list_extend(bundles, vim.split(
  vim.fn.glob(mason_path .. '/packages/vscode-java-test/extension/server/*.jar'), '\n', { trimempty = true }
))

jdtls.start_or_attach {
  cmd = {
    java_home .. '/bin/java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Xmx2g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens', 'java.base/java.util=ALL-UNNAMED',
    '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
    '-jar', launcher,
    '-configuration', jdtls_path .. '/config_' .. os_config,  -- required
    '-data', workspace,
  },
  root_dir = root_dir,
  init_options = { bundles = bundles },
  settings = {
    java = {
      signatureHelp    = { enabled = true },
      inlayHints       = { parameterNames = { enabled = 'all' } },
      implementationsCodeLens = { enabled = true },
      maven            = { downloadSources = true },
      eclipse          = { downloadSources = true },
      configuration = {
        updateBuildConfiguration = 'interactive',
        runtimes = {
          { name = 'JavaSE-17', path = java_homes[17] },
          { name = 'JavaSE-21', path = java_homes[21] },
          { name = 'JavaSE-25', path = java_homes[25] },
        },
      },
      sources = {
        organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
      },
    },
  },
  on_attach = function(_, bufnr)
    local map = function(k, f, d, m)
      vim.keymap.set(m or 'n', k, f, { buffer = bufnr, desc = 'Java: ' .. d })
    end
    map('<leader>ji', jdtls.organize_imports,  'Organize imports')
    map('<leader>jv', jdtls.extract_variable,  'Extract variable')
    map('<leader>jv', function() jdtls.extract_variable(true) end, 'Extract variable', 'v')
    map('<leader>jc', jdtls.extract_constant,  'Extract constant')
    map('<leader>jm', function() end,           'Extract method (visual only)')
    vim.keymap.set('v', '<leader>jm', function() jdtls.extract_method(true) end,
      { buffer = bufnr, desc = 'Java: Extract method' })
    map('<leader>jt', jdtls.test_nearest_method, 'Run nearest test')
    map('<leader>jT', jdtls.test_class,           'Run test class')
    jdtls.setup_dap { hotcodereplace = 'auto' }
    jdtls.setup.add_commands()
  end,
}
