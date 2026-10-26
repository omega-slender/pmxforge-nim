## Extended metadata preservation.
##
## Provides the xattr and ACL snapshot and restore helpers used when an existing file is replaced on
## Linux, macOS, and the BSDs.

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  import strformat
  import algorithm

  type
    ExtendedFileAttribute* = object ## Extended file attribute name-value pair.
      name*: string ## Attribute name string.
      value*: seq[byte] ## Binary attribute value payload.

  when defined(linux) or defined(macosx) or defined(freebsd) or defined(dragonfly) or defined(netbsd):
    proc metadataError(operation, filePath, attributeName: string): ref IOError =
      ## Creates a formatted IOError for metadata operations.
      let suffix = if attributeName.len == 0: "" else: fmt" for '{attributeName}'"
      newException(IOError, fmt"Cannot {operation} extended metadata{suffix} on '{filePath}'.")

  when defined(linux) or defined(macosx):
    const
      MaxExtendedAttributeNameBytes = 4096 ## Maximum byte length for an xattr name.
      MaxExtendedAttributeCount = 4096 ## Maximum number of xattr entries per file.

    proc parseAttributeNames(filePath: string, encoded: seq[byte]): seq[string] {.raises: [IOError].} =
      ## Splits a null-delimited buffer into validated attribute names. Shared by the
      ## Linux and macOS branches, which differ only in the syscall wrappers.
      var start = 0
      for i, value in encoded:
        if value != 0:
          continue
        let nameLength = i - start
        if nameLength == 0 or nameLength > MaxExtendedAttributeNameBytes:
          raise metadataError("parse", filePath, "")
        var name = newString(nameLength)
        for j in 0 ..< nameLength:
          name[j] = char(encoded[start + j])
        result.add(name)
        if result.len > MaxExtendedAttributeCount:
          raise newException(
            IOError,
            fmt"'{filePath}' has more than {MaxExtendedAttributeCount} " &
              "extended attributes; refusing an unbounded metadata copy.")
        start = i + 1
      if start != encoded.len:
        raise metadataError("parse", filePath, "")

  when defined(linux):
    type XAttrSize = clong

    proc llistxattr(
      path: cstring,
      list: pointer,
      size: csize_t
    ): XAttrSize {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc lgetxattr(
      path,
      name: cstring,
      value: pointer,
      size: csize_t
    ): XAttrSize {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc flistxattr(
      fileDescriptor: cint,
      list: pointer,
      size: csize_t
    ): XAttrSize {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc fsetxattr(
      fileDescriptor: cint,
      name: cstring,
      value: pointer,
      size: csize_t,
      flags: cint
    ): cint {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc fremovexattr(
      fileDescriptor: cint,
      name: cstring
    ): cint {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}

    const
      MaxExtendedAttributeValueBytes = 16 * 1024 * 1024 ## Maximum byte length for an xattr value (16 MB).
      MaxExtendedAttributeTotalBytes = 64 * 1024 * 1024 ## Maximum combined xattr bytes (64 MB).
      MaxExtendedAttributeAttempts = 3 ## Retry count for reading xattrs under concurrent changes.

    proc readAttribute(filePath, attributeName: string): seq[byte] {.raises: [IOError].} =
      ## Reads the byte payload of one extended attribute without following symlinks.
      let cPath = filePath.cstring
      let cName = attributeName.cstring
      for _ in 0 ..< MaxExtendedAttributeAttempts:
        let required = lgetxattr(cPath, cName, nil, 0)
        if required < 0:
          raise metadataError("size", filePath, attributeName)
        if required > XAttrSize(MaxExtendedAttributeValueBytes):
          raise newException(
            IOError,
            fmt"Extended metadata value for '{attributeName}' exceeds the " &
              fmt"{MaxExtendedAttributeValueBytes}-byte safety limit.")
        var value = newSeq[byte](int(required))
        let actual = if value.len == 0:
          lgetxattr(cPath, cName, nil, 0)
        else:
          lgetxattr(cPath, cName, addr value[0], csize_t(value.len))
        if actual < 0:
          continue
        if actual != required:
          continue
        value.setLen(int(actual))
        return value
      raise metadataError("read", filePath, attributeName)

    proc snapshotExtendedFileAttributes*(filePath: string): seq[ExtendedFileAttribute] {.raises: [IOError].} =
      ## Reads a size-bounded snapshot of the file's extended attributes.
      let cPath = filePath.cstring
      for _ in 0 ..< MaxExtendedAttributeAttempts:
        let required = llistxattr(cPath, nil, 0)
        if required < 0:
          raise metadataError("list", filePath, "")
        if required == 0:
          if llistxattr(cPath, nil, 0) == 0:
            return @[]
          continue
        if required > XAttrSize(MaxExtendedAttributeTotalBytes):
          raise newException(
            IOError,
            fmt"Extended metadata names for '{filePath}' exceed the " &
              fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
        var encoded = newSeq[byte](int(required))
        let actual = llistxattr(cPath, addr encoded[0], csize_t(encoded.len))
        if actual < 0 or actual != required:
          continue
        var names = parseAttributeNames(filePath, encoded)
        names.sort()
        var totalBytes = 0'i64
        for name in names:
          let value = readAttribute(filePath, name)
          if value.len > MaxExtendedAttributeValueBytes or
              totalBytes > int64(MaxExtendedAttributeTotalBytes) - int64(value.len):
            raise newException(
              IOError,
              fmt"Extended metadata for '{filePath}' exceeds the " &
                fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
          totalBytes += int64(value.len)
          result.add(ExtendedFileAttribute(name: name, value: value))
        var finalEncoded = newSeq[byte](int(required))
        let finalActual = llistxattr(cPath, addr finalEncoded[0], csize_t(finalEncoded.len))
        if finalActual != required or finalEncoded != encoded:
          result.setLen(0)
          continue
        var stable = true
        for i, name in names:
          try:
            if readAttribute(filePath, name) != result[i].value:
              stable = false
              break
          except IOError:
            stable = false
            break
        if stable:
          return result
        result.setLen(0)
      raise metadataError("snapshot", filePath, "")

    proc restoreExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Restores attributes through the open temporary file descriptor.
      if file == nil:
        raise newException(IOError, fmt"Cannot restore extended metadata on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      for attribute in attributes:
        let valuePointer = if attribute.value.len == 0: nil else: addr attribute.value[0]
        if fsetxattr(
          fileDescriptor, attribute.name.cstring, valuePointer, csize_t(attribute.value.len), 0) !=
            0:
          raise metadataError("restore", filePath, attribute.name)

    proc clearUnlistedExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Removes unlisted attributes from the open temporary file descriptor.
      if file == nil:
        raise newException(IOError, fmt"Cannot clear extended metadata on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      let required = flistxattr(fileDescriptor, nil, 0)
      if required < 0:
        raise metadataError("list", filePath, "")
      if required == 0:
        return
      if required > XAttrSize(MaxExtendedAttributeTotalBytes):
        raise newException(
          IOError,
          fmt"Extended metadata names for '{filePath}' exceed the " &
            fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
      var encoded = newSeq[byte](int(required))
      let actual = flistxattr(fileDescriptor, addr encoded[0], csize_t(encoded.len))
      if actual < 0 or actual != required:
        raise metadataError("list", filePath, "")
      let existingNames = parseAttributeNames(filePath, encoded)
      for name in existingNames:
        var keep = false
        for attribute in attributes:
          if attribute.name == name:
            keep = true
            break
        if not keep and fremovexattr(fileDescriptor, name.cstring) != 0:
          raise metadataError("remove", filePath, name)

  elif defined(macosx):
    import std/posix

    type XAttrSize = clong
    const
      XattrNoFollow = 1.cint ## XATTR_NOFOLLOW: inspect the link itself, not its target.
      DarwinEnoattr = 93.cint ## ENOATTR: the attribute does not exist.
      AclTypeExtended = 0x00000100.cint ## ACL_TYPE_EXTENDED descriptor type.
      MaxExtendedAttributeValueBytes = 16 * 1024 * 1024 ## Maximum byte length for an xattr value (16 MB).
      MaxExtendedAttributeTotalBytes = 64 * 1024 * 1024 ## Maximum combined xattr bytes (64 MB).
      MaxExtendedAttributeAttempts = 3 ## Retry count for reads under concurrent changes.

    proc listxattr(
      path: cstring,
      list: pointer,
      size: csize_t,
      options: cint
    ): XAttrSize {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc getxattr(
      path,
      name: cstring,
      value: pointer,
      size: csize_t,
      position: uint32,
      options: cint
    ): XAttrSize {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc flistxattr(
      fileDescriptor: cint,
      list: pointer,
      size: csize_t,
      options: cint
    ): XAttrSize {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc fsetxattr(
      fileDescriptor: cint,
      name: cstring,
      value: pointer,
      size: csize_t,
      position: uint32,
      options: cint
    ): cint {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc fremovexattr(
      fileDescriptor: cint,
      name: cstring,
      options: cint
    ): cint {. importc, header: "<sys/xattr.h>", cdecl, sideEffect.}
    proc aclGetLinkNp(
      path: cstring,
      aclType: cint
    ): pointer {. importc: "acl_get_link_np", header: "<sys/acl.h>", cdecl, sideEffect.}
    proc aclSizeOf(acl: pointer): clong {. importc: "acl_size", header: "<sys/acl.h>", cdecl, sideEffect.}
    proc aclCopyExt(
      buffer: pointer,
      acl: pointer,
      size: clong
    ): clong {. importc: "acl_copy_ext", header: "<sys/acl.h>", cdecl, sideEffect.}
    proc aclCopyInt(
      buffer: pointer
    ): pointer {. importc: "acl_copy_int", header: "<sys/acl.h>", cdecl, sideEffect.}
    proc aclSetFdNp(
      fileDescriptor: cint,
      acl: pointer,
      aclType: cint
    ): cint {. importc: "acl_set_fd_np", header: "<sys/acl.h>", cdecl, sideEffect.}
    proc aclDeleteFdNp(
      fileDescriptor: cint,
      aclType: cint
    ): cint {. importc: "acl_delete_fd_np", header: "<sys/acl.h>", cdecl, sideEffect.}
    proc aclFree(obj: pointer): cint {. importc: "acl_free", header: "<sys/acl.h>", cdecl, sideEffect.}

    proc readAttribute(filePath, attributeName: string): seq[byte] {.raises: [IOError].} =
      ## Reads one extended attribute without following symlinks.
      let cPath = filePath.cstring
      let cName = attributeName.cstring
      for _ in 0 ..< MaxExtendedAttributeAttempts:
        let required = getxattr(cPath, cName, nil, 0, 0'u32, XattrNoFollow)
        if required < 0:
          raise metadataError("size", filePath, attributeName)
        if required > XAttrSize(MaxExtendedAttributeValueBytes):
          raise newException(
            IOError,
            fmt"Extended metadata value for '{attributeName}' exceeds the " &
              fmt"{MaxExtendedAttributeValueBytes}-byte safety limit.")
        var value = newSeq[byte](int(required))
        let actual = if value.len == 0:
          getxattr(cPath, cName, nil, 0, 0'u32, XattrNoFollow)
        else:
          getxattr(cPath, cName, addr value[0], csize_t(value.len), 0'u32, XattrNoFollow)
        if actual < 0 or actual != required:
          continue
        value.setLen(int(actual))
        return value
      raise metadataError("read", filePath, attributeName)

    proc snapshotExtendedFileAttributes*(filePath: string): seq[ExtendedFileAttribute] {.raises: [IOError].} =
      ## Reads a bounded snapshot of macOS extended attributes without following symlinks.
      let cPath = filePath.cstring
      for _ in 0 ..< MaxExtendedAttributeAttempts:
        let required = listxattr(cPath, nil, 0, XattrNoFollow)
        if required < 0:
          raise metadataError("list", filePath, "")
        if required == 0:
          if listxattr(cPath, nil, 0, XattrNoFollow) == 0:
            return @[]
          continue
        if required > XAttrSize(MaxExtendedAttributeTotalBytes):
          raise newException(
            IOError,
            fmt"Extended metadata names for '{filePath}' exceed the " &
              fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
        var encoded = newSeq[byte](int(required))
        let actual = listxattr(cPath, addr encoded[0], csize_t(encoded.len), XattrNoFollow)
        if actual < 0 or actual != required:
          continue
        var names = parseAttributeNames(filePath, encoded)
        names.sort()
        var totalBytes = 0'i64
        for name in names:
          let value = readAttribute(filePath, name)
          if value.len > MaxExtendedAttributeValueBytes or
              totalBytes > int64(MaxExtendedAttributeTotalBytes) - int64(value.len):
            raise newException(
              IOError,
              fmt"Extended metadata for '{filePath}' exceeds the " &
                fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
          totalBytes += int64(value.len)
          result.add(ExtendedFileAttribute(name: name, value: value))
        var finalEncoded = newSeq[byte](int(required))
        let finalActual = listxattr(cPath, addr finalEncoded[0], csize_t(finalEncoded.len), XattrNoFollow)
        if finalActual != required or finalEncoded != encoded:
          result.setLen(0)
          continue
        var stable = true
        for i, name in names:
          try:
            if readAttribute(filePath, name) != result[i].value:
              stable = false
              break
          except IOError:
            stable = false
            break
        if stable:
          return result
        result.setLen(0)
      raise metadataError("snapshot", filePath, "")

    proc restoreExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Restores attributes through the open temporary file descriptor.
      if file == nil:
        raise newException(IOError, fmt"Cannot restore extended metadata on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      for attribute in attributes:
        let valuePointer = if attribute.value.len == 0: nil else: addr attribute.value[0]
        if fsetxattr(
          fileDescriptor, attribute.name.cstring, valuePointer, csize_t(attribute.value.len), 0'u32,
          0.cint) != 0:
          raise metadataError("restore", filePath, attribute.name)

    proc clearUnlistedExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Removes unlisted attributes from the open temporary file descriptor.
      if file == nil:
        raise newException(IOError, fmt"Cannot clear extended metadata on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      let required = flistxattr(fileDescriptor, nil, 0, 0.cint)
      if required < 0:
        raise metadataError("list", filePath, "")
      if required == 0:
        return
      if required > XAttrSize(MaxExtendedAttributeTotalBytes):
        raise newException(
          IOError,
          fmt"Extended metadata names for '{filePath}' exceed the " &
            fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
      var encoded = newSeq[byte](int(required))
      let actual = flistxattr(fileDescriptor, addr encoded[0], csize_t(encoded.len), 0.cint)
      if actual < 0 or actual != required:
        raise metadataError("list", filePath, "")
      for name in parseAttributeNames(filePath, encoded):
        var keep = false
        for attribute in attributes:
          if attribute.name == name:
            keep = true
            break
        if not keep and fremovexattr(fileDescriptor, name.cstring, 0.cint) != 0:
          raise metadataError("remove", filePath, name)

    proc snapshotExtendedFileAcl*(filePath: string): seq[byte] {.raises: [IOError].} =
      ## Copies the extended ACL; a missing ACL stays an empty snapshot.
      let acl = aclGetLinkNp(filePath.cstring, AclTypeExtended)
      if acl == nil:
        if posix.errno == posix.ENOENT:
          return @[]
        raise metadataError("read ACL", filePath, "")
      try:
        let required = aclSizeOf(acl)
        if required < 0:
          raise metadataError("size ACL", filePath, "")
        if required == 0:
          return @[]
        if required > clong(MaxExtendedAttributeValueBytes):
          raise newException(IOError, fmt"ACL for '{filePath}' exceeds the safety limit.")
        result = newSeq[byte](int(required))
        let actual = aclCopyExt(addr result[0], acl, clong(result.len))
        if actual != required:
          raise metadataError("read ACL", filePath, "")
      finally:
        discard aclFree(acl)

    proc restoreExtendedFileAcl*(file: File, filePath: string, aclBytes: seq[byte]) {.raises: [IOError].} =
      ## Restores the ACL on the temporary inode; empty deletes it.
      if file == nil:
        raise newException(IOError, fmt"Cannot restore ACL on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      if aclBytes.len == 0:
        if aclDeleteFdNp(fileDescriptor, AclTypeExtended) != 0 and posix.errno != posix.ENOENT and
            posix.errno != DarwinEnoattr:
          raise metadataError("remove ACL", filePath, "")
        return
      let acl = aclCopyInt(unsafeAddr aclBytes[0])
      if acl == nil:
        raise metadataError("decode ACL", filePath, "")
      try:
        if aclSetFdNp(fileDescriptor, acl, AclTypeExtended) != 0:
          raise metadataError("restore ACL", filePath, "")
      finally:
        discard aclFree(acl)

  elif defined(freebsd) or defined(dragonfly) or defined(netbsd):
    const
      ExtattrNamespaceUser = 1.cint ## EXTATTR_NAMESPACE_USER namespace.
      ExtattrNamespaceSystem = 2.cint ## EXTATTR_NAMESPACE_SYSTEM namespace.
      MaxExtendedAttributeNameBytes = 4096 ## Maximum byte length for an extattr name.
      MaxExtendedAttributeValueBytes = 16 * 1024 * 1024 ## Maximum byte length for an extattr value (16 MB).
      MaxExtendedAttributeTotalBytes = 64 * 1024 * 1024 ## Maximum combined extattr bytes (64 MB).
      MaxExtendedAttributeCount = 4096 ## Maximum number of extattr entries per file.
      MaxExtendedAttributeAttempts = 3 ## Retry count for reads under concurrent changes.
      UserPrefix = "user." ## Prefix added to user-namespace names.
      SystemPrefix = "system." ## Prefix added to system-namespace names.

    proc extattrListLink(
      path: cstring,
      attrnamespace: cint,
      data: pointer,
      nbytes: csize_t
    ): clong {. importc: "extattr_list_link", header: "<sys/extattr.h>", cdecl, sideEffect.}
    proc extattrGetLink(
      path: cstring,
      attrnamespace: cint,
      attrname: cstring,
      data: pointer,
      nbytes: csize_t
    ): clong {. importc: "extattr_get_link", header: "<sys/extattr.h>", cdecl, sideEffect.}
    proc extattrSetFd(
      fileDescriptor: cint,
      attrnamespace: cint,
      attrname: cstring,
      data: pointer,
      nbytes: csize_t
    ): clong {. importc: "extattr_set_fd", header: "<sys/extattr.h>", cdecl, sideEffect.}
    proc extattrDeleteFd(
      fileDescriptor: cint,
      attrnamespace: cint,
      attrname: cstring
    ): cint {. importc: "extattr_delete_fd", header: "<sys/extattr.h>", cdecl, sideEffect.}
    proc extattrListFd(
      fileDescriptor: cint,
      attrnamespace: cint,
      data: pointer,
      nbytes: csize_t
    ): clong {. importc: "extattr_list_fd", header: "<sys/extattr.h>", cdecl, sideEffect.}

    proc parseExtattrList(
      filePath: string,
      encoded: seq[byte],
      prefix: string
    ): seq[string] {.raises: [IOError].} =
      ## Decodes length-prefixed FreeBSD extended attribute names.
      var i = 0
      while i < encoded.len:
        let nameLength = int(encoded[i])
        inc i
        if nameLength == 0 or nameLength > MaxExtendedAttributeNameBytes or i + nameLength > encoded.len:
          raise metadataError("parse", filePath, "")
        var name = prefix
        for _ in 0 ..< nameLength:
          name.add char(encoded[i])
          inc i
        result.add(name)
        if result.len > MaxExtendedAttributeCount:
          raise newException(
            IOError,
            fmt"'{filePath}' has more than {MaxExtendedAttributeCount} " &
              "extended attributes; refusing an unbounded metadata copy.")

    proc splitAttributeName(name: string): tuple[ns: cint, raw: string] {.raises: [IOError].} =
      ## Splits a full attribute name into its namespace constant and raw name.
      if name.len > UserPrefix.len and name[0 ..< UserPrefix.len] == UserPrefix:
        return (ExtattrNamespaceUser, name[UserPrefix.len .. ^1])
      if name.len > SystemPrefix.len and name[0 ..< SystemPrefix.len] == SystemPrefix:
        return (ExtattrNamespaceSystem, name[SystemPrefix.len .. ^1])
      raise newException(IOError, "Extended attribute name is missing a namespace prefix.")

    proc listNamespace(
      filePath: string,
      ns: cint,
      prefix: string,
      required: bool
    ): seq[string] {.raises: [IOError].} =
      ## Lists extended attribute names in one FreeBSD namespace without following symlinks.
      let cPath = filePath.cstring
      let size = extattrListLink(cPath, ns, nil, 0)
      if size < 0:
        if required:
          raise metadataError("list", filePath, "")
        return @[]
      if size == 0:
        return @[]
      if size > clong(MaxExtendedAttributeTotalBytes):
        raise newException(
          IOError,
          fmt"Extended metadata names for '{filePath}' exceed the " &
            fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
      var encoded = newSeq[byte](int(size))
      let actual = extattrListLink(cPath, ns, addr encoded[0], csize_t(encoded.len))
      if actual != size:
        raise metadataError("list", filePath, "")
      parseExtattrList(filePath, encoded, prefix)

    proc readAttribute(filePath, attributeName: string): seq[byte] {.raises: [IOError].} =
      ## Reads a BSD extended attribute value.
      let parts = splitAttributeName(attributeName)
      let cPath = filePath.cstring
      let cName = parts.raw.cstring
      for _ in 0 ..< MaxExtendedAttributeAttempts:
        let required = extattrGetLink(cPath, parts.ns, cName, nil, 0)
        if required < 0:
          raise metadataError("size", filePath, attributeName)
        if required > clong(MaxExtendedAttributeValueBytes):
          raise newException(
            IOError,
            fmt"Extended metadata value for '{attributeName}' exceeds the " &
              fmt"{MaxExtendedAttributeValueBytes}-byte safety limit.")
        var value = newSeq[byte](int(required))
        let actual = if value.len == 0:
          extattrGetLink(cPath, parts.ns, cName, nil, 0)
        else:
          extattrGetLink(cPath, parts.ns, cName, addr value[0], csize_t(value.len))
        if actual < 0 or actual != required:
          continue
        value.setLen(int(actual))
        return value
      raise metadataError("read", filePath, attributeName)

    proc snapshotExtendedFileAttributes*(filePath: string): seq[ExtendedFileAttribute] {.raises: [IOError].} =
      ## Reads the user and, when permitted, system extended attributes.
      for _ in 0 ..< MaxExtendedAttributeAttempts:
        var names = listNamespace(filePath, ExtattrNamespaceUser, UserPrefix, true)
        names.add listNamespace(filePath, ExtattrNamespaceSystem, SystemPrefix, false)
        names.sort()
        var totalBytes = 0'i64
        result.setLen(0)
        for name in names:
          let value = readAttribute(filePath, name)
          if value.len > MaxExtendedAttributeValueBytes or
              totalBytes > int64(MaxExtendedAttributeTotalBytes) - int64(value.len):
            raise newException(
              IOError,
              fmt"Extended metadata for '{filePath}' exceeds the " &
                fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
          totalBytes += int64(value.len)
          result.add(ExtendedFileAttribute(name: name, value: value))
        var confirm = listNamespace(filePath, ExtattrNamespaceUser, UserPrefix, true)
        confirm.add listNamespace(filePath, ExtattrNamespaceSystem, SystemPrefix, false)
        confirm.sort()
        if confirm != names:
          continue
        var stable = true
        for i, name in names:
          try:
            if readAttribute(filePath, name) != result[i].value:
              stable = false
              break
          except IOError:
            stable = false
            break
        if stable:
          return result
      raise metadataError("snapshot", filePath, "")

    proc restoreExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Restores attributes through the open temporary file descriptor.
      if file == nil:
        raise newException(IOError, fmt"Cannot restore extended metadata on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      for attribute in attributes:
        let parts = splitAttributeName(attribute.name)
        let valuePointer = if attribute.value.len == 0: nil else: addr attribute.value[0]
        if extattrSetFd(
          fileDescriptor, parts.ns, parts.raw.cstring, valuePointer, csize_t(attribute.value.len)) < 0:
          raise metadataError("restore", filePath, attribute.name)

    proc listFdNamespace(
      fileDescriptor: cint,
      filePath: string,
      ns: cint,
      prefix: string,
      required: bool
    ): seq[string] {.raises: [IOError].} =
      ## Lists extended attribute names on an open file descriptor in one FreeBSD namespace.
      let size = extattrListFd(fileDescriptor, ns, nil, 0)
      if size < 0:
        if required:
          raise metadataError("list", filePath, "")
        return @[]
      if size == 0:
        return @[]
      if size > clong(MaxExtendedAttributeTotalBytes):
        raise newException(
          IOError,
          fmt"Extended metadata names for '{filePath}' exceed the " &
            fmt"{MaxExtendedAttributeTotalBytes}-byte safety limit.")
      var encoded = newSeq[byte](int(size))
      let actual = extattrListFd(fileDescriptor, ns, addr encoded[0], csize_t(encoded.len))
      if actual != size:
        raise metadataError("list", filePath, "")
      parseExtattrList(filePath, encoded, prefix)

    proc clearUnlistedExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Removes unlisted attributes from the open temporary file descriptor.
      if file == nil:
        raise newException(IOError, fmt"Cannot clear extended metadata on '{filePath}': file is closed.")
      let fileDescriptor = getOsFileHandle(file)
      var existing = listFdNamespace(fileDescriptor, filePath, ExtattrNamespaceUser, UserPrefix, true)
      existing.add listFdNamespace(fileDescriptor, filePath, ExtattrNamespaceSystem, SystemPrefix, false)
      for name in existing:
        var keep = false
        for attribute in attributes:
          if attribute.name == name:
            keep = true
            break
        if not keep:
          let parts = splitAttributeName(name)
          if extattrDeleteFd(fileDescriptor, parts.ns, parts.raw.cstring) != 0:
            raise metadataError("remove", filePath, name)

  else:
    proc snapshotExtendedFileAttributes*(filePath: string): seq[ExtendedFileAttribute] {.raises: [IOError].} =
      ## Fails closed on unsupported POSIX targets lacking xattr/ACL bindings.
      raise newException(
        IOError,
        fmt"Cannot preserve ACL/xattr metadata for existing file '{filePath}' " &
          "on this POSIX target; install a platform metadata adapter.")

    proc restoreExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Fails closed on unsupported POSIX targets lacking xattr/ACL bindings.
      discard file
      discard attributes
      raise newException(
        IOError, fmt"Cannot restore ACL/xattr metadata for '{filePath}' on this POSIX target.")

    proc clearUnlistedExtendedFileAttributes*(
      file: File,
      filePath: string,
      attributes: openArray[ExtendedFileAttribute]
    ) {.raises: [IOError].} =
      ## Fails closed on unsupported POSIX targets lacking xattr/ACL bindings.
      discard file
      discard attributes
      raise newException(IOError, fmt"Cannot clear ACL/xattr metadata for '{filePath}' on this POSIX target.")
