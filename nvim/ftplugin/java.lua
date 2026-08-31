local jdtls = require 'jdtls'

local mason_path = vim.fn.stdpath 'data' .. '/mason'
local jdtls_path = mason_path .. '/packages/jdtls'
local launcher = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')

local java_homes = {
  [17] = '/usr/lib/jvm/java-17-openjdk-amd64',
  [21] = '/usr/lib/jvm/java-21-openjdk-amd64',
  [25] = '/usr/lib/jvm/temurin-25-jdk-amd64',
}

local function get_spring_boot_default(pom)
  for line in io.lines(pom) do
    local version = line:match('<parent>.-<version>(%d+)%.', 1)
    if version then
      local major = tonumber(version)
      if major >= 4 then return 21 end
      if major >= 3 then return 17 end
    end
  end
  return nil
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
local java_home = java_homes[java_version] or java_homes[21]

local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
local workspace = vim.fn.stdpath 'data' .. '/jdtls-workspace/' .. project_name

jdtls.start_or_attach {
  cmd = {
    java_home .. '/bin/java',
    '-jar', launcher,
    '-data', workspace,
  },
  root_dir = jdtls.setup.find_root { 'pom.xml', 'build.gradle', '.git' },
  settings = {
    java = {
      completion = { enabled = true },
      signatureHelp = { enabled = true },
      configuration = {
        runtimes = {
          { name = 'JavaSE-17', path = java_homes[17] },
          { name = 'JavaSE-21', path = java_homes[21] },
          { name = 'JavaSE-25', path = java_homes[25] },
        },
      },
    },
  },
}
