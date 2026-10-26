## API reference generator.
##
## Regenerates `docs/API.md` from the public symbols of the library. The compiler supplies the
## documentation through `nim jsondoc`; this script merges the modules and renders Markdown.
##
## Run it with `nimble apiDocs`, or directly with `nim r tools/gen_api_docs.nim`. Pass `--check` to
## verify that the committed file is current without rewriting it.

import std/[algorithm, json, os, osproc, sequtils, strformat, strutils, tables]

const
  RepoRoot = parentDir(parentDir(currentSourcePath())) ## Package root, resolved at compile time.
  SrcDir = RepoRoot / "src" ## Import root handed to the compiler.
  DefaultOutFile = RepoRoot / "docs" / "API.md" ## Default Markdown destination.
  SignatureWidth = 100 ## Column where a signature moves its parameters to separate lines.
  SectionTitles = [
    "Overview",
    "Core types",
    "Model and format",
    "Elements",
    "Serialization",
    "Byte-level primitives"
  ] ## Document sections, rendered in this order.
  CategoryOrder = [
    "Types",
    "Constants",
    "Variables",
    "Procedures",
    "Operators",
    "Iterators",
    "Templates",
    "Macros",
    "Converters"
  ] ## Subsections inside a module, rendered in this order.

type
  ModuleSpec = object
    key: string ## Anchor prefix, unique across the reference.
    path: string ## Module path under `src`, without the extension.
    section: string ## Section title the module is listed under.

  Symbol = object
    name: string ## Exported name, with backticks for operators.
    kind: string ## Compiler category, such as `skProc`.
    code: string ## Rendered declaration, as the compiler prints it.
    description: string ## ReStructuredText rendered to HTML by the compiler.
    line: int ## First source line of the declaration.
    paramNames: seq[string] ## Parameter names, used to detect repeated declarations.
    paramTypes: seq[string] ## Declared parameter types, empty when inferred from a default.

  SymbolGroup = object
    name: string ## Shared name of every overload in the group.
    kind: string ## Compiler category shared by the group.
    members: seq[Symbol] ## Distinct signatures, in source order.

  ModuleData = object
    spec: ModuleSpec ## Manifest entry that produced this data.
    description: string ## Module docstring rendered to HTML.
    groups: seq[SymbolGroup] ## Public symbols, already grouped.

const
  Modules = [
    ModuleSpec(key: "pmxforge", path: "pmxforge", section: "Overview"),
    ModuleSpec(key: "vectors", path: "pmxforge/core/vectors", section: "Core types"),
    ModuleSpec(key: "colors", path: "pmxforge/core/colors", section: "Core types"),
    ModuleSpec(key: "model", path: "pmxforge/format/model", section: "Model and format"),
    ModuleSpec(key: "enums", path: "pmxforge/format/enums", section: "Model and format"),
    ModuleSpec(key: "flags", path: "pmxforge/format/flags", section: "Model and format"),
    ModuleSpec(key: "limits", path: "pmxforge/format/limits", section: "Model and format"),
    ModuleSpec(key: "errors", path: "pmxforge/format/errors", section: "Model and format"),
    ModuleSpec(key: "texture", path: "pmxforge/format/elements/texture", section: "Elements"),
    ModuleSpec(key: "vertex", path: "pmxforge/format/elements/vertex", section: "Elements"),
    ModuleSpec(key: "face", path: "pmxforge/format/elements/face", section: "Elements"),
    ModuleSpec(key: "material", path: "pmxforge/format/elements/material", section: "Elements"),
    ModuleSpec(key: "bone", path: "pmxforge/format/elements/bone", section: "Elements"),
    ModuleSpec(key: "morph", path: "pmxforge/format/elements/morph", section: "Elements"),
    ModuleSpec(key: "display_slot", path: "pmxforge/format/elements/display_slot", section: "Elements"),
    ModuleSpec(key: "rigid_body", path: "pmxforge/format/elements/rigid_body", section: "Elements"),
    ModuleSpec(key: "joint", path: "pmxforge/format/elements/joint", section: "Elements"),
    ModuleSpec(key: "soft_body", path: "pmxforge/format/elements/soft_body", section: "Elements"),
    ModuleSpec(key: "validation", path: "pmxforge/format/validation", section: "Serialization"),
    ModuleSpec(key: "reader", path: "pmxforge/format/io/reader", section: "Serialization"),
    ModuleSpec(key: "writer", path: "pmxforge/format/io/writer", section: "Serialization"),
    ModuleSpec(key: "binary", path: "pmxforge/format/io/binary", section: "Byte-level primitives"),
    ModuleSpec(key: "text_codec", path: "pmxforge/format/io/text_codec", section: "Byte-level primitives"),
    ModuleSpec(
      key: "file_metadata",
      path: "pmxforge/format/io/file_metadata",
      section: "Byte-level primitives"
    )
  ] ## Public modules, in reading order.

proc fail(message: string) {.noreturn.} =
  ## Reports a generator problem on stderr and exits with a failure code.
  stderr.writeLine fmt"error: {message}"
  quit(1)

proc compilerPath(): string =
  ## Returns the Nim compiler to invoke, honoring the `NIM` environment variable.
  let override = getEnv("NIM")
  if override.len > 0:
    return override
  result = findExe("nim")
  if result.len == 0:
    fail "nim is not on PATH; install Nim or set NIM to the compiler executable."

proc packageVersion(): string =
  ## Reads the `version` field of the package manifest.
  let manifest = RepoRoot / "pmxforge.nimble"
  if not fileExists(manifest):
    fail fmt"missing package manifest '{manifest}'"
  for line in lines(manifest):
    let trimmed = line.strip
    if not trimmed.startsWith("version"):
      continue
    let parts = trimmed.split('=', 1)
    if parts.len == 2:
      return parts[1].strip.strip(chars = {'"', '\''})
  fail fmt"cannot read the version from '{manifest}'"

proc outputPath(raw: string): string =
  ## Resolves an output path without requiring it to exist. `expandFilename` raises for a
  ## missing target on some Nim versions, which made `--out:<new file>` unusable.
  if raw.len == 0:
    fail "the output path must not be empty"
  if isAbsolute(raw):
    normalizedPath(raw)
  else:
    normalizedPath(getCurrentDir() / raw)

proc runJsonDoc(compiler: string; module: ModuleSpec; outDir: string): JsonNode =
  ## Asks the compiler for one module's documentation and parses the JSON it writes.
  let source = SrcDir / module.path.addFileExt("nim")
  if not fileExists(source):
    fail fmt"missing source file '{source}'"
  let arguments = @[
    compiler,
    "jsondoc",
    "--hints:off",
    "--warnings:off",
    "--path:" & SrcDir,
    "--outdir:" & outDir,
    source
  ]
  let command = arguments.mapIt(quoteShell(it)).join(" ")
  let (output, status) = execCmdEx(command, options = {poUsePath, poStdErrToStdOut})
  if status != 0:
    fail fmt"jsondoc failed for '{module.path}':" & "\n" & output.strip
  let jsonPath = outDir / (splitFile(source).name & ".json")
  if not fileExists(jsonPath):
    fail fmt"jsondoc wrote no JSON for '{module.path}':" & "\n" & output.strip
  result = parseFile(jsonPath)

proc toSymbol(node: JsonNode): Symbol =
  ## Converts one `jsondoc` entry into the internal record.
  result.name = node["name"].getStr
  result.kind = node["type"].getStr
  result.code = node["code"].getStr
  result.description = node{"description"}.getStr
  result.line = node{"line"}.getInt
  let signature = node{"signature"}
  if signature != nil:
    let arguments = signature{"arguments"}
    if arguments != nil:
      for argument in arguments:
        result.paramNames.add argument["name"].getStr
        result.paramTypes.add argument{"type"}.getStr

proc collectSymbols(node: JsonNode): seq[Symbol] =
  ## Converts every documented entry of one module.
  let entries = node{"entries"}
  if entries == nil:
    return
  for entry in entries:
    result.add toSymbol(entry)

proc decodeEntities(text: string): string =
  ## Replaces the HTML entities the compiler emits in doc comments.
  result = text
  result = result.replace("&quot;", "\"")
  result = result.replace("&#39;", "'")
  result = result.replace("&apos;", "'")
  result = result.replace("&lt;", "<")
  result = result.replace("&gt;", ">")
  result = result.replace("&nbsp;", " ")
  result = result.replace("&amp;", "&")

proc elementName(tag: string): string =
  ## Returns the lower-case element name of a raw tag such as `/p` or `pre class="listing"`.
  var start = 0
  if tag.len > 0 and tag[0] == '/':
    start = 1
  var stop = start
  while stop < tag.len and tag[stop].isAlphaNumeric:
    inc stop
  tag[start ..< stop].toLowerAscii

proc isClosing(tag: string): bool =
  ## Returns true when the raw tag closes an element.
  tag.len > 0 and tag[0] == '/'

proc attributeValue(tag, attribute: string): string =
  ## Returns one quoted HTML attribute, or "" when the tag does not carry it.
  let marker = attribute & "=\""
  let start = tag.find(marker)
  if start < 0:
    return ""
  let first = start + marker.len
  let stop = tag.find('"', first)
  if stop < 0:
    return ""
  tag[first ..< stop]

proc stripTags(html: string): string =
  ## Removes every tag while keeping the text, and decodes entities.
  var index = 0
  while index < html.len:
    if html[index] == '<':
      let close = html.find('>', index)
      if close < 0:
        break
      index = close + 1
    else:
      let next = html.find('<', index)
      let stop = if next < 0: html.len else: next
      result.add decodeEntities(html[index ..< stop])
      index = stop

proc tidy(text: string): string =
  ## Drops repeated blank lines and trailing spaces while keeping code indentation.
  var lines: seq[string]
  var pendingBlank = false
  for line in text.splitLines():
    let trimmed = line.strip(leading = false, trailing = true)
    if trimmed.len == 0:
      pendingBlank = true
      continue
    if pendingBlank and lines.len > 0:
      lines.add ""
    pendingBlank = false
    lines.add trimmed
  lines.join("\n")

proc htmlToMarkdown(html: string): string =
  ## Converts the HTML emitted by `jsondoc` into Markdown paragraphs, lists, and fenced code.
  if html.len == 0:
    return ""
  var openLinks: seq[string]
  var index = 0
  while index < html.len:
    let tagStart = html.find('<', index)
    if tagStart < 0:
      result.add decodeEntities(html[index .. ^1])
      break
    if tagStart > index:
      result.add decodeEntities(html[index ..< tagStart])
    let tagStop = html.find('>', tagStart)
    if tagStop < 0:
      break
    let tag = html[tagStart + 1 ..< tagStop]
    index = tagStop + 1
    let name = elementName(tag)
    let closing = isClosing(tag)
    if name == "pre" and not closing:
      let blockEnd = html.find("</pre>", index)
      let snippet = if blockEnd < 0: html[index .. ^1] else: html[index ..< blockEnd]
      let language = if snippet.contains("<span"): "nim" else: ""
      result.add "\n\n```" & language & "\n" & stripTags(snippet).strip & "\n```\n\n"
      index = if blockEnd < 0: html.len else: blockEnd + "</pre>".len
      continue
    case name
    of "p":
      result.add "\n\n"
    of "br":
      result.add "\n"
    of "tt", "code":
      result.add "`"
    of "b", "strong":
      result.add "**"
    of "i", "em":
      result.add "*"
    of "li":
      if not closing:
        result.add "\n- "
    of "ul", "ol":
      result.add "\n"
    of "a":
      if closing:
        let target = if openLinks.len > 0: openLinks.pop() else: ""
        result.add "](" & target & ")"
      else:
        openLinks.add attributeValue(tag, "href")
        result.add "["
    else:
      discard
  result = tidy(result)

proc splitTopLevel(text: string; separators: set[char]): seq[string] =
  ## Splits `text` on `separators` found outside brackets and string literals.
  var depth = 0
  var current = ""
  var quoted = false
  var index = 0
  while index < text.len:
    let character = text[index]
    if quoted:
      current.add character
      if character == '\\' and index + 1 < text.len:
        inc index
        current.add text[index]
      elif character == '"':
        quoted = false
    else:
      case character
      of '"':
        quoted = true
        current.add character
      of '(', '[', '{':
        inc depth
        current.add character
      of ')', ']', '}':
        dec depth
        current.add character
      else:
        if depth == 0 and character in separators:
          result.add current.strip
          current = ""
        else:
          current.add character
    inc index
  result.add current.strip
  result.keepItIf(it.len > 0)

proc mergeNameGroups(parameters: seq[string]): seq[string] =
  ## Re-attaches bare names such as `a, b` to the declaration that gives them a type.
  var pending = ""
  for parameter in parameters:
    pending = if pending.len == 0: parameter else: pending & ", " & parameter
    if ':' in parameter or '=' in parameter:
      result.add pending
      pending = ""
  if pending.len > 0:
    result.add pending

proc stripPragmas(code: string): string =
  ## Removes the compiler-generated `tags`, `forbids`, and empty `raises` pragmas.
  let start = code.rfind("{.")
  if start < 0 or not code.endsWith(".}"):
    return code
  let declaration = code[0 ..< start].strip
  let body = code[start + 2 ..< code.len - 2]
  var kept: seq[string]
  for pragma in splitTopLevel(body, {','}):
    let trimmed = pragma.strip
    if trimmed.len == 0 or trimmed.startsWith("tags:") or trimmed.startsWith("forbids:"):
      continue
    if trimmed == "raises: []" or trimmed == "inline":
      continue
    kept.add trimmed
  if kept.len == 0:
    return declaration
  declaration & " {." & kept.join(", ") & ".}"

proc normalizeSignature(code: string): string =
  ## Collapses a documented signature to one or more lines without compiler pragma noise.
  var text = code.splitLines().mapIt(it.strip).join(" ")
  text = text.strip
  let openParen = text.find('(')
  if openParen < 0:
    return stripPragmas(text).strip
  var depth = 0
  var closeParen = -1
  var quoted = false
  var index = openParen
  while index < text.len:
    let character = text[index]
    if quoted:
      if character == '\\':
        inc index
      elif character == '"':
        quoted = false
    else:
      case character
      of '"':
        quoted = true
      of '(':
        inc depth
      of ')':
        dec depth
        if depth == 0:
          closeParen = index
          break
      else:
        discard
    inc index
  if closeParen < 0:
    return stripPragmas(text).strip
  let prefix = text[0 .. openParen]
  let tail = stripPragmas(text[closeParen .. ^1])
  let parameters = mergeNameGroups(splitTopLevel(text[openParen + 1 ..< closeParen], {',', ';'}))
  if parameters.len == 0:
    return stripPragmas(text).strip
  let single = prefix & parameters.join(", ") & tail
  if single.len <= SignatureWidth:
    return single
  result = prefix & "\n"
  for position, parameter in parameters:
    result.add "  " & parameter
    if position < parameters.high:
      result.add ","
    result.add "\n"
  result.add tail

proc isOperatorName(name: string): bool =
  ## Returns true when the exported name is a symbolic operator rather than an identifier.
  var bare = name
  if bare.len >= 2 and bare[0] == '`' and bare[^1] == '`':
    bare = bare[1 ..< bare.len - 1]
  bare.len > 0 and not (bare[0].isAlphaAscii or bare[0] == '_')

proc sameParameters(a, b: Symbol): bool =
  ## Returns true when `b` repeats the parameter list of `a`, which marks a second declaration.
  if a.paramNames.len != b.paramNames.len:
    return false
  if a.paramNames.len == 0:
    return true
  if a.paramNames != b.paramNames:
    return false
  for index in 0 ..< a.paramNames.len:
    let first = a.paramTypes[index]
    let second = b.paramTypes[index]
    if first.len > 0 and second.len > 0 and first != second:
      return false
  true

proc groupSymbols(symbols: seq[Symbol]): seq[SymbolGroup] =
  ## Groups overloads and folds repeated declarations of the same procedure.
  for symbol in symbols:
    var target = -1
    for index, group in result:
      if group.name == symbol.name and group.kind == symbol.kind:
        target = index
        break
    if target < 0:
      result.add SymbolGroup(name: symbol.name, kind: symbol.kind, members: @[symbol])
      continue
    var merged = false
    for index, member in result[target].members:
      if sameParameters(member, symbol):
        if result[target].members[index].description.len == 0:
          result[target].members[index].description = symbol.description
        merged = true
        break
    if not merged:
      result[target].members.add symbol

proc categoryOf(group: SymbolGroup): string =
  ## Returns the heading a symbol belongs under.
  case group.kind
  of "skType":
    "Types"
  of "skConst":
    "Constants"
  of "skVar", "skLet":
    "Variables"
  of "skIterator":
    "Iterators"
  of "skTemplate":
    "Templates"
  of "skMacro":
    "Macros"
  of "skConverter":
    "Converters"
  else:
    if isOperatorName(group.name): "Operators" else: "Procedures"

proc kindLabel(group: SymbolGroup): string =
  ## Returns the short keyword that introduces the symbol, for the index table.
  let words = group.members[0].code.splitWhitespace()
  if words.len > 0 and words[0] in ["proc", "func", "iterator", "template", "macro", "method",
                                    "converter"]:
    return words[0]
  case group.kind
  of "skType":
    "type"
  of "skConst":
    "const"
  of "skVar", "skLet":
    "variable"
  else:
    "symbol"

proc headingName(name: string): string =
  ## Wraps a symbol name in backticks unless it is an operator that already carries them.
  if name.len >= 2 and name[0] == '`' and name[^1] == '`':
    name
  else:
    "`" & name & "`"

proc compactDocComments(code: string): string =
  ## Collapses the column the compiler pads before an inline `##` doc comment, so a
  ## rendered declaration keeps the single space the source uses.
  var lines: seq[string]
  for line in code.splitLines():
    var scanned = ""
    var index = 0
    var quoted = false
    while index < line.len:
      let character = line[index]
      if quoted:
        scanned.add character
        if character == '\\' and index + 1 < line.len:
          inc index
          scanned.add line[index]
        elif character == '"':
          quoted = false
      elif character == '"':
        quoted = true
        scanned.add character
      elif character == '#' and index + 1 < line.len and line[index + 1] == '#':
        var stop = scanned.len
        while stop > 0 and scanned[stop - 1] in {' ', '\t'}:
          dec stop
        if stop > 0:
          scanned.setLen(stop)
          scanned.add ' '
        scanned.add "##"
        inc index
      else:
        scanned.add character
      inc index
    lines.add scanned
  result = lines.join("\n").strip(leading = false, trailing = true)

proc normalizedCode(symbol: Symbol): string =
  ## Returns the declaration to show for a symbol.
  if symbol.kind == "skType":
    compactDocComments(symbol.code.strip(leading = false, trailing = true))
  else:
    normalizeSignature(symbol.code)

proc codeFence(lines: seq[string]): string =
  ## Renders one fenced block holding every signature of a symbol.
  "```nim\n" & lines.join("\n") & "\n```\n"

proc descriptionsOf(group: SymbolGroup): seq[string] =
  ## Returns the distinct descriptions of a group, in first-seen order.
  for member in group.members:
    let text = htmlToMarkdown(member.description)
    if text.len > 0 and text notin result:
      result.add text

proc renderSymbol(group: SymbolGroup; anchor, sourceLink: string): string =
  ## Renders the heading, signatures, description, and source link of one symbol.
  result.add "<a id=\"" & anchor & "\"></a>\n"
  result.add "##### " & headingName(group.name) & "\n\n"
  let descriptions = descriptionsOf(group)
  if descriptions.len <= 1:
    result.add codeFence(group.members.mapIt(normalizedCode(it)))
    if descriptions.len == 1:
      result.add "\n" & descriptions[0] & "\n"
  else:
    var byDescription = initOrderedTable[string, seq[string]]()
    for member in group.members:
      let text = htmlToMarkdown(member.description)
      byDescription.mgetOrPut(text, @[]).add normalizedCode(member)
    var first = true
    for text, signatures in byDescription:
      if not first:
        result.add "\n"
      first = false
      result.add codeFence(signatures)
      if text.len > 0:
        result.add "\n" & text & "\n"
  result.add "\n<sub>" & sourceLink & "</sub>\n\n"

proc fenceLanguage(firstLine: string): string =
  ## Returns the fence language of an indented block, inferred from its first line.
  let text = firstLine.strip
  if text.startsWith("nim ") or text.startsWith("$ ") or text.startsWith("#!"):
    "console"
  else:
    "nim"

proc isCodeLine(line: string): bool =
  ## Returns true when a docstring line is indented enough to belong to a literal block.
  line.startsWith("  ") and line.strip.len > 0

proc renderDocComment(docLines: seq[string]): string =
  ## Renders doc comment lines, turning `.. code-block::` directives and indented
  ## literal blocks into fenced code.
  var index = 0
  var inFence = false
  var language = ""
  var fenceBody = ""
  while index < docLines.len:
    let line = docLines[index]
    let trimmed = line.strip
    if not inFence and trimmed.startsWith(".. code-block::"):
      language = trimmed[".. code-block::".len .. ^1].strip
      fenceBody = ""
      inFence = true
      inc index
      while index < docLines.len and docLines[index].strip.len == 0:
        inc index
      continue
    if not inFence and isCodeLine(line):
      language = fenceLanguage(line)
      fenceBody = ""
      inFence = true
      continue
    if inFence:
      if line.startsWith("  "):
        fenceBody.add line[2 .. ^1] & "\n"
        inc index
        continue
      if trimmed.len == 0:
        var lookahead = index + 1
        while lookahead < docLines.len and docLines[lookahead].strip.len == 0:
          inc lookahead
        if lookahead < docLines.len and isCodeLine(docLines[lookahead]):
          fenceBody.add "\n"
          inc index
          continue
        result.add "\n```" & language & "\n" & fenceBody.strip(leading = false, trailing = true) &
          "\n```\n\n"
        inFence = false
        inc index
        continue
      result.add "\n```" & language & "\n" & fenceBody.strip(leading = false, trailing = true) &
        "\n```\n\n"
      inFence = false
      continue
    result.add line & "\n"
    inc index
  if inFence:
    result.add "\n```" & language & "\n" & fenceBody.strip(leading = false, trailing = true) & "\n```\n"
  result = tidy(result)

proc moduleDocstring(path: string): string =
  ## Reads the leading `##` block of a module, so `include` files cannot leak into it.
  let source = SrcDir / path.addFileExt("nim")
  if not fileExists(source):
    fail fmt"missing source file '{source}'"
  var docLines: seq[string]
  for line in readFile(source).splitLines():
    if line.startsWith("##"):
      var content = line[2 .. ^1]
      if content.startsWith(" "):
        content = content[1 .. ^1]
      docLines.add content.strip(leading = false, trailing = true)
      continue
    if docLines.len == 0 and line.strip.len == 0:
      continue
    break
  result = renderDocComment(docLines)

proc renderModule(module: ModuleData; anchors: var Table[string, string]): string =
  ## Renders one module section and registers the anchor of every symbol.
  let spec = module.spec
  result.add "<a id=\"mod-" & spec.key & "\"></a>\n"
  result.add "### `" & spec.path & "`\n\n"
  let description = module.description
  if description.len > 0:
    result.add description & "\n\n"
  let fileName = splitFile(spec.path).name & ".nim"
  let sourcePath = "../src/" & spec.path & ".nim"
  result.add fmt"<sub>[`src/{spec.path}.nim`]({sourcePath})</sub>" & "\n\n"
  var ordinal = 0
  for category in CategoryOrder:
    var groups = module.groups.filterIt(it.categoryOf == category)
    if groups.len == 0:
      continue
    groups.sort(proc (a, b: SymbolGroup): int = cmp(a.name, b.name))
    result.add "#### " & category & "\n\n"
    for group in groups:
      let anchor = fmt"sym-{spec.key}-{ordinal}"
      inc ordinal
      anchors[spec.key & "/" & group.name] = anchor
      let line = group.members[0].line
      let link = fmt"[`{fileName}:{line}`]({sourcePath}#L{line})"
      result.add renderSymbol(group, anchor, link)

proc renderIndex(modules: seq[ModuleData]; anchors: Table[string, string]): string =
  ## Renders the alphabetical table that links every symbol to its module section.
  var rows: seq[tuple[name, kind, modulePath, anchor: string]]
  for module in modules:
    for group in module.groups:
      rows.add (
        group.name,
        group.kindLabel,
        module.spec.path,
        anchors[module.spec.key & "/" & group.name]
      )
  rows.sort(proc (a, b: tuple[name, kind, modulePath, anchor: string]): int =
    result = cmp(a.name.toLowerAscii, b.name.toLowerAscii)
    if result == 0:
      result = cmp(a.modulePath, b.modulePath)
  )
  result.add "<a id=\"index\"></a>\n"
  result.add "## Symbol index\n\n"
  result.add "| Symbol | Kind | Module |\n"
  result.add "|:-------|:-----|:-------|\n"
  for row in rows:
    result.add "| " & headingName(row.name) & " | " & row.kind & " | [" &
      row.modulePath & "](#" & row.anchor & ") |\n"
  result.add "\n"

proc safeBreakPositions(line: string): seq[int] =
  ## Returns the spaces that sit outside inline code spans and links.
  var ticks = 0
  var brackets = 0
  var parentheses = 0
  for index, character in line:
    case character
    of '`':
      inc ticks
    of '[':
      inc brackets
    of ']':
      dec brackets
    of '(':
      inc parentheses
    of ')':
      dec parentheses
    of ' ':
      if ticks mod 2 == 0 and brackets == 0 and parentheses == 0:
        result.add index
    else:
      discard

proc wrapProse(line: string; width: int): seq[string] =
  ## Breaks a prose line at safe spaces so that no segment exceeds `width`.
  if line.len <= width:
    return @[line]
  let breaks = safeBreakPositions(line)
  var start = 0
  var index = 0
  while index < breaks.len:
    if line.len - start <= width:
      result.add line[start .. ^1]
      start = line.len
      break
    var last = -1
    while index < breaks.len and breaks[index] - start <= width:
      last = breaks[index]
      inc index
    if last < 0:
      last = breaks[index]
      inc index
    result.add line[start ..< last]
    start = last + 1
  if start < line.len:
    result.add line[start .. ^1]

proc wrapDocument(text: string; width = 110): string =
  ## Wraps long prose lines; fences, tables, headings, and list items stay untouched.
  var inFence = false
  for line in text.splitLines():
    if line.startsWith("```"):
      inFence = not inFence
      result.add line & "\n"
      continue
    if inFence or line.len <= width or line.startsWith("<") or line.startsWith("#") or
        line.startsWith("|") or line.startsWith(">") or line.startsWith("-") or
        line.startsWith("*") or line.startsWith(" "):
      result.add line & "\n"
      continue
    for segment in wrapProse(line, width):
      result.add segment & "\n"

proc renderDocument(modules: seq[ModuleData]; version: string): string =
  ## Renders the complete reference.
  var anchors = initTable[string, string]()
  var symbolCount = 0
  for module in modules:
    symbolCount += module.groups.len
  result.add "# PMX Forge API Reference\n\n"
  result.add fmt"**Version {version}** · {modules.len} modules · {symbolCount} public symbols" & "\n\n"
  result.add "> Generated from the Nim sources by [`tools/gen_api_docs.nim`](../tools/gen_api_docs.nim).\n"
  result.add "> Run `nimble apiDocs` after changing the public API.\n\n"
  for module in modules:
    if module.spec.section != "Overview":
      continue
    result.add "<a id=\"mod-" & module.spec.key & "\"></a>\n"
    let description = module.description
    if description.len > 0:
      result.add description & "\n\n"
  result.add "## Contents\n\n"
  for section in SectionTitles:
    let sectionModules = modules.filterIt(it.spec.section == section)
    if sectionModules.len == 0:
      continue
    result.add "- **" & section & "**\n"
    for module in sectionModules:
      if section == "Overview":
        result.add fmt"  - [Overview](#mod-{module.spec.key})" & "\n"
      else:
        result.add fmt"  - [`{module.spec.path}`](#mod-{module.spec.key}) · {module.groups.len} symbols" &
          "\n"
  result.add "- [Symbol index](#index)\n"
  result.add "\n"
  for section in SectionTitles:
    if section == "Overview":
      continue
    let sectionModules = modules.filterIt(it.spec.section == section)
    if sectionModules.len == 0:
      continue
    result.add "## " & section & "\n\n"
    for module in sectionModules:
      result.add renderModule(module, anchors)
  result.add renderIndex(modules, anchors)
  result.add "---\n\n"
  result.add "*This reference is generated. Do not edit it by hand: run `nimble apiDocs` after changing " &
    "the public API.*\n"
  result = wrapDocument(result)

proc main() =
  ## Regenerates the reference, or verifies it with `--check`.
  var outFile = DefaultOutFile
  var checkOnly = false
  for argument in commandLineParams():
    if argument == "--check":
      checkOnly = true
    elif argument.startsWith("--out:"):
      outFile = outputPath(argument["--out:".len .. ^1])
    elif not argument.startsWith("--"):
      outFile = outputPath(argument)
  let version = packageVersion()
  let compiler = compilerPath()
  let tempDir = getTempDir() / fmt"pmxforge-jsondoc-{getCurrentProcessId()}"
  removeDir(tempDir)
  createDir(tempDir)
  defer:
    removeDir(tempDir)
  var modules: seq[ModuleData]
  for spec in Modules:
    let node = runJsonDoc(compiler, spec, tempDir)
    modules.add ModuleData(
      spec: spec,
      description: moduleDocstring(spec.path),
      groups: groupSymbols(collectSymbols(node))
    )
  let document = renderDocument(modules, version)
  if checkOnly:
    if not fileExists(outFile):
      fail fmt"'{outFile}' is missing; run 'nimble apiDocs'"
    if readFile(outFile) != document:
      fail fmt"'{outFile}' is out of date; run 'nimble apiDocs'"
    echo fmt"ok: {outFile} is current"
    return
  createDir(splitFile(outFile).dir)
  writeFile(outFile, document)
  var symbolCount = 0
  for module in modules:
    symbolCount += module.groups.len
  echo fmt"wrote {outFile}: {symbolCount} symbols in {modules.len} modules"

when isMainModule:
  main()
