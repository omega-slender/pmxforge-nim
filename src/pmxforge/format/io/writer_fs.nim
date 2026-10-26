## Filesystem destinations for the writer.
##
## Provides the atomic replace path used by `writePmx`. Included by `writer.nim`; do not import it directly.

when not declared(PmxWriteLimits):
  {.fatal: "Include writer_fs.nim from writer.nim; do not import it.".}

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  proc syncOpenFileToDisk(file: File, filePath: string) {.raises: [IOError].} =
    ## Flushes the open temporary file to disk before the rename.
    when defined(windows):
      if winlean.flushFileBuffers(winlean.Handle(getOsFileHandle(file))) == 0'i32:
        let errorCode = osLastError()
        let errorMessage = osErrorMsg(errorCode)
        raise newException(
          IOError,
          fmt"Cannot flush temporary PMX file '{filePath}' to disk: " &
            (if errorMessage.len == 0: "unknown OS error" else: errorMessage))
    elif defined(posix):
      if posix.fsync(getOsFileHandle(file)) != 0:
        raise newException(IOError, fmt"Cannot flush temporary PMX file '{filePath}' to disk.")

  when defined(posix):
    proc canonicalDirectoryPath(directoryPath, filePath: string): string {.raises: [IOError].} =
      ## Resolves the destination directory once, following every symlink.
      try:
        result = expandFilename(absolutePath(directoryPath))
      except CatchableError as exc:
        raise newException(
          IOError,
          fmt"Cannot resolve destination directory '{directoryPath}' for '{filePath}': " & exc.msg,
          exc)

    proc validateDestinationDirectory(
      directoryPath,
      filePath: string
    ) {.raises: [IOError, OSError, ValueError].} =
      ## Rejects directories where untrusted users can replace files.
      var currentPath = normalizedPath(absolutePath(directoryPath))
      while true:
        let directoryInfo = getFileInfo(currentPath, followSymlink = false)
        if directoryInfo.kind != pcDir or directoryInfo.isSpecial:
          raise newException(
            IOError, fmt"Destination directory component '{currentPath}' is not a regular directory.")
        var directoryStat: posix.Stat
        if posix.lstat(currentPath.cstring, directoryStat) != 0:
          raise newException(IOError, fmt"Cannot inspect destination directory component '{currentPath}'.")
        let writableByOther = (directoryStat.st_mode and (posix.S_IWGRP.Mode or posix.S_IWOTH.Mode)) != 0.Mode
        let sticky = (directoryStat.st_mode and posix.S_ISVTX.Mode) != 0.Mode
        if writableByOther and not sticky:
          raise newException(
            IOError,
            fmt"Refusing to write '{filePath}' through non-sticky writable directory " &
              fmt"'{currentPath}'. Use a directory trusted by the writing process.")
        let parentPath = parentDir(currentPath)
        if parentPath == currentPath or parentPath.len == 0:
          break
        currentPath = parentPath

    proc setOpenFileOwner(
      file: File,
      owner: posix.Uid,
      group: posix.Gid,
      filePath: string
    ) {.raises: [IOError].} =
      ## Sets owner and group of the open file descriptor.
      if file == nil or posix.fchown(getOsFileHandle(file), owner, group) != 0:
        raise newException(IOError, fmt"Cannot preserve ownership on temporary PMX file '{filePath}'.")

    proc setOpenFilePermissions(
      file: File,
      permissions: set[FilePermission],
      filePath: string,
      specialMode = 0.Mode
    ) {.raises: [IOError].} =
      ## Applies mode bits to the open inode, not to its path.
      if file == nil:
        raise newException(
          IOError, fmt"Cannot set permissions on temporary PMX file '{filePath}': file is closed.")
      var mode = 0.Mode
      if fpUserRead in permissions:
        mode = mode or posix.S_IRUSR.Mode
      if fpUserWrite in permissions:
        mode = mode or posix.S_IWUSR.Mode
      if fpUserExec in permissions:
        mode = mode or posix.S_IXUSR.Mode
      if fpGroupRead in permissions:
        mode = mode or posix.S_IRGRP.Mode
      if fpGroupWrite in permissions:
        mode = mode or posix.S_IWGRP.Mode
      if fpGroupExec in permissions:
        mode = mode or posix.S_IXGRP.Mode
      if fpOthersRead in permissions:
        mode = mode or posix.S_IROTH.Mode
      if fpOthersWrite in permissions:
        mode = mode or posix.S_IWOTH.Mode
      if fpOthersExec in permissions:
        mode = mode or posix.S_IXOTH.Mode
      mode = mode or specialMode
      if posix.fchmod(getOsFileHandle(file), mode) != 0:
        raise newException(IOError, fmt"Cannot set permissions on temporary PMX file '{filePath}'.")

    proc pmxRenameat(
      olddirfd: cint,
      oldpath: cstring,
      newdirfd: cint,
      newpath: cstring
    ): cint {. importc: "renameat", header: "<stdio.h>", cdecl, sideEffect.}

    proc pmxOpenat(
      dirfd: cint,
      path: cstring,
      oflag: cint
    ): cint {. importc: "openat", header: "<fcntl.h>", cdecl, sideEffect.}

    proc pmxLinkat(
      olddirfd: cint,
      oldpath: cstring,
      newdirfd: cint,
      newpath: cstring,
      flags: cint
    ): cint {. importc: "linkat", header: "<fcntl.h>", cdecl, sideEffect.}

    proc pmxUnlinkat(
      dirfd: cint,
      pathname: cstring,
      flags: cint
    ): cint {. importc: "unlinkat", header: "<fcntl.h>", cdecl, sideEffect.}

    var PmxONoFollow {.importc: "O_NOFOLLOW", header: "<fcntl.h>".}: cint

    proc requireHeldDirectory(directoryPath, filePath: string, expected: posix.Stat) {.raises: [IOError].} =
      ## Checks that the path still names the directory opened earlier, so the rename that
      ## follows cannot be redirected somewhere else.
      var current: posix.Stat
      if posix.lstat(directoryPath.cstring, current) != 0:
        raise newException(IOError, fmt"Cannot recheck destination directory '{directoryPath}'.")
      if current.st_ino != expected.st_ino or current.st_dev != expected.st_dev:
        raise newException(
          IOError, fmt"Destination directory '{directoryPath}' changed while writing '{filePath}'.")

    proc commitNewFileNoReplace(
      dirFd: cint,
      temporaryName,
      destinationName,
      filePath: string
    ) {.raises: [IOError].} =
      ## Atomically links temporary file to new destination without replacing existing files.
      if pmxLinkat(dirFd, temporaryName.cstring, dirFd, destinationName.cstring, 0) != 0:
        raise newException(
          IOError, fmt"Failed to create '{filePath}' without replacing a concurrent destination.")
      if pmxUnlinkat(dirFd, temporaryName.cstring, 0) != 0:
        raise newException(
          IOError,
          fmt"Created '{filePath}', but could not remove the temporary PMX name " &
            fmt"'{temporaryName}'; do not retry blindly.")

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  when defined(windows):
    proc commitNewFileNoReplace(temporaryPath, filePath: string) {.raises: [IOError].} =
      ## Atomically moves temporary file to destination, failing if destination exists.
      if winlean.moveFileW(newWideCString(temporaryPath), newWideCString(filePath)) == 0'i32:
        let errorCode = osLastError()
        let errorMessage = osErrorMsg(errorCode)
        raise newException(
          IOError,
          fmt"Failed to create '{filePath}' without replacing a concurrent destination: " &
            (if errorMessage.len == 0: "unknown OS error" else: errorMessage))

    proc openExistingPathNoFollow(path: string): winlean.Handle {.raises: [IOError].} =
      ## Opens an existing path on Windows with FILE_FLAG_OPEN_REPARSE_POINT.
      result = winlean.createFileW(
        newWideCString(path), winlean.GENERIC_READ,
        winlean.FILE_SHARE_READ or winlean.FILE_SHARE_WRITE or winlean.FILE_SHARE_DELETE, nil,
        winlean.OPEN_EXISTING, winlean.FILE_FLAG_OPEN_REPARSE_POINT, winlean.Handle(0))
      if result == winlean.INVALID_HANDLE_VALUE:
        raise newException(
          IOError, fmt"Cannot recheck destination '{path}' without following reparse points.")

    proc fileIdFromHandle(handle: winlean.Handle, path: string):
        tuple[device: DeviceId, file: FileId] {.raises: [IOError].} =
      ## Reads the volume serial number and file index for a Windows handle.
      var info: winlean.BY_HANDLE_FILE_INFORMATION
      if winlean.getFileInformationByHandle(handle, addr info) == 0:
        raise newException(IOError, fmt"Cannot read the file identity of '{path}'.")
      template mergeFileId(lowPart, highPart: winlean.DWORD): FileId =
        ## Combines low and high DWORDs into a 64-bit FileId.
        FileId((uint64(cast[uint32](lowPart))) or (uint64(cast[uint32](highPart)) shl 32))
      (DeviceId(info.dwVolumeSerialNumber), mergeFileId(info.nFileIndexLow, info.nFileIndexHigh))

    proc getSecurityInfo(
      handle: winlean.Handle,
      objectType: int32,
      securityInfo: winlean.DWORD,
      owner,
      group: pointer,
      dacl: ptr pointer,
      sacl: pointer,
      securityDescriptor: ptr pointer
    ): winlean.DWORD {. stdcall, dynlib: "advapi32", importc: "GetSecurityInfo".}

    proc getAclInformation(
      acl,
      information: pointer,
      length: winlean.DWORD,
      informationClass: int32
    ): winlean.WINBOOL {. stdcall, dynlib: "advapi32", importc: "GetAclInformation".}

    proc getAce(
      acl: pointer,
      index: winlean.DWORD,
      ace: ptr pointer
    ): winlean.WINBOOL {. stdcall, dynlib: "advapi32", importc: "GetAce".}

    proc isValidSid(sid: pointer): winlean.WINBOOL {. stdcall, dynlib: "advapi32", importc: "IsValidSid".}

    proc getSidSubAuthorityCount(
      sid: pointer
    ): ptr uint8 {. stdcall, dynlib: "advapi32", importc: "GetSidSubAuthorityCount".}

    proc getSidSubAuthority(
      sid: pointer,
      index: winlean.DWORD
    ): ptr winlean.DWORD {. stdcall, dynlib: "advapi32", importc: "GetSidSubAuthority".}

    proc getSidIdentifierAuthority(
      sid: pointer
    ): pointer {. stdcall, dynlib: "advapi32", importc: "GetSidIdentifierAuthority".}

    const
      ReadControlRight = 0x00020000'i32 ## READ_CONTROL access right.
      FileAddFile = 0x00000002'u32 ## FILE_ADD_FILE access right.
      FileAddSubdirectory = 0x00000004'u32 ## FILE_ADD_SUBDIRECTORY access right.
      FileDeleteChild = 0x00000040'u32 ## FILE_DELETE_CHILD access right.
      DeleteRight = 0x00010000'u32 ## DELETE access right.
      WriteDacRight = 0x00040000'u32 ## WRITE_DAC access right.
      WriteOwnerRight = 0x00080000'u32 ## WRITE_OWNER access right.
      GenericWriteRight = 0x40000000'u32 ## GENERIC_WRITE access right.
      GenericAllRight = 0x10000000'u32 ## GENERIC_ALL access right.
      InheritOnlyAce = 0x08'u8 ## ACE flag: applies to inherited children only.
      AccessAllowedAce = 0x00'u8 ## ACE type: ACCESS_ALLOWED_ACE_TYPE.
      AccessAllowedObjectAce = 0x05'u8 ## ACE type: ACCESS_ALLOWED_OBJECT_ACE_TYPE.
      AccessAllowedCallbackAce = 0x09'u8 ## ACE type: ACCESS_ALLOWED_CALLBACK_ACE_TYPE.
      AccessAllowedCallbackObjectAce = 0x0B'u8 ## ACE type: ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE.
      AceObjectTypePresent = 0x00000001'u32 ## ACE flag: object type GUID present.
      AceInheritedObjectTypePresent = 0x00000002'u32 ## ACE flag: inherited object type GUID present.
      SeFileObject = 1'i32 ## SE_FILE_OBJECT descriptor type.
      DaclSecurityInformation = 4'i32 ## DACL_SECURITY_INFORMATION flag.
      AclSizeInformationClass = 2'i32 ## ACL_SIZE_INFORMATION class.
      LeafReplaceRights = FileAddFile or FileAddSubdirectory or FileDeleteChild or
        DeleteRight or WriteDacRight or WriteOwnerRight or GenericWriteRight or
        GenericAllRight ## Rights that let a principal replace the leaf entry.
      AncestorReplaceRights =
        FileDeleteChild or DeleteRight or WriteDacRight or WriteOwnerRight or GenericWriteRight or
        GenericAllRight
        ## Rights that let a principal replace an existing child entry.

    type AclSizeInformation = object
      aceCount: int32
      aclBytesInUse: int32
      aclBytesFree: int32

    proc readByte(base: pointer, offset: int): uint8 =
      ## Reads an 8-bit unsigned integer from pointer + offset.
      copyMem(addr result, cast[pointer](cast[uint](base) + uint(offset)), 1)

    proc readU16(base: pointer, offset: int): uint16 =
      ## Reads a 16-bit little-endian integer from pointer + offset.
      copyMem(addr result, cast[pointer](cast[uint](base) + uint(offset)), 2)

    proc readU32(base: pointer, offset: int): uint32 =
      ## Reads a 32-bit little-endian integer from pointer + offset.
      copyMem(addr result, cast[pointer](cast[uint](base) + uint(offset)), 4)

    proc worldPrincipal(sid: pointer): bool =
      ## Returns true if the SID represents a world principal (Everyone, Anonymous, Guests).
      if sid == nil or isValidSid(sid) == 0:
        return false
      let authority = getSidIdentifierAuthority(sid)
      if authority == nil:
        return false
      if readByte(authority, 0) != 0 or readByte(authority, 1) != 0 or readByte(authority, 2) != 0 or
          readByte(authority, 3) != 0 or readByte(authority, 4) != 0:
        return false
      let count = int(getSidSubAuthorityCount(sid)[])
      if count < 1 or count > 15:
        return false
      let first = cast[uint32](getSidSubAuthority(sid, 0)[])
      let kind = readByte(authority, 5)
      if kind == 1:
        return count == 1 and first == 0'u32
      if kind != 5:
        return false
      if count == 1:
        return first == 7'u32
      if count == 2 and first == 32'u32:
        let second = cast[uint32](getSidSubAuthority(sid, 1)[])
        return second == 546'u32
      false

    proc sidFromAllowedAce(ace: pointer, aceSize: int): pointer =
      ## Extracts the SID pointer from an access-allowed ACE structure.
      let aceType = readByte(ace, 0)
      var offset = 0
      case aceType
      of AccessAllowedAce, AccessAllowedCallbackAce:
        offset = 8
      of AccessAllowedObjectAce, AccessAllowedCallbackObjectAce:
        if aceSize < 12:
          return nil
        let flags = readU32(ace, 8)
        offset = 12
        if (flags and AceObjectTypePresent) != 0:
          offset += 16
        if (flags and AceInheritedObjectTypePresent) != 0:
          offset += 16
      else:
        return nil
      if aceSize < offset + 8:
        return nil
      cast[pointer](cast[uint](ace) + uint(offset))

    proc directoryGrantsWorldReplace(directoryPath: string, leaf: bool): bool {.raises: [IOError].} =
      ## Checks whether the directory's DACL grants replace rights to unprivileged users.
      let handle = winlean.createFileW(
        newWideCString(directoryPath), ReadControlRight,
        winlean.FILE_SHARE_READ or winlean.FILE_SHARE_WRITE or winlean.FILE_SHARE_DELETE, nil,
        winlean.OPEN_EXISTING, winlean.FILE_FLAG_BACKUP_SEMANTICS or winlean.FILE_FLAG_OPEN_REPARSE_POINT,
        winlean.Handle(0))
      if handle == winlean.INVALID_HANDLE_VALUE:
        raise newException(IOError, fmt"Cannot inspect the security descriptor of '{directoryPath}'.")
      var securityDescriptor: pointer = nil
      try:
        var info: winlean.BY_HANDLE_FILE_INFORMATION
        if winlean.getFileInformationByHandle(handle, addr info) == 0:
          raise newException(IOError, fmt"Cannot inspect directory '{directoryPath}'.")
        if (info.dwFileAttributes and winlean.FILE_ATTRIBUTE_REPARSE_POINT) != 0:
          raise newException(
            IOError, fmt"Destination directory component '{directoryPath}' is a reparse point.")
        var dacl: pointer = nil
        let status = getSecurityInfo(
          handle, SeFileObject, DaclSecurityInformation, nil, nil, addr dacl, nil, addr securityDescriptor)
        if status != 0:
          raise newException(IOError, fmt"Cannot read the DACL of '{directoryPath}'.")
        if dacl == nil:
          return true
        var aclInfo: AclSizeInformation
        if getAclInformation(dacl, addr aclInfo, winlean.DWORD(sizeof(aclInfo)), AclSizeInformationClass) ==
          0 or aclInfo.aceCount < 0:
          raise newException(IOError, fmt"Cannot read ACL entries of '{directoryPath}'.")
        let rights = if leaf: LeafReplaceRights else: AncestorReplaceRights
        for index in 0 ..< aclInfo.aceCount:
          var ace: pointer = nil
          if getAce(dacl, winlean.DWORD(index), addr ace) == 0 or ace == nil:
            raise newException(IOError, fmt"Cannot read ACL entry {index} of '{directoryPath}'.")
          let aceSize = int(readU16(ace, 2))
          if aceSize < 8:
            raise newException(IOError, fmt"ACL entry {index} of '{directoryPath}' is truncated.")
          if (readByte(ace, 1) and InheritOnlyAce) != 0:
            continue
          let aceType = readByte(ace, 0)
          if aceType notin
              {AccessAllowedAce, AccessAllowedObjectAce, AccessAllowedCallbackAce,
               AccessAllowedCallbackObjectAce}:
            continue
          let mask = readU32(ace, 4)
          if (mask and rights) == 0:
            continue
          let sid = sidFromAllowedAce(ace, aceSize)
          if sid == nil:
            raise newException(IOError, fmt"Cannot parse an allow entry on '{directoryPath}'.")
          if worldPrincipal(sid):
            return true
        result = false
      finally:
        if securityDescriptor != nil:
          winlean.localFree(securityDescriptor)
        discard winlean.closeHandle(handle)

    const FileReadAttributes = 0x0080'u32 ## FILE_READ_ATTRIBUTES access right.

    proc getFinalPathNameByHandleW(
      hFile: winlean.Handle,
      resolvedPath: WideCString,
      pathLength: winlean.DWORD,
      flags: winlean.DWORD
    ): winlean.DWORD {. stdcall, dynlib: "kernel32", importc: "GetFinalPathNameByHandleW", sideEffect.}

    proc trimNtPrefix(path: string): string =
      ## Removes the `\\?\` and `\\?\UNC\` prefixes the API returns.
      const NtPrefix = "\\\\?\\"
      const NtUncPrefix = "\\\\?\\UNC\\"
      if path.len > NtUncPrefix.len and path[0 ..< NtUncPrefix.len] == NtUncPrefix:
        "\\\\" & path[NtUncPrefix.len .. ^1]
      elif path.len > NtPrefix.len and path[0 ..< NtPrefix.len] == NtPrefix:
        path[NtPrefix.len .. ^1]
      else:
        path

    proc canonicalDirectoryPath(directoryPath, filePath: string): string {.raises: [IOError].} =
      ## Resolves junctions and directory symlinks to their final path, so a destination
      ## reached through one is checked and committed as the real directory.
      let handle = winlean.createFileW(
        newWideCString(directoryPath), winlean.DWORD(FileReadAttributes),
        winlean.FILE_SHARE_READ or winlean.FILE_SHARE_WRITE or winlean.FILE_SHARE_DELETE, nil,
        winlean.OPEN_EXISTING, winlean.FILE_FLAG_BACKUP_SEMANTICS, winlean.Handle(0))
      if handle == winlean.INVALID_HANDLE_VALUE:
        let errorCode = osLastError()
        let errorMessage = osErrorMsg(errorCode)
        raise newException(
          IOError,
          fmt"Cannot resolve destination directory '{directoryPath}' for '{filePath}': " &
            (if errorMessage.len == 0: "unknown OS error" else: errorMessage))
      try:
        var bufferSize = 512
        while bufferSize <= 32768:
          var buffer = newSeq[uint16](bufferSize + 1)
          let written = getFinalPathNameByHandleW(
            handle, cast[WideCString](addr buffer[0]), winlean.DWORD(bufferSize), winlean.DWORD(0))
          if written.int == 0:
            raise newException(
              IOError, fmt"Cannot resolve destination directory '{directoryPath}' for '{filePath}'.")
          if written.int < bufferSize:
            result = trimNtPrefix($cast[WideCString](addr buffer[0]))
            break
          bufferSize = written.int + 1
        if result.len == 0:
          raise newException(
            IOError,
            fmt"Cannot resolve destination directory '{directoryPath}': the resolved path is too long.")
      finally:
        discard winlean.closeHandle(handle)

    proc validateDestinationDirectory(
      directoryPath,
      filePath: string
    ) {.raises: [IOError, OSError, ValueError].} =
      ## Rejects directories granting write or delete rights to world principals.
      var currentPath = normalizedPath(absolutePath(directoryPath))
      var leaf = true
      while true:
        let directoryInfo = getFileInfo(currentPath, followSymlink = false)
        if directoryInfo.kind != pcDir or directoryInfo.isSpecial:
          raise newException(
            IOError, fmt"Destination directory component '{currentPath}' is not a regular directory.")
        if directoryGrantsWorldReplace(currentPath, leaf):
          raise newException(
            IOError,
            fmt"Refusing to write '{filePath}' through directory '{currentPath}' " &
              "because a world principal can replace entries there.")
        leaf = false
        let parentPath = parentDir(currentPath)
        if parentPath == currentPath or parentPath.len == 0:
          break
        currentPath = parentPath

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  type
    OutputLimitedStream = ref object of StreamObj ## Write-only stream enforcing an output size limit.
      parent: Stream ## Underlying writable stream.
      remaining: int64 ## Remaining allowed byte count.

  proc limitedWriteData(
    s: Stream,
    buffer: pointer,
    bufferLength: int
  ) {.nimcall, raises: [IOError, OSError], gcsafe.} =
    ## Writes to the parent stream and enforces the remaining byte limit.
    let limited = OutputLimitedStream(s)
    if bufferLength < 0:
      raise newException(IOError, "Negative output-limited write length.")
    if int64(bufferLength) > limited.remaining:
      raise newException(PmxWriteLimitIoError, "PMX output exceeds the configured limit.")
    limited.parent.writeData(buffer, bufferLength)
    limited.remaining -= int64(bufferLength)

  proc limitedGetPosition(s: Stream): int {.nimcall, raises: [IOError, OSError], gcsafe.} =
    ## Returns the current write offset of the underlying stream.
    OutputLimitedStream(s).parent.getPosition()

  proc newOutputLimitedStream(stream: Stream, maxBytes: int64): OutputLimitedStream {.raises: [ValueError].} =
    ## Creates a stream wrapper that raises an error if more than maxBytes are written.
    if stream == nil:
      raise newException(ValueError, "Stream is nil.")
    if maxBytes < 0:
      raise newException(ValueError, "Output byte limit must not be negative.")
    new(result)
    result.parent = stream
    result.remaining = maxBytes
    result.writeDataImpl = limitedWriteData
    result.getPositionImpl = limitedGetPosition

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  proc writePmxFileInternal(
    model: PmxModel,
    filePath: string,
    limits: PmxWriteLimits,
    autoUpgradeVersion: bool,
    mode: PmxWriteMode,
    maxStringBytes: int
  ) {.raises: [IOError, OSError, ValueError].} =
    ## Writes a model atomically using a temporary file in the destination directory.
    if filePath.len == 0:
      raise newException(ValueError, "File path must not be empty.")
    if '\0' in filePath:
      raise newException(ValueError, "File path must not contain NUL bytes.")
    validateWriteLimits(limits)

    let dir = parentDir(filePath)
    var targetDir = if dir.len == 0: "." else: dir
    if not dirExists(targetDir):
      raise newException(IOError, fmt"Cannot write to '{filePath}'. Directory '{targetDir}' does not exist.")
    when defined(posix) or defined(windows):
      targetDir = canonicalDirectoryPath(targetDir, filePath)
      validateDestinationDirectory(targetDir, filePath)
    when defined(posix):
      let destinationDirFd = posix.open(targetDir.cstring, posix.O_RDONLY)
      if destinationDirFd < 0:
        raise newException(IOError, fmt"Cannot open destination directory '{targetDir}'.")
      var destinationDirStat: posix.Stat
      if posix.fstat(destinationDirFd, destinationDirStat) != 0:
        discard posix.close(destinationDirFd)
        raise newException(IOError, fmt"Cannot inspect destination directory '{targetDir}'.")
      defer:
        discard posix.close(destinationDirFd)
    let stringLimit = effectiveStringLimit(limits, maxStringBytes)
    let writeModel = prepareWriteModel(model, autoUpgradeVersion, mode, stringLimit)
    validateWritableModel(writeModel, mode, stringLimit)

    var targetPresent = true
    var initialTargetInfo: FileInfo
    try:
      initialTargetInfo = getFileInfo(filePath, followSymlink = false)
    except OSError as exc:
      when defined(windows):
        if exc.errorCode notin [2'i32, 3'i32]:
          raise exc
      else:
        if exc.errorCode != posix.ENOENT.int32:
          raise exc
      targetPresent = false
    if targetPresent and (initialTargetInfo.kind != pcFile or initialTargetInfo.isSpecial):
      raise newException(IOError, fmt"Destination '{filePath}' must be a regular non-symlink file.")
    let preservePermissions = targetPresent
    var originalPermissions: set[FilePermission]
    var originalTargetInfo: FileInfo
    when defined(posix):
      var originalOwner: tuple[uid: posix.Uid, gid: posix.Gid]
      var originalSpecialMode = 0.Mode
      var originalStat: posix.Stat
    if preservePermissions:
      originalPermissions = getFilePermissions(filePath)
      originalTargetInfo = initialTargetInfo
      when defined(posix):
        if posix.lstat(filePath.cstring, originalStat) != 0:
          raise newException(IOError, fmt"Cannot inspect ownership of destination '{filePath}'.")
        originalOwner = (originalStat.st_uid, originalStat.st_gid)
        originalSpecialMode =
          originalStat.st_mode and (posix.S_ISUID.Mode or posix.S_ISGID.Mode or posix.S_ISVTX.Mode)
    when defined(linux) or defined(macosx) or defined(freebsd) or defined(dragonfly) or defined(netbsd):
      var originalExtendedAttributes: seq[ExtendedFileAttribute]
      if preservePermissions:
        originalExtendedAttributes = snapshotExtendedFileAttributes(filePath)
    when defined(macosx):
      var originalExtendedAcl: seq[byte]
      if preservePermissions:
        originalExtendedAcl = snapshotExtendedFileAcl(filePath)

    let created = createTempFile(".pmxforge-", ".tmp", targetDir)
    let temporaryPath = created.path
    let temporaryFile = created.cfile
    var temporaryInfo: FileInfo
    var temporaryExists = true
    var s: FileStream
    var commitCompleted = false
    try:
      temporaryInfo = getFileInfo(temporaryFile)
      s = newFileStream(temporaryFile)
      if s == nil:
        close(temporaryFile)
        raise newException(IOError, fmt"Cannot open temporary PMX file '{temporaryPath}'.")
      try:
        let limited = newOutputLimitedStream(s, limits.maxOutputBytes)
        writePmxValidated(writeModel, limited, mode, stringLimit)
        checkedFlushFile(temporaryFile)
        when defined(posix):
          when defined(linux) or defined(macosx) or defined(freebsd) or defined(dragonfly) or defined(netbsd):
            if preservePermissions:
              setOpenFileOwner(temporaryFile, originalOwner.uid, originalOwner.gid, temporaryPath)
              clearUnlistedExtendedFileAttributes(temporaryFile, temporaryPath, originalExtendedAttributes)
              restoreExtendedFileAttributes(temporaryFile, temporaryPath, originalExtendedAttributes)
          if preservePermissions:
            when not defined(linux) and not defined(macosx) and not defined(freebsd) and
              not defined(dragonfly) and not defined(netbsd):
              setOpenFileOwner(temporaryFile, originalOwner.uid, originalOwner.gid, temporaryPath)
            setOpenFilePermissions(temporaryFile, originalPermissions, temporaryPath, originalSpecialMode)
            when defined(macosx):
              restoreExtendedFileAcl(temporaryFile, temporaryPath, originalExtendedAcl)
          syncOpenFileToDisk(temporaryFile, temporaryPath)
        else:
          syncOpenFileToDisk(temporaryFile, temporaryPath)
      except PmxWriteLimitIoError as exc:
        raise newException(PmxLimitError, exc.msg, exc)
      finally:
        s.close()
      try:
        let currentTemporaryInfo = getFileInfo(temporaryPath, followSymlink = false)
        if currentTemporaryInfo.id != temporaryInfo.id or currentTemporaryInfo.kind != pcFile:
          raise newException(IOError, fmt"Temporary PMX file '{temporaryPath}' changed before commit.")
        if preservePermissions:
          when defined(windows):
            let currentTargetInfo = getFileInfo(filePath, followSymlink = false)
            if currentTargetInfo.id != originalTargetInfo.id or
                currentTargetInfo.kind != originalTargetInfo.kind:
              raise newException(
                IOError, fmt"Destination '{filePath}' changed while the PMX file was being written.")
            if getFilePermissions(filePath) != originalPermissions:
              raise newException(
                IOError,
                fmt"Destination permissions for '{filePath}' changed while the PMX file was being written.")
            let destHandle = openExistingPathNoFollow(filePath)
            try:
              if fileIdFromHandle(destHandle, filePath) != originalTargetInfo.id:
                raise newException(
                  IOError, fmt"Destination '{filePath}' changed while the PMX file was being written.")
            finally:
              discard winlean.closeHandle(destHandle)
          else:
            requireHeldDirectory(targetDir, filePath, destinationDirStat)
            let destFd = pmxOpenat(
              destinationDirFd, lastPathPart(filePath).cstring, posix.O_RDONLY or PmxONoFollow)
            if destFd < 0:
              raise newException(
                IOError, fmt"Cannot recheck destination '{filePath}' without following a symlink.")
            try:
              var currentStat: posix.Stat
              if posix.fstat(destFd, currentStat) != 0:
                raise newException(IOError, fmt"Cannot recheck identity of destination '{filePath}'.")
              if currentStat.st_ino != originalStat.st_ino or currentStat.st_dev != originalStat.st_dev:
                raise newException(
                  IOError, fmt"Destination '{filePath}' changed while the PMX file was being written.")
              if currentStat.st_uid != originalOwner.uid or currentStat.st_gid != originalOwner.gid:
                raise newException(
                  IOError,
                  fmt"Destination ownership for '{filePath}' changed while the PMX file was being written.")
              let modeMask =
                posix.S_IRWXU.Mode or posix.S_IRWXG.Mode or posix.S_IRWXO.Mode or posix.S_ISUID.Mode or
                posix.S_ISGID.Mode or posix.S_ISVTX.Mode
              if (currentStat.st_mode and modeMask) != (originalStat.st_mode and modeMask):
                raise newException(
                  IOError,
                  fmt"Destination permissions for '{filePath}' changed while the PMX file was being written."
                )
            finally:
              discard posix.close(destFd)
          when defined(linux) or defined(macosx) or defined(freebsd) or defined(dragonfly) or defined(netbsd):
            let currentExtendedAttributes = snapshotExtendedFileAttributes(filePath)
            if currentExtendedAttributes != originalExtendedAttributes:
              raise newException(
                IOError,
                fmt"Destination security metadata for '{filePath}' changed while the PMX file was being written."
              )
          when defined(macosx):
            if snapshotExtendedFileAcl(filePath) != originalExtendedAcl:
              raise newException(
                IOError, fmt"Destination ACL for '{filePath}' changed while the PMX file was being written.")
        else:
          when defined(posix):
            requireHeldDirectory(targetDir, filePath, destinationDirStat)
            let appearedFd = pmxOpenat(
              destinationDirFd, lastPathPart(filePath).cstring, posix.O_RDONLY or PmxONoFollow)
            if appearedFd >= 0:
              discard posix.close(appearedFd)
              raise newException(
                IOError, fmt"Destination '{filePath}' appeared while the PMX file was being written.")
            if posix.errno != posix.ENOENT:
              raise newException(IOError, fmt"Cannot recheck absence of destination '{filePath}'.")
          else:
            try:
              discard getFileInfo(filePath, followSymlink = false)
              raise newException(
                IOError, fmt"Destination '{filePath}' appeared while the PMX file was being written.")
            except OSError as exc:
              if exc.errorCode notin [2'i32, 3'i32]:
                raise exc
        if preservePermissions:
          when defined(windows):
            let replaced = replaceFileW(
              newWideCString(filePath), newWideCString(temporaryPath), nil, 0'i32, nil, nil)
            if replaced == 0'i32:
              let errorCode = osLastError()
              let errorMessage = osErrorMsg(errorCode)
              raise newException(
                IOError,
                fmt"Failed to replace '{filePath}' while preserving its security descriptor: " &
                  (if errorMessage.len == 0: "unknown OS error" else: errorMessage))
          else:
            if pmxRenameat(
              destinationDirFd, lastPathPart(temporaryPath).cstring, destinationDirFd,
              lastPathPart(filePath).cstring) != 0:
              raise newException(
                IOError, fmt"Failed to replace '{filePath}' through the held destination directory.")
        else:
          when defined(windows):
            commitNewFileNoReplace(temporaryPath, filePath)
          else:
            commitNewFileNoReplace(
              destinationDirFd, lastPathPart(temporaryPath), lastPathPart(filePath), filePath)
        commitCompleted = true
        when defined(posix):
          if posix.fsync(destinationDirFd) != 0:
            raise newException(IOError, fmt"Cannot flush destination directory for '{filePath}'.")
      except ValueError:
        raise
      except CatchableError as exc:
        if commitCompleted:
          raise newException(
            IOError,
            fmt"PMX file '{filePath}' was replaced, but directory durability " &
              "could not be confirmed; do not retry blindly: " & exc.msg,
            exc)
        raise newException(IOError, fmt"Failed to commit temporary PMX file to '{filePath}': {exc.msg}", exc)
      temporaryExists = false
    finally:
      if temporaryExists:
        discard tryRemoveFile(temporaryPath)

  proc writePmx*(
    model: PmxModel,
    filePath: string,
    autoUpgradeVersion = true,
    mode = pwmStrict,
    maxStringBytes = -1
  ) {.raises: [IOError, OSError, ValueError].} =
    ## Writes `model` to `filePath` atomically using SafePmxWriteLimits.
    writePmxFileInternal(model, filePath, SafePmxWriteLimits, autoUpgradeVersion, mode, maxStringBytes)

  proc writePmx*(
    model: PmxModel,
    filePath: string,
    limits: PmxWriteLimits,
    autoUpgradeVersion = true,
    mode = pwmStrict,
    maxStringBytes = -1
  ) {.raises: [IOError, OSError, ValueError].} =
    ## Writes `model` to `filePath` atomically using the specified write limits.
    writePmxFileInternal(model, filePath, limits, autoUpgradeVersion, mode, maxStringBytes)
