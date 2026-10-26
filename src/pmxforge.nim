## PMX Forge reads, validates, repairs, and writes PMX 2.0 and 2.1 model files.
##
## Basic usage:
##   import pmxforge
##
##   let model = readPmx("model.pmx")
##   validate(model)
##   writePmx(model, "model-copy.pmx")
##
## Reading and writing are independent, every limit is explicit, and the byte overloads
## work on host-owned storage. Native builds add the path and stream overloads; browser
## and WebAssembly builds use the byte buffers.

import ./pmxforge/format/model
import ./pmxforge/format/errors
import ./pmxforge/format/limits
import ./pmxforge/format/elements/all as elements
import ./pmxforge/format/validation
import ./pmxforge/format/io/reader
import ./pmxforge/format/io/writer

export model
export errors
export limits
export elements
export validation
export reader
export writer
