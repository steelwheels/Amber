#
# unit_test.mk
#

build_dir = $(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)
test_exec = $(build_dir)/ambparser
test_dir  = ../Test/AmberParser

log_file  = $(build_dir)/ambparser.log

TEE	  = tee -a

all: exec diff

clean:
	rm -f $(log_file) $(log_file).*

exec: dummy
	rm -f $(log_file)
	$(test_exec) $(test_dir)/samples/empty.amb 2>&1  | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/single.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/dict0.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/dict1.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/nest.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/nest2.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/welcome.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/bitmap.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/buttons.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/terminal.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/town.amb 2>&1 | $(TEE) $(log_file)
	$(test_exec) $(test_dir)/samples/table.amb 2>&1 | $(TEE) $(log_file)

diff: dummy
	grep -v CoreText $(log_file) \
	  | grep -v "Unknown component" \
	  > $(log_file).mod
	diff -w $(log_file).mod $(test_dir)/ambparser.log.OK

dummy:

