.DEFAULT_GOAL := help
SHELL=/bin/bash

-include .makefile/composer.mk
-include .makefile/global.mk

###
### ENV VERSIONS
### ¯¯¯

SYLIUS_VERSION=1.12.6
SYMFONY_VERSION=6.4
PLUGIN_NAME=agence-adeliom/sylius-tailwindcss-theme
PLUGIN_DIR=themes/TailwindTheme

###
### DEVELOPMENT : make command used  when you test or contribute
### ¯¯¯¯¯¯¯¯¯¯¯

-include .makefile/dev.mk

###
### CI : make command used by github workflow
### ¯¯¯¯¯¯¯¯¯¯¯

-include .makefile/ci.mk




