elinks -dump "${1:?Need URL}" | perl check.pl