#!/usr/bin/env bats

# Tests that execute xquery via start.jar
@test "Change admin password" {
  run docker exec exist java -jar start.jar client -q -u admin -P '' -x 'sm:passwd("admin", "nimda")'
  [ "$status" -eq 0 ]
}

# Tests that use rest endpoint, this might be disabled by default soon
@test "confirm new password" {
  result=$(curl -s -H 'Content-Type: text/xml' -u 'admin:nimda' --data-binary @test/dba-xq.xml http://127.0.0.1:8080/exist/rest/db | grep 'true' | head -1)
  [ "$result" == 'true' ]
}

@test "GET version via rest" {
  run curl -s -u 'admin:nimda' "http://127.0.0.1:8080/exist/rest/db?_query=system:get-version()&_wrap=no"
  [ "$status" -eq 0 ]
  echo '# ' $output >&3
}

@test "POST list repo query" {
  result=$(curl -s -H 'Content-Type: text/xml' -u 'admin:nimda' --data-binary @test/repo-list.xml http://127.0.0.1:8080/exist/rest/db | grep -o 'http://' | head -1)
  [ "$result" == 'http://' ]
}

@test "teardown revert changes" {
  run docker exec exist java -jar start.jar client -q -u admin -P 'nimda' -x 'sm:passwd("admin", "")'
  [ "$status" -eq 0 ]
}
