CC = emcc

JSDIR = js

GL4ES_DIR ?= ../gl4es

# Emscripten fast linking: https://github.com/emscripten-core/emscripten/issues/17019
BUILD ?= devel

# Generate share/version.h
VERSION := $(shell sh scripts/version.sh)

ifeq ($(BUILD), devel)
CFLAGS := -O1 -fsanitize=undefined -fsanitize=address -std=gnu99 -Wall -Ishare -DNDEBUG -I$(GL4ES_DIR)/include
else
CFLAGS := -O3 -std=gnu99 -Wall -Ishare -DNDEBUG -I$(GL4ES_DIR)/include
endif

EM_CFLAGS := \
	-s USE_SDL=2 \
	-s USE_SDL_TTF=2 \
	-s USE_VORBIS=1 \
	-s USE_LIBPNG=1 \
	-s USE_LIBJPEG=1

DATA_ZIP := data-emscripten.zip

EM_PRELOAD := \
	--preload-file $(DATA_ZIP)@/data/base.zip

# Exclude Neverputt + everything that can be downloaded later.
DATA_EXCLUDE := \
	'*.map' \
	'*.obj' \
	'*.xcf' \
	'*.wings' \
	'holes*.txt' \
	'map-ckk/*' \
	'map-fwp/*' \
	'map-hard/*' \
	'map-iCourse/*' \
	'map-medium/*' \
	'map-misc/*' \
	'map-mym/*' \
	'map-mym2/*' \
	'map-paxed/*' \
	'map-paxed2/*' \
	'map-paxed3/*' \
	'map-putt/*' \
	'map-slippi/*' \
	'map-tones/*' \
	'map-vidski/*' \
	'shot-fwp/*' \
	'shot-hard/*' \
	'shot-medium/*' \
	'shot-misc/*' \
	'shot-mym/*' \
	'shot-mym2/*' \
	'shot-putt/*' \
	'shot-tones/*' \
	'set-fwp.txt' \
	'set-hard.txt' \
	'set-medium.txt' \
	'set-misc.txt' \
	'set-mym.txt' \
	'set-mym2.txt' \
	'set-tones.txt'

LDFLAGS := $(GL4ES_DIR)/lib/libGL.a
EM_LDFLAGS := \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s FULL_ES2=1 \
	-s INVOKE_RUN=0 \
	-s EXPORTED_RUNTIME_METHODS="['callMain']" \
	-s HTML5_SUPPORT_DEFERRING_USER_SENSITIVE_REQUESTS=0 \
	-s LLD_REPORT_UNDEFINED \
	-s FETCH=1 \
	-lidbfs.js \
	$(EM_PRELOAD) \
	--use-preload-cache

ifeq ($(BUILD), devel)
EM_LDFLAGS += -s ERROR_ON_WASM_CHANGES_AFTER_LINK -s WASM_BIGINT
endif

BALL_SRCS := \
	ball/demo.c \
	ball/demo_dir.c \
	ball/game_client.c \
	ball/game_common.c \
	ball/game_draw.c \
	ball/game_proxy.c \
	ball/game_server.c \
	ball/hud.c \
	ball/level.c \
	ball/main.c \
	ball/progress.c \
	ball/score.c \
	ball/set.c \
	ball/st_ball.c \
	ball/st_conf.c \
	ball/st_demo.c \
	ball/st_done.c \
	ball/st_fail.c \
	ball/st_goal.c \
	ball/st_help.c \
	ball/st_level.c \
	ball/st_name.c \
	ball/st_over.c \
	ball/st_pause.c \
	ball/st_play.c \
	ball/st_save.c \
	ball/st_set.c \
	ball/st_shared.c \
	ball/st_start.c \
	ball/st_title.c \
	ball/util.c \
	share/array.c \
	share/audio.c \
	share/ball.c \
	share/base_config.c \
	share/base_image.c \
	share/binary.c \
	share/cmd.c \
	share/common.c \
	share/config.c \
	share/dir.c \
	share/fetch_emscripten.c \
	share/font.c \
	share/fs_common.c \
	share/fs_jpg.c \
	share/fs_ov.c \
	share/fs_png.c \
	share/fs_stdio.c \
	share/miniz.c \
	share/geom.c \
	share/glext.c \
	share/gui.c \
	share/hmd_null.c \
	share/image.c \
	share/joy.c \
	share/lang.c \
	share/list.c \
	share/log.c \
	share/mtrl.c \
	share/package.c \
	share/part.c \
	share/queue.c \
	share/solid_all.c \
	share/solid_base.c \
	share/solid_draw.c \
	share/solid_sim_sol.c \
	share/solid_vary.c \
	share/st_common.c \
	share/st_package.c \
	share/state.c \
	share/text.c \
	share/theme.c \
	share/tilt_null.c \
	share/vec3.c \
	share/video.c

BALL_OBJS := $(BALL_SRCS:.c=.emscripten.o)

%.emscripten.o: %.c
	$(CC) -c -o $@ $(CFLAGS) $(EM_CFLAGS) $<

.PHONY: neverball
neverball: $(JSDIR)/neverball.js

$(JSDIR)/neverball.js: $(BALL_OBJS) $(DATA_ZIP)
	$(CC) -o $@ $(BALL_OBJS) $(CFLAGS) $(EM_CFLAGS) $(LDFLAGS) $(EM_LDFLAGS)

$(DATA_ZIP):
	cd data && zip -r ../$@ . -x $(DATA_EXCLUDE)

.PHONY: packages
packages: clean-packages
	target_dir="$$(pwd)/js/packages/"; \
	manifest="$$target_dir/available-packages-emscripten.txt"; \
	make_package="$$(pwd)/scripts/make-package.sh"; \
	mkdir -p "$$target_dir" && \
	scripts/make-data-packages.sh "data" "$$target_dir" "$$make_package" >> $$manifest; \
	scripts/make-repo-packages.sh "../neverball-packages" "$$target_dir" "$$make_package" | tee "$$target_dir/available-packages.txt" >> "$$manifest"

.PHONY: clean-packages
clean-packages:
	rm -rf "$$(pwd)/js/packages"

.PHONY: clean
clean:
	$(RM) $(BALL_OBJS) $(JSDIR)/neverball.js $(JSDIR)/neverball.wasm $(JSDIR)/neverball.data $(DATA_ZIP)

.PHONY: watch
watch:
	while true; do \
		$(MAKE) -f emscripten/ball.mk --no-print-directory --question || ( $(MAKE) -f emscripten/ball.mk --no-print-directory && echo '\e[32mok\e[0m' ); \
		sleep 1; \
	done