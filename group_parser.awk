BEGIN {
  group_size = 0;
  file = ARGV[1];
  ok = 1;
}

NF > 0 {
  if (NF != 1) {
    printf("%s: line '%s' should only contain a student number\n", file, $0);
    ok = 0;
    exit 1;
  }

  if ($1 !~ /^[aA][0-9]{8}$/) {
    printf("%s: line '%s' doesn't contain a student number\n", file, $0);
    ok = 0;
    exit 1;
  }

  group_size += 1;
}

END {
  if (ok != 1) {
    exit 1;
  }

  if (group_size < 1) {
    printf("%s: even if you don't have a group member, you should include your own PID\n", file);
    exit 1
  } else if (group_size > 2) {
    printf("%s: there can be at most 2 group members\n", file);
    exit 1
  }

  printf("parsed %d group members\n", group_size);
}
