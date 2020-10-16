# always call with bash_unit <folder>/*.sh
# test functions should start with test_

script=""
[[ -f ../splashmark.sh ]] && script="../splashmark.sh"
[[ -f  ./splashmark.sh ]] && script="./splashmark.sh"
[[ -z "$script" ]] &&  fail "Run this from the root or from the tests folder"

test_executable_script_found() {
	assert_not_equals "" "$script"	"Executable script could not be found"
}

test_should_show_option_verbose() {
  assert "$script 2>&1 | grep -q verbose" "Script usage is shown when run without parameters"
}

### Examples -- via https://github.com/pgrange/bash_unit ###
# assert "test -x /tmp/the_file" "/tmp/the_file should be executable"
# assert_fails "grep cool /tmp/the_file" "should not write 'cool' in /tmp/the_file"
# assert_status_code 25 run_program
# assert_equals "a string" "another string" "a string should be another string"
# assert_not_equals "a string" "a string" "a string should be different from another string"
# fake ps echo hello world