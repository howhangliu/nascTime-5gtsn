FEATURETOOL = opp_featuretool

.PHONY: all clean cleanall makefiles checkenvir checkmakefiles dist

all: makefiles
	@cd src && $(MAKE)

clean: makefiles
	@cd src && $(MAKE) clean

cleanall: makefiles
	@cd src && $(MAKE) MODE=release clean
	@cd src && $(MAKE) MODE=debug clean
	@rm -f src/Makefile

# nascTime / FRER: derive dependency roots the same way Simu5G's own
# top-level Makefile derives INET_ROOT -- computed at build time, not
# hardcoded into a stale .oppbuildspec. Defaults assume the standard
# sibling-directory layout (../inet-4.6.0, ../simu5g-1.5.0); override on
# the command line if your layout differs, e.g.:
#   make INET_ROOT=/path/to/inet SIMU5G_ROOT=/path/to/simu5g
INET_ROOT ?= $(abspath ../inet-4.6.0)
SIMU5G_ROOT ?= $(abspath ../simu5g-1.5.0)

checkenvir:
	@if [ ! -d $(INET_ROOT) ]; then \
	echo; \
	echo '======================================================================='; \
	echo 'INET not found at $(INET_ROOT). Set INET_ROOT=<path> or check your layout.'; \
	echo '======================================================================='; \
	echo; \
	exit 1; \
	fi
	@if [ ! -d $(SIMU5G_ROOT) ]; then \
	echo; \
	echo '======================================================================='; \
	echo 'Simu5G not found at $(SIMU5G_ROOT). Set SIMU5G_ROOT=<path> or check your layout.'; \
	echo '======================================================================='; \
	echo; \
	exit 1; \
	fi

makefiles: checkenvir
	@$(info *** CREATING Makefile with INET_ROOT=$(INET_ROOT) SIMU5G_ROOT=$(SIMU5G_ROOT))
	@cd src && opp_makemake -f --deep --make-so -o nasctime \
		-KINET_PROJ=$(INET_ROOT) -KSIMU5G_PROJ=$(SIMU5G_ROOT) \
		-DINET_IMPORT \
		-I. -I$$\(INET_PROJ\)/src -I$$\(SIMU5G_PROJ\)/src \
		-L$$\(INET_PROJ\)/src -L$$\(SIMU5G_PROJ\)/src \
		-lINET$$\(D\) -lsimu5g$$\(D\)

checkmakefiles:
	@if [ ! -f src/Makefile ]; then \
	echo; \
	echo '======================================================================='; \
	echo 'src/Makefile does not exist. Please use "make makefiles" to generate it!'; \
	echo '======================================================================='; \
	echo; \
	exit 1; \
	fi