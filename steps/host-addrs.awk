# Rewrite every [[host]] entry so that its [host.yasagent.config] LISTEN_ADDR uses
# the ip of that host. yasboot package se gen writes the first host ip into every
# host block, which makes the standby yasagent bind an address it does not own.
#
# Usage: awk -v port=1702 -f host-addrs.awk hosts.toml
# Keep this file free of single quotes and of shell metacharacters: the content is
# spliced into a single-quoted shell string by steps/db.sh (see YINSTALL-010).
function flush_agent() {
  if (in_agent && !written) {
    print agent_indent "  LISTEN_ADDR = \"" host_ip ":" port "\""
    written = 1
    rewrites++
  }
}
/^[[:space:]]*\[\[host\]\]/ {
  flush_agent()
  in_agent = 0
  written = 0
  host_ip = ""
  hosts++
  print
  next
}
/^[[:space:]]*\[host\.yasagent\.config\]/ {
  if (host_ip == "") {
    print "hosts.toml host entry without ip" > "/dev/stderr"
    failed = 1
    exit 1
  }
  in_agent = 1
  written = 0
  match($0, /^[[:space:]]*/)
  agent_indent = substr($0, RSTART, RLENGTH)
  print
  next
}
in_agent && /^[[:space:]]*LISTEN_ADDR[[:space:]]*=/ {
  match($0, /^[[:space:]]*/)
  print substr($0, RSTART, RLENGTH) "LISTEN_ADDR = \"" host_ip ":" port "\""
  written = 1
  rewrites++
  next
}
/^[[:space:]]*ip[[:space:]]*=/ && host_ip == "" && hosts > 0 {
  value = $0
  sub(/^[[:space:]]*ip[[:space:]]*=[[:space:]]*/, "", value)
  gsub(/"/, "", value)
  sub(/[[:space:]]+$/, "", value)
  host_ip = value
  print
  next
}
/^[[:space:]]*\[/ {
  flush_agent()
  in_agent = 0
}
{ print }
END {
  flush_agent()
  if (failed) {
    exit 1
  }
  if (hosts == 0 || rewrites != hosts) {
    print "expected one yasagent LISTEN_ADDR per host, rewrote " rewrites " of " hosts > "/dev/stderr"
    exit 1
  }
}
