import os, terminal, tables, strformat, strutils, parsecfg, parseopt
import oblivion/[utils, process]

let
  xdg = getConfigDir()
  cfgdir = xdg / "oblivion"
  cfgfile = cfgdir / "config.ini"

if not dirExists(xdg):
  error("Env var 'XDG_CONFIG_DIRS' points to non-existent directory")
  quit QuitFailure

# Find config file
if not dirExists(cfgdir):
  try:
    createDir(cfgdir)
    note(fmt"Created dir: {cfgdir}")
  except:
    error(fmt"Could not create dir: {cfgdir}")
    quit QuitFailure

if not fileExists(cfgfile):
  try: 
    writeFile(cfgfile, "")
    note(fmt"Created empty file: {cfgfile}")
  except:
    error(fmt"Could not file: {cfgdir}")
    quit QuitFailure

# Parse config file
let cfg = loadConfig(cfgfile)

proc findGroup(arg: string): string =
  var matches = newSeq[string]()
  for g in cfg.keys:
    if g.startsWith(arg):
      matches.add(g)
  case matches.len
  of 0:
    error("Group not found")
    quit QuitFailure
  of 1:
    result = matches[0]
  else:
    error("Ambiguous group match:")
    for m in matches:
      echo "  " & colored(m, fgYellow)
    quit QuitFailure

proc findAlias(group, arg: string): tuple[alias, cmd: string] =
  var matches = initTable[string, string]()

  # Exact match
  if cfg.contains(group):
    if cfg[group].contains(arg):
      return (arg, cfg[group][arg])

  for alias, cmd in cfg[group]:
    if alias.startsWith(arg):
      matches[alias] = cmd
  case matches.len
  of 0:
    error("Alias not found")
    quit QuitFailure
  of 1:
    for k, v in matches.pairs:
      result = (k, v)
  else:
    error("Ambiguous alias match:")
    for alias, cmds in matches.pairs:
      echo "  " & colored(alias, fgYellow)
    quit QuitFailure

proc printGroup(group: string) =
  for alias, cmd in cfg[group]:
    echo fmt"  {alias:<10}" & styled("| ", styleBright, fgYellow) & pretty(cmd)

if paramCount() == 0:
  echo "Available groups:"
  for g in cfg.keys:
    echo "  " & styled(g, styleBright, fgYellow)
  quit QuitSuccess

let g = findGroup(paramStr(1))

if paramCount() == 1:
  printGroup(g)
  quit QuitSuccess

var (alias, cmd) = findAlias(g, paramStr(2))

# Check if arguments match parameters
if countParams(cmd) != paramCount() - 2:
  error("Number of arguments don't match number of parameters of chosen command")
  quit QuitFailure
cmd = substitute(cmd)

echo colored("= ", fgBlue) & pretty(cmd)
let ret = execShellCmd(cmd)
if ret != 0:
  quit QuitFailure
