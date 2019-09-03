ifeq (1,$(TEMPLATE_BUILDER))
ifneq (,$(findstring kali, $(TEMPLATE_FLAVOR)))
APPMENUS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
endif
endif

# vim: ft=make