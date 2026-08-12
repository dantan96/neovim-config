CFG := $(HOME)/.config/nvim

.PHONY: test test_file luarc

# Regenerate the checked-in .luarc.json from lazy-lock.json and this machine's
# runtime paths. Run after installing or removing a plugin; tests/test_luarc.lua
# fails if it has not been. --noplugin -u NONE: the generator must not depend on
# the config it is generating for.
luarc:
	cd $(CFG) && nvim --headless --noplugin -u NONE \
		-c 'lua print(assert(loadfile("scripts/gen_luarc.lua"))().write("$(CFG)"))' -c q

test:
	cd $(CFG) && nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run()"

test_file:
	cd $(CFG) && nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('$(FILE)')"
