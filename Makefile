CFG := $(HOME)/.config/nvim

.PHONY: test test_file

test:
	cd $(CFG) && nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run()"

test_file:
	cd $(CFG) && nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('$(FILE)')"
