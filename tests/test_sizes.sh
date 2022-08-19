#!/usr/bin/env bash
# test functions should start with test_
# using https://github.com/pgrange/bash_unit
#  fail
#  assert
#  assert "test -e /tmp/the_file"
#  assert_fails "grep this /tmp/the_file" "should not write 'this' in /tmp/the_file"
#  assert_status_code 25 code
#  assert_equals "a string" "another string" "a string should be another string"
#  assert_not_equals "a string" "a string" "a string should be different from another string"
#  fake ps echo hello world

root_folder=$(cd .. && pwd) # tests/.. is root folder
# shellcheck disable=SC2012
# shellcheck disable=SC2035
root_script=$(find "$root_folder" -maxdepth 1 -name "*.sh" | head -1) # normally there should be only 1

test_set_width_crop() {
  local random_width=$((100 + RANDOM % 400))
  local random_height=$((100 + RANDOM % 400))
  $root_script -q -w $random_width -c $random_height  file images/square.jpg test.jpg

  assert_equals $random_width "$(identify -format '%w\n' test.jpg)"
  assert_equals $random_height "$(identify -format '%h\n' test.jpg)"
}

test_list_sizes() {
  assert_equals 1 "$("$root_script" sizes 2>&1 | grep -c "github:repo")"
  assert_equals 1 "$("$root_script" sizes 2>&1 | grep -c "instagram:square")"
  assert_equals 1 "$("$root_script" sizes 2>&1 | grep -c "twitter:header")"
}

test_preset_github() {
  $root_script -q -s github:repo  file images/square.jpg github.jpg

  assert_equals 1280 "$(identify -format '%w\n' github.jpg)"
  assert_equals 640 "$(identify -format '%h\n' github.jpg)"
}

test_zzz_cleanup(){
    assert "rm -f test.jpg github.jpg"
}
