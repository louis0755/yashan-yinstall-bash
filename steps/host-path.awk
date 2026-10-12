# Rewrite every "path = ..." entry in hosts.toml with the requested install path.
# The yasboot "package se gen" stage writes <install-path>/<release-version>, so a
# build qualified version such as 27.1.1.2-356-gd953d3665a9 has to be written here
# before "yasboot package install" for the software to land in the requested
# directory (YINSTALL-014). Indentation and every other line are preserved.
/^[[:space:]]*path[[:space:]]*=/ {
  match($0, /^[[:space:]]*/)
  print substr($0, RSTART, RLENGTH) "path = \"" path "\""
  next
}
{ print }
