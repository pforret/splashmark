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

test_usage_effect_blur() {
  assert "$root_script -e blur   unsplash apple test.jpg"
  assert "$root_script -e blur50 unsplash apple test.jpg"
}

test_usage_effect_dark() {
  assert "$root_script -e dark   unsplash apple test.jpg"
  assert "$root_script -e dark50 unsplash apple test.jpg"
}

test_usage_effect_desat() {
  assert "$root_script -e desat   unsplash apple test.jpg"
  assert "$root_script -e desat50 unsplash apple test.jpg"
}

test_usage_effect_grain() {
  assert "$root_script -e grain   unsplash apple test.jpg"
  assert "$root_script -e grain50 unsplash apple test.jpg"
}

test_usage_effect_light() {
  assert "$root_script -e light   unsplash apple test.jpg"
  assert "$root_script -e light50 unsplash apple test.jpg"
}

test_usage_effect_median() {
  assert "$root_script -e median   unsplash apple test.jpg"
  assert "$root_script -e median50 unsplash apple test.jpg"
}

test_usage_effect_monochrome() {
  assert "$root_script -e monochrome   unsplash apple test.jpg"
  assert "$root_script -e bw           unsplash apple test.jpg"
}

test_usage_effect_paint() {
  assert "$root_script -e paint   unsplash apple test.jpg"
  assert "$root_script -e paint50 unsplash apple test.jpg"
}

test_usage_effect_pixel() {
  assert "$root_script -e pixel   unsplash apple test.jpg"
  assert "$root_script -e pixel50 unsplash apple test.jpg"
}

test_usage_effect_sketch() {
  assert "$root_script -e sketch   unsplash apple test.jpg"
  assert "$root_script -e sketch50 unsplash apple test.jpg"
}

test_usage_effect_vignette() {
  assert "$root_script -e vignette   unsplash apple test.jpg"
  assert "$root_script -e vignette50 unsplash apple test.jpg"
  rm -f test.jpg
}

