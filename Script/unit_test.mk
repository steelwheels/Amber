#
# unit_test.mk
#

build_dir = $(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)
test_exec = $(build_dir)/ambparser
test_dir  = ../Test/AmberParser

log_file  = $(build_dir)/ambparser.log

TEE	  = tee -a

all: exec diff

exec: dummy
	rm -f $(log_file)
	$(test_exec) $(test_dir)/samples/empty.amb 2>&1  | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/single.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/nest.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/nest2.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/welcome.amb 2>&1 | $(TEE) $(log_file)

diff: dummy
	diff -w $(log_file) $(test_dir)/ambparser.log.OK

dummy:

